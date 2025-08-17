package services

import (
	"database/sql"
	"encoding/csv"
	"fmt"
	"io"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type InventoryService struct {
	db *sql.DB
}

func NewInventoryService() *InventoryService {
	return &InventoryService{
		db: database.GetDB(),
	}
}

func (s *InventoryService) GetStock(companyID, locationID int, productID *int) ([]models.StockWithProduct, error) {
	query := `
		SELECT s.stock_id, s.location_id, s.product_id, s.quantity, s.reserved_quantity, s.last_updated,
			   p.name as product_name, p.sku, p.reorder_level,
			   c.name as category_name, b.name as brand_name, u.symbol as unit_symbol
		FROM stock s
		JOIN products p ON s.product_id = p.product_id
		LEFT JOIN categories c ON p.category_id = c.category_id
		LEFT JOIN brands b ON p.brand_id = b.brand_id
		LEFT JOIN units u ON p.unit_id = u.unit_id
		WHERE p.company_id = $1 AND s.location_id = $2 AND p.is_deleted = FALSE
	`

	args := []interface{}{companyID, locationID}
	argCount := 2

	if productID != nil {
		argCount++
		query += fmt.Sprintf(" AND s.product_id = $%d", argCount)
		args = append(args, *productID)
	}

	query += " ORDER BY p.name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock: %w", err)
	}
	defer rows.Close()

	var stockItems []models.StockWithProduct
	for rows.Next() {
		var item models.StockWithProduct
		err := rows.Scan(
			&item.StockID, &item.LocationID, &item.ProductID, &item.Quantity,
			&item.ReservedQuantity, &item.LastUpdated, &item.ProductName, &item.ProductSKU,
			&item.ReorderLevel, &item.CategoryName, &item.BrandName, &item.UnitSymbol,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan stock: %w", err)
		}

		// Check if low stock
		item.IsLowStock = item.Quantity <= float64(item.ReorderLevel)

		stockItems = append(stockItems, item)
	}

	return stockItems, nil
}

func (s *InventoryService) AdjustStock(companyID, locationID, userID int, req *models.CreateStockAdjustmentRequest) error {
	// Verify product belongs to company
	var productCompanyID int
	err := s.db.QueryRow("SELECT company_id FROM products WHERE product_id = $1 AND is_deleted = FALSE",
		req.ProductID).Scan(&productCompanyID)
	if err == sql.ErrNoRows {
		return fmt.Errorf("product not found")
	}
	if err != nil {
		return fmt.Errorf("failed to verify product: %w", err)
	}
	if productCompanyID != companyID {
		return fmt.Errorf("product not found")
	}

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Update or insert stock
	_, err = tx.Exec(`
		INSERT INTO stock (location_id, product_id, quantity, last_updated)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
		ON CONFLICT (location_id, product_id)
		DO UPDATE SET 
			quantity = stock.quantity + $3,
			last_updated = CURRENT_TIMESTAMP
	`, locationID, req.ProductID, req.Adjustment)

	if err != nil {
		return fmt.Errorf("failed to adjust stock: %w", err)
	}

	// Record adjustment history
	_, err = tx.Exec(`
		INSERT INTO stock_adjustments (location_id, product_id, adjustment, reason, created_by)
		VALUES ($1, $2, $3, $4, $5)
	`, locationID, req.ProductID, req.Adjustment, req.Reason, userID)

	if err != nil {
		return fmt.Errorf("failed to record adjustment: %w", err)
	}

	return tx.Commit()
}

func (s *InventoryService) GetStockAdjustments(companyID, locationID int) ([]models.StockAdjustment, error) {
	query := `
		SELECT sa.adjustment_id, sa.location_id, sa.product_id, sa.adjustment, 
			   sa.reason, sa.created_by, sa.created_at
		FROM stock_adjustments sa
		JOIN products p ON sa.product_id = p.product_id
		WHERE p.company_id = $1 AND sa.location_id = $2
		ORDER BY sa.created_at DESC
	`

	rows, err := s.db.Query(query, companyID, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock adjustments: %w", err)
	}
	defer rows.Close()

	var adjustments []models.StockAdjustment
	for rows.Next() {
		var adj models.StockAdjustment
		err := rows.Scan(
			&adj.AdjustmentID, &adj.LocationID, &adj.ProductID, &adj.Adjustment,
			&adj.Reason, &adj.CreatedBy, &adj.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan adjustment: %w", err)
		}
		adjustments = append(adjustments, adj)
	}

	return adjustments, nil
}

func (s *InventoryService) CreateStockTransfer(companyID, fromLocationID, userID int, req *models.CreateStockTransferRequest) (*models.StockTransfer, error) {
	// Verify locations belong to company
	err := s.verifyLocationsInCompany(companyID, fromLocationID, req.ToLocationID)
	if err != nil {
		return nil, err
	}

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Generate transfer number using numbering sequence
	ns := NewNumberingSequenceService()
	transferNumber, err := ns.NextNumber(tx, "stock_transfer", companyID, &fromLocationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate transfer number: %w", err)
	}

	// Create transfer
	var transferID int
	err = tx.QueryRow(`
                INSERT INTO stock_transfers (transfer_number, from_location_id, to_location_id, transfer_date, notes, created_by, updated_by)
                VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4, $5, $5)
                RETURNING transfer_id
        `, transferNumber, fromLocationID, req.ToLocationID, req.Notes, userID).Scan(&transferID)

	if err != nil {
		return nil, fmt.Errorf("failed to create transfer: %w", err)
	}

	// Add transfer items
	for _, item := range req.Items {
		// Verify product exists and has sufficient stock
		var currentStock float64
		err = tx.QueryRow(`
			SELECT COALESCE(quantity, 0) FROM stock 
			WHERE location_id = $1 AND product_id = $2
		`, fromLocationID, item.ProductID).Scan(&currentStock)

		if err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to check stock: %w", err)
		}

		if currentStock < item.Quantity {
			return nil, fmt.Errorf("insufficient stock for product ID %d", item.ProductID)
		}

		// Insert transfer detail
		_, err = tx.Exec(`
			INSERT INTO stock_transfer_details (transfer_id, product_id, quantity)
			VALUES ($1, $2, $3)
		`, transferID, item.ProductID, item.Quantity)

		if err != nil {
			return nil, fmt.Errorf("failed to add transfer item: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Return created transfer
	transfer := &models.StockTransfer{
		TransferID:     transferID,
		TransferNumber: transferNumber,
		FromLocationID: fromLocationID,
		ToLocationID:   req.ToLocationID,
		TransferDate:   time.Now(),
		Status:         "PENDING",
		Notes:          req.Notes,
		CreatedBy:      userID,
	}

	return transfer, nil
}

func (s *InventoryService) GetStockTransfers(companyID, locationID int) ([]models.StockTransfer, error) {
	query := `
                SELECT transfer_id, transfer_number, from_location_id, to_location_id,
                           transfer_date, status, notes, created_by, approved_by, approved_at,
                           sync_status, created_at, updated_at
                FROM stock_transfers
                WHERE (from_location_id = $1 OR to_location_id = $1)
                ORDER BY created_at DESC
        `

	rows, err := s.db.Query(query, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get transfers: %w", err)
	}
	defer rows.Close()

	var transfers []models.StockTransfer
	for rows.Next() {
		var transfer models.StockTransfer
		err := rows.Scan(
			&transfer.TransferID, &transfer.TransferNumber, &transfer.FromLocationID,
			&transfer.ToLocationID, &transfer.TransferDate, &transfer.Status,
			&transfer.Notes, &transfer.CreatedBy, &transfer.ApprovedBy, &transfer.ApprovedAt,
			&transfer.SyncStatus, &transfer.CreatedAt, &transfer.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan transfer: %w", err)
		}
		transfers = append(transfers, transfer)
	}

	return transfers, nil
}

func (s *InventoryService) CompleteStockTransfer(transferID, companyID, userID int) error {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Get transfer details
	var fromLocationID, toLocationID int
	var status string
	err = tx.QueryRow(`
		SELECT from_location_id, to_location_id, status 
		FROM stock_transfers 
		WHERE transfer_id = $1
	`, transferID).Scan(&fromLocationID, &toLocationID, &status)

	if err == sql.ErrNoRows {
		return fmt.Errorf("transfer not found")
	}
	if err != nil {
		return fmt.Errorf("failed to get transfer: %w", err)
	}

	if status != "PENDING" {
		return fmt.Errorf("transfer is not pending")
	}

	// Get transfer items and process each
	rows, err := tx.Query(`
		SELECT product_id, quantity FROM stock_transfer_details 
		WHERE transfer_id = $1
	`, transferID)
	if err != nil {
		return fmt.Errorf("failed to get transfer items: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var productID int
		var quantity float64
		err := rows.Scan(&productID, &quantity)
		if err != nil {
			return fmt.Errorf("failed to scan transfer item: %w", err)
		}

		// Reduce stock from source location
		_, err = tx.Exec(`
			UPDATE stock SET quantity = quantity - $1, last_updated = CURRENT_TIMESTAMP
			WHERE location_id = $2 AND product_id = $3
		`, quantity, fromLocationID, productID)
		if err != nil {
			return fmt.Errorf("failed to reduce source stock: %w", err)
		}

		// Add stock to destination location
		_, err = tx.Exec(`
			INSERT INTO stock (location_id, product_id, quantity, last_updated)
			VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
			ON CONFLICT (location_id, product_id)
			DO UPDATE SET 
				quantity = stock.quantity + $3,
				last_updated = CURRENT_TIMESTAMP
		`, toLocationID, productID, quantity)
		if err != nil {
			return fmt.Errorf("failed to add destination stock: %w", err)
		}
	}

	// Mark transfer as completed
	_, err = tx.Exec(`
                UPDATE stock_transfers
                SET status = 'COMPLETED', approved_by = $1, approved_at = CURRENT_TIMESTAMP, updated_by = $1, updated_at = CURRENT_TIMESTAMP
                WHERE transfer_id = $2
        `, userID, transferID)
	if err != nil {
		return fmt.Errorf("failed to complete transfer: %w", err)
	}

	return tx.Commit()
}

// ADD THESE METHODS TO YOUR EXISTING inventory_service.go FILE

// GetStockTransfer retrieves a single transfer with items by ID
func (s *InventoryService) GetStockTransfer(transferID, companyID int) (*models.StockTransferWithDetails, error) {
	// First get the transfer details
	var transfer models.StockTransferWithDetails
	query := `
                SELECT st.transfer_id, st.transfer_number, st.from_location_id, st.to_location_id,
                           st.transfer_date, st.status, st.notes, st.created_by, st.approved_by, st.approved_at,
                           st.sync_status, st.created_at, st.updated_at,
                           fl.name as from_location_name, tl.name as to_location_name,
                           cu.username as created_by_name, au.username as approved_by_name
                FROM stock_transfers st
		JOIN locations fl ON st.from_location_id = fl.location_id
		JOIN locations tl ON st.to_location_id = tl.location_id
		JOIN users cu ON st.created_by = cu.user_id
		LEFT JOIN users au ON st.approved_by = au.user_id
		WHERE st.transfer_id = $1 
		AND (fl.company_id = $2 OR tl.company_id = $2)
	`

	err := s.db.QueryRow(query, transferID, companyID).Scan(
		&transfer.TransferID, &transfer.TransferNumber, &transfer.FromLocationID,
		&transfer.ToLocationID, &transfer.TransferDate, &transfer.Status,
		&transfer.Notes, &transfer.CreatedBy, &transfer.ApprovedBy, &transfer.ApprovedAt,
		&transfer.SyncStatus, &transfer.CreatedAt, &transfer.UpdatedAt,
		&transfer.FromLocationName, &transfer.ToLocationName,
		&transfer.CreatedByName, &transfer.ApprovedByName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("transfer not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get transfer: %w", err)
	}

	// Get transfer items with product details
	itemsQuery := `
		SELECT std.transfer_detail_id, std.product_id, std.quantity, std.received_quantity,
			   p.name as product_name, p.sku as product_sku, u.symbol as unit_symbol
		FROM stock_transfer_details std
		JOIN products p ON std.product_id = p.product_id
		LEFT JOIN units u ON p.unit_id = u.unit_id
		WHERE std.transfer_id = $1
		ORDER BY std.transfer_detail_id
	`

	rows, err := s.db.Query(itemsQuery, transferID)
	if err != nil {
		return nil, fmt.Errorf("failed to get transfer items: %w", err)
	}
	defer rows.Close()

	var items []models.StockTransferDetailWithProduct
	for rows.Next() {
		var item models.StockTransferDetailWithProduct
		err := rows.Scan(
			&item.TransferDetailID, &item.ProductID, &item.Quantity, &item.ReceivedQuantity,
			&item.ProductName, &item.ProductSKU, &item.UnitSymbol,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan transfer item: %w", err)
		}
		items = append(items, item)
	}

	transfer.Items = items
	return &transfer, nil
}

// GetStockTransfersWithFilters retrieves transfers with enhanced filtering
func (s *InventoryService) GetStockTransfersWithFilters(filters *models.StockTransferFilters) ([]models.StockTransferWithItems, error) {
	query := `
                SELECT st.transfer_id, st.transfer_number, st.from_location_id, st.to_location_id,
                           st.transfer_date, st.status, st.notes, st.created_by, st.approved_by, st.approved_at,
                           st.sync_status, st.created_at, st.updated_at,
                           fl.name as from_location_name, tl.name as to_location_name
                FROM stock_transfers st
                JOIN locations fl ON st.from_location_id = fl.location_id
		JOIN locations tl ON st.to_location_id = tl.location_id
		WHERE (fl.company_id = $1 OR tl.company_id = $1)
	`

	args := []interface{}{filters.CompanyID}
	argIndex := 2

	// Add location filtering
	if filters.LocationID > 0 {
		query += fmt.Sprintf(" AND (st.from_location_id = $%d OR st.to_location_id = $%d)", argIndex, argIndex)
		args = append(args, filters.LocationID)
		argIndex++
	}

	if filters.SourceLocationID > 0 {
		query += fmt.Sprintf(" AND st.from_location_id = $%d", argIndex)
		args = append(args, filters.SourceLocationID)
		argIndex++
	}

	if filters.DestinationLocationID > 0 {
		query += fmt.Sprintf(" AND st.to_location_id = $%d", argIndex)
		args = append(args, filters.DestinationLocationID)
		argIndex++
	}

	if filters.Status != "" {
		query += fmt.Sprintf(" AND UPPER(st.status) = UPPER($%d)", argIndex)
		args = append(args, filters.Status)
		argIndex++
	}

	query += " ORDER BY st.created_at DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get transfers: %w", err)
	}
	defer rows.Close()

	var transfers []models.StockTransferWithItems
	for rows.Next() {
		var transfer models.StockTransferWithItems
		err := rows.Scan(
			&transfer.TransferID, &transfer.TransferNumber, &transfer.FromLocationID,
			&transfer.ToLocationID, &transfer.TransferDate, &transfer.Status,
			&transfer.Notes, &transfer.CreatedBy, &transfer.ApprovedBy, &transfer.ApprovedAt,
			&transfer.SyncStatus, &transfer.CreatedAt, &transfer.UpdatedAt,
			&transfer.FromLocationName, &transfer.ToLocationName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan transfer: %w", err)
		}

		// Get items for each transfer
		items, err := s.getTransferItems(transfer.TransferID)
		if err != nil {
			return nil, fmt.Errorf("failed to get transfer items: %w", err)
		}
		transfer.Items = items

		transfers = append(transfers, transfer)
	}

	return transfers, nil
}

// CancelStockTransfer cancels a pending transfer
func (s *InventoryService) CancelStockTransfer(transferID, companyID, userID int) error {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Verify transfer exists and is pending
	var status string
	var fromLocationID, toLocationID int
	err = tx.QueryRow(`
		SELECT st.status, st.from_location_id, st.to_location_id
		FROM stock_transfers st
		JOIN locations fl ON st.from_location_id = fl.location_id
		JOIN locations tl ON st.to_location_id = tl.location_id
		WHERE st.transfer_id = $1 AND (fl.company_id = $2 OR tl.company_id = $2)
	`, transferID, companyID).Scan(&status, &fromLocationID, &toLocationID)

	if err == sql.ErrNoRows {
		return fmt.Errorf("transfer not found")
	}
	if err != nil {
		return fmt.Errorf("failed to get transfer: %w", err)
	}

	if status != "PENDING" {
		return fmt.Errorf("only pending transfers can be cancelled")
	}

	// Update transfer status to CANCELLED
	_, err = tx.Exec(`
                UPDATE stock_transfers
                SET status = 'CANCELLED', updated_by = $2, updated_at = CURRENT_TIMESTAMP
                WHERE transfer_id = $1
        `, transferID, userID)
	if err != nil {
		return fmt.Errorf("failed to cancel transfer: %w", err)
	}

	return tx.Commit()
}

// Helper method to get transfer items
func (s *InventoryService) getTransferItems(transferID int) ([]models.StockTransferItemSummary, error) {
	query := `
		SELECT std.product_id, std.quantity, p.name as product_name
		FROM stock_transfer_details std
		JOIN products p ON std.product_id = p.product_id
		WHERE std.transfer_id = $1
		ORDER BY std.transfer_detail_id
	`

	rows, err := s.db.Query(query, transferID)
	if err != nil {
		return nil, fmt.Errorf("failed to get transfer items: %w", err)
	}
	defer rows.Close()

	var items []models.StockTransferItemSummary
	for rows.Next() {
		var item models.StockTransferItemSummary
		err := rows.Scan(&item.ProductID, &item.Quantity, &item.ProductName)
		if err != nil {
			return nil, fmt.Errorf("failed to scan transfer item: %w", err)
		}
		items = append(items, item)
	}

	return items, nil
}

// Helper methods
func (s *InventoryService) verifyLocationsInCompany(companyID, fromLocationID, toLocationID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM locations 
		WHERE company_id = $1 AND location_id IN ($2, $3) AND is_active = TRUE
	`, companyID, fromLocationID, toLocationID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to verify locations: %w", err)
	}

	if count != 2 {
		return fmt.Errorf("invalid locations")
	}

	return nil
}

// GetInventorySummary returns aggregated stock and recent activity for a company
func (s *InventoryService) GetInventorySummary(companyID int) (*models.InventorySummary, error) {
	summary := &models.InventorySummary{}

	// Aggregate stock by location
	rows, err := s.db.Query(`
               SELECT l.location_id, l.name, COALESCE(SUM(s.quantity),0) as total_qty
               FROM locations l
               LEFT JOIN stock s ON l.location_id = s.location_id
               LEFT JOIN products p ON s.product_id = p.product_id
               WHERE l.company_id = $1 AND (p.company_id = $1 OR p.company_id IS NULL)
               GROUP BY l.location_id, l.name
       `, companyID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var item models.StockLocationSummary
			if err := rows.Scan(&item.LocationID, &item.LocationName, &item.TotalQuantity); err == nil {
				summary.StockByLocation = append(summary.StockByLocation, item)
			}
		}
	}

	// Recent movement and transactions are left empty for now
	summary.MovementHistory = []models.StockAdjustment{}
	summary.RecentTransactions = []models.StockTransfer{}
	return summary, nil
}

// GetProductSummary returns stock and history for a single product
func (s *InventoryService) GetProductSummary(companyID, productID int) (*models.ProductSummary, error) {
	summary := &models.ProductSummary{ProductID: productID}

	rows, err := s.db.Query(`
               SELECT location_id, product_id, quantity, reserved_quantity, last_updated
               FROM stock WHERE product_id = $1`, productID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var st models.Stock
			if err := rows.Scan(&st.LocationID, &st.ProductID, &st.Quantity, &st.ReservedQuantity, &st.LastUpdated); err == nil {
				summary.StockByLocation = append(summary.StockByLocation, st)
			}
		}
	}

	summary.MovementHistory = []models.StockAdjustment{}
	summary.RecentTransfers = []models.StockTransferDetailWithProduct{}
	return summary, nil
}

// ImportInventory processes inventory data from an uploaded file stream
func (s *InventoryService) ImportInventory(companyID int, r io.Reader) error {
	reader := csv.NewReader(r)

	// Attempt to read header row; if file is empty just return
	if _, err := reader.Read(); err != nil {
		if err == io.EOF {
			return nil
		}
		return fmt.Errorf("failed to read header: %w", err)
	}

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read record: %w", err)
		}

		// Process each record here. Actual implementation would map
		// CSV columns to inventory fields and persist them.
		_ = record
	}

	return nil
}

// ExportInventory returns inventory data as an Excel file
func (s *InventoryService) ExportInventory(companyID int) ([]byte, error) {
	// Placeholder - return empty content
	return []byte{}, nil
}

// GenerateBarcode creates barcode labels for the provided products
func (s *InventoryService) GenerateBarcode(companyID int, req *models.BarcodeRequest) ([]byte, error) {
	// Placeholder - return empty PDF/label content
	return []byte{}, nil
}
