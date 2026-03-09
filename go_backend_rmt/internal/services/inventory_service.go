package services

import (
	"bytes"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"

	"github.com/lib/pq"
	"github.com/xuri/excelize/v2"
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
	// Select products in the company and left-join stock for the requested location.
	// COALESCE stock fields to avoid NULL scans and to return zero-quantity rows.
	query := `
        SELECT
            COALESCE(s.stock_id, 0) AS stock_id,
            $2 AS location_id,
            COALESCE(s.product_id, p.product_id) AS product_id,
            COALESCE(s.quantity, 0) AS quantity,
            COALESCE(s.reserved_quantity, 0) AS reserved_quantity,
            COALESCE(s.last_updated, CURRENT_TIMESTAMP) AS last_updated,
            p.name AS product_name,
            p.sku,
            p.reorder_level,
            p.category_id,
            c.name AS category_name,
            b.name AS brand_name,
            u.symbol AS unit_symbol
        FROM products p
        LEFT JOIN stock s
            ON s.product_id = p.product_id
           AND s.location_id = $2
        LEFT JOIN categories c ON p.category_id = c.category_id
        LEFT JOIN brands b ON p.brand_id = b.brand_id
        LEFT JOIN units u ON p.unit_id = u.unit_id
        WHERE p.company_id = $1 AND p.is_deleted = FALSE
    `

	args := []interface{}{companyID, locationID}
	argCount := 2

	if productID != nil {
		argCount++
		query += fmt.Sprintf(" AND p.product_id = $%d", argCount)
		args = append(args, *productID)
	}

	query += " ORDER BY p.name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock: %w", err)
	}
	defer rows.Close()

	// Ensure empty slice ([]) instead of null when no rows
	stockItems := make([]models.StockWithProduct, 0)
	for rows.Next() {
		var item models.StockWithProduct
		err := rows.Scan(
			&item.StockID, &item.LocationID, &item.ProductID, &item.Quantity,
			&item.ReservedQuantity, &item.LastUpdated, &item.ProductName, &item.ProductSKU,
			&item.ReorderLevel, &item.CategoryID, &item.CategoryName, &item.BrandName, &item.UnitSymbol,
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

// CreateStockAdjustmentDocument creates a header + items and applies stock changes atomically
func (s *InventoryService) CreateStockAdjustmentDocument(companyID, locationID, userID int, req *models.CreateStockAdjustmentDocumentRequest) (*models.StockAdjustmentDocument, error) {
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("no items to adjust")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Generate document number using numbering sequence, fallback to timestamp if not configured
	ns := NewNumberingSequenceService()
	docNumber, err := ns.NextNumber(tx, "stock_adjustment", companyID, &locationID)
	if err != nil {
		// fallback simple number
		docNumber = fmt.Sprintf("ADJ-%d", time.Now().Unix())
	}

	var docID int
	var createdAt time.Time
	err = tx.QueryRow(`
        INSERT INTO stock_adjustment_documents (document_number, location_id, reason, created_by)
        VALUES ($1,$2,$3,$4)
        RETURNING document_id, created_at
    `, docNumber, locationID, req.Reason, userID).Scan(&docID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create document: %w", err)
	}

	for _, it := range req.Items {
		// Verify product belongs to company
		var productCompanyID int
		err := tx.QueryRow("SELECT company_id FROM products WHERE product_id = $1 AND is_deleted = FALSE", it.ProductID).Scan(&productCompanyID)
		if err == sql.ErrNoRows || productCompanyID != companyID {
			return nil, fmt.Errorf("product not found")
		}
		if err != nil {
			return nil, fmt.Errorf("failed to verify product: %w", err)
		}

		// Insert item
		if _, err := tx.Exec(`
            INSERT INTO stock_adjustment_document_items (document_id, product_id, adjustment)
            VALUES ($1,$2,$3)
        `, docID, it.ProductID, it.Adjustment); err != nil {
			return nil, fmt.Errorf("failed to add document item: %w", err)
		}

		// Apply stock change (upsert)
		if _, err := tx.Exec(`
            INSERT INTO stock (location_id, product_id, quantity, last_updated)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
            ON CONFLICT (location_id, product_id)
            DO UPDATE SET 
                quantity = stock.quantity + $3,
                last_updated = CURRENT_TIMESTAMP
        `, locationID, it.ProductID, it.Adjustment); err != nil {
			return nil, fmt.Errorf("failed to adjust stock: %w", err)
		}

		// Record adjustment history (keeps legacy listing working)
		if _, err := tx.Exec(`
            INSERT INTO stock_adjustments (location_id, product_id, adjustment, reason, created_by)
            VALUES ($1,$2,$3,$4,$5)
        `, locationID, it.ProductID, it.Adjustment, fmt.Sprintf("%s | %s", docNumber, req.Reason), userID); err != nil {
			return nil, fmt.Errorf("failed to record adjustment: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &models.StockAdjustmentDocument{
		DocumentID:     docID,
		DocumentNumber: docNumber,
		LocationID:     locationID,
		Reason:         req.Reason,
		CreatedBy:      userID,
		CreatedAt:      createdAt,
	}, nil
}

// GetStockAdjustmentDocuments returns document headers for a company/location
func (s *InventoryService) GetStockAdjustmentDocuments(companyID, locationID int) ([]models.StockAdjustmentDocument, error) {
	rows, err := s.db.Query(`
        SELECT d.document_id, d.document_number, d.location_id, d.reason, d.created_by, d.created_at
        FROM stock_adjustment_documents d
        JOIN locations l ON d.location_id = l.location_id
        WHERE l.company_id = $1 AND d.location_id = $2
        ORDER BY d.created_at DESC
    `, companyID, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get documents: %w", err)
	}
	defer rows.Close()
	list := make([]models.StockAdjustmentDocument, 0)
	for rows.Next() {
		var d models.StockAdjustmentDocument
		if err := rows.Scan(&d.DocumentID, &d.DocumentNumber, &d.LocationID, &d.Reason, &d.CreatedBy, &d.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan document: %w", err)
		}
		// include items for each document for list summaries
		itsRows, err := s.db.Query(`
            SELECT item_id, document_id, product_id, adjustment
            FROM stock_adjustment_document_items
            WHERE document_id = $1
            ORDER BY item_id
        `, d.DocumentID)
		if err == nil {
			var items []models.StockAdjustmentDocumentItem
			for itsRows.Next() {
				var it models.StockAdjustmentDocumentItem
				if err := itsRows.Scan(&it.ItemID, &it.DocumentID, &it.ProductID, &it.Adjustment); err == nil {
					items = append(items, it)
				}
			}
			itsRows.Close()
			d.Items = items
		}
		list = append(list, d)
	}
	return list, nil
}

// GetStockAdjustmentDocument returns header + items
func (s *InventoryService) GetStockAdjustmentDocument(documentID, companyID, locationID int) (*models.StockAdjustmentDocument, error) {
	var d models.StockAdjustmentDocument
	err := s.db.QueryRow(`
        SELECT d.document_id, d.document_number, d.location_id, d.reason, d.created_by, d.created_at
        FROM stock_adjustment_documents d
        JOIN locations l ON d.location_id = l.location_id
        WHERE d.document_id = $1 AND l.company_id = $2 AND d.location_id = $3
    `, documentID, companyID, locationID).Scan(&d.DocumentID, &d.DocumentNumber, &d.LocationID, &d.Reason, &d.CreatedBy, &d.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("document not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get document: %w", err)
	}

	rows, err := s.db.Query(`
        SELECT item_id, document_id, product_id, adjustment
        FROM stock_adjustment_document_items
        WHERE document_id = $1
        ORDER BY item_id
    `, documentID)
	if err != nil {
		return nil, fmt.Errorf("failed to get document items: %w", err)
	}
	defer rows.Close()
	var items []models.StockAdjustmentDocumentItem
	for rows.Next() {
		var it models.StockAdjustmentDocumentItem
		if err := rows.Scan(&it.ItemID, &it.DocumentID, &it.ProductID, &it.Adjustment); err != nil {
			return nil, fmt.Errorf("failed to scan item: %w", err)
		}
		items = append(items, it)
	}
	d.Items = items
	return &d, nil
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

// ApproveStockTransfer marks a pending transfer as in transit
func (s *InventoryService) ApproveStockTransfer(transferID, companyID, actingLocationID, userID int) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var status string
	var fromLocationID int
	err = tx.QueryRow(`
                SELECT st.status, st.from_location_id
                FROM stock_transfers st
                JOIN locations fl ON st.from_location_id = fl.location_id
                JOIN locations tl ON st.to_location_id = tl.location_id
                WHERE st.transfer_id = $1 AND (fl.company_id = $2 OR tl.company_id = $2)
        `, transferID, companyID).Scan(&status, &fromLocationID)

	if err == sql.ErrNoRows {
		return fmt.Errorf("transfer not found")
	}
	if err != nil {
		return fmt.Errorf("failed to get transfer: %w", err)
	}

	if status != "PENDING" {
		return fmt.Errorf("only pending transfers can be approved")
	}

	// Ensure approval is performed from source location
	if actingLocationID != fromLocationID {
		return fmt.Errorf("approval must be done from source location")
	}

	_, err = tx.Exec(`
                UPDATE stock_transfers
                SET status = 'IN_TRANSIT', approved_by = $2, approved_at = CURRENT_TIMESTAMP, updated_by = $2, updated_at = CURRENT_TIMESTAMP
                WHERE transfer_id = $1
        `, transferID, userID)
	if err != nil {
		return fmt.Errorf("failed to approve transfer: %w", err)
	}

	return tx.Commit()
}

func (s *InventoryService) CompleteStockTransfer(transferID, companyID, actingLocationID, userID int) error {
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

	if status != "IN_TRANSIT" {
		return fmt.Errorf("transfer is not in transit")
	}

	// Ensure completion is performed at destination location
	if actingLocationID != toLocationID {
		return fmt.Errorf("completion must be done at destination location")
	}

	// Get transfer items first (drain rows), then process updates to avoid
	// issuing new queries while the result set is still open (lib/pq quirk).
	rows, err := tx.Query(`
        SELECT product_id, quantity FROM stock_transfer_details 
        WHERE transfer_id = $1
    `, transferID)
	if err != nil {
		return fmt.Errorf("failed to get transfer items: %w", err)
	}
	var items []struct {
		productID int
		quantity  float64
	}
	for rows.Next() {
		var productID int
		var quantity float64
		if err := rows.Scan(&productID, &quantity); err != nil {
			rows.Close()
			return fmt.Errorf("failed to scan transfer item: %w", err)
		}
		items = append(items, struct {
			productID int
			quantity  float64
		}{productID: productID, quantity: quantity})
	}
	if err := rows.Close(); err != nil {
		return fmt.Errorf("failed to close items cursor: %w", err)
	}

	for _, it := range items {
		// Reduce stock from source location
		if _, err := tx.Exec(`
            UPDATE stock SET quantity = quantity - $1, last_updated = CURRENT_TIMESTAMP
            WHERE location_id = $2 AND product_id = $3
        `, it.quantity, fromLocationID, it.productID); err != nil {
			return fmt.Errorf("failed to reduce source stock: %w", err)
		}

		// Add stock to destination location
		if _, err := tx.Exec(`
            INSERT INTO stock (location_id, product_id, quantity, last_updated)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
            ON CONFLICT (location_id, product_id)
            DO UPDATE SET 
                quantity = stock.quantity + $3,
                last_updated = CURRENT_TIMESTAMP
        `, toLocationID, it.productID, it.quantity); err != nil {
			return fmt.Errorf("failed to add destination stock: %w", err)
		}
	}

	// Mark transfer as completed
	_, err = tx.Exec(`
                UPDATE stock_transfers
                SET status = 'COMPLETED', updated_by = $1, updated_at = CURRENT_TIMESTAMP
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

var inventoryImportHeaders = []string{
	"SKU",
	"Name",
	"Description",
	"Category",
	"Brand",
	"Unit",
	"Tax",
	"Default Supplier",
	"Cost Price",
	"Selling Price",
	"Reorder Level",
	"Weight",
	"Dimensions",
	"Is Serialized",
	"Is Active",
	"Barcode",
	"Pack Size",
	"Barcode Cost Price",
	"Barcode Selling Price",
	"Is Primary Barcode",
}

type inventoryGroup struct {
	SKU             string
	Name            string
	Description     *string
	Category        *string
	Brand           *string
	Unit            *string
	Tax             string
	DefaultSupplier *string
	CostPrice       *float64
	SellingPrice    *float64
	ReorderLevel    *int
	Weight          *float64
	Dimensions      *string
	IsSerialized    *bool
	IsActive        *bool
	Barcodes        []models.ProductBarcode
}

// ImportInventory imports product master data and barcodes via Excel (.xlsx).
// If a product already exists (SKU or barcode match), it updates the product and replaces its barcodes.
func (s *InventoryService) ImportInventory(companyID, userID int, data []byte) (*models.ImportResult, error) {
	xl, err := excelize.OpenReader(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("invalid Excel file: %w", err)
	}

	sheetName := xl.GetSheetName(0)
	rows, err := xl.GetRows(sheetName)
	if err != nil {
		return nil, fmt.Errorf("failed to read sheet: %w", err)
	}
	if len(rows) == 0 {
		return &models.ImportResult{}, nil
	}

	hdr := headerIndex(rows[0])
	skuIdx, _ := firstHeaderMatch(hdr, "sku")
	nameIdx, ok := firstHeaderMatch(hdr, "name")
	if !ok {
		return nil, fmt.Errorf("missing required column: Name")
	}
	taxIdx, ok := firstHeaderMatch(hdr, "tax", "tax name", "tax id", "tax_id")
	if !ok {
		return nil, fmt.Errorf("missing required column: Tax")
	}
	barcodeIdx, ok := firstHeaderMatch(hdr, "barcode")
	if !ok {
		return nil, fmt.Errorf("missing required column: Barcode")
	}

	descIdx, _ := firstHeaderMatch(hdr, "description")
	categoryIdx, _ := firstHeaderMatch(hdr, "category", "category name", "category_name")
	brandIdx, _ := firstHeaderMatch(hdr, "brand", "brand name", "brand_name")
	unitIdx, _ := firstHeaderMatch(hdr, "unit", "unit symbol", "unit name", "unit_name")
	supplierIdx, _ := firstHeaderMatch(hdr, "default supplier", "supplier", "default_supplier")
	costIdx, _ := firstHeaderMatch(hdr, "cost price", "cost_price")
	sellIdx, _ := firstHeaderMatch(hdr, "selling price", "selling_price")
	reorderIdx, _ := firstHeaderMatch(hdr, "reorder level", "reorder_level")
	weightIdx, _ := firstHeaderMatch(hdr, "weight")
	dimIdx, _ := firstHeaderMatch(hdr, "dimensions")
	serializedIdx, _ := firstHeaderMatch(hdr, "is serialized", "is_serialized", "serialized")
	activeIdx, _ := firstHeaderMatch(hdr, "is active", "is_active", "active")
	packIdx, _ := firstHeaderMatch(hdr, "pack size", "pack_size")
	bcCostIdx, _ := firstHeaderMatch(hdr, "barcode cost price", "barcode_cost_price")
	bcSellIdx, _ := firstHeaderMatch(hdr, "barcode selling price", "barcode_selling_price")
	primaryIdx, _ := firstHeaderMatch(hdr, "is primary barcode", "is_primary", "primary")

	groups := make(map[string]*inventoryGroup)
	skus := make([]string, 0)
	barcodes := make([]string, 0)

	res := &models.ImportResult{Errors: make([]models.ImportRowError, 0)}
	for i, row := range rows[1:] {
		rowNum := i + 2
		name := cell(row, nameIdx)
		if name == "" {
			res.Skipped++
			continue
		}

		sku := cell(row, skuIdx)
		key := sku
		if key == "" {
			key = "name:" + strings.ToLower(name)
		}

		g, exists := groups[key]
		if !exists {
			g = &inventoryGroup{Name: name}
			if sku != "" {
				g.SKU = sku
				skus = append(skus, sku)
			}
			groups[key] = g
		} else if g.Name != name && name != "" {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Name", Message: "conflicting values for the same SKU/group"})
			res.Skipped++
			continue
		}

		if v := cell(row, descIdx); v != "" {
			if g.Description != nil && *g.Description != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Description", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.Description = &v
		}
		if v := cell(row, categoryIdx); v != "" {
			if g.Category != nil && *g.Category != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Category", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.Category = &v
		}
		if v := cell(row, brandIdx); v != "" {
			if g.Brand != nil && *g.Brand != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Brand", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.Brand = &v
		}
		if v := cell(row, unitIdx); v != "" {
			if g.Unit != nil && *g.Unit != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Unit", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.Unit = &v
		}

		tax := cell(row, taxIdx)
		if tax == "" {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Tax", Message: "tax is required"})
			res.Skipped++
			continue
		}
		if g.Tax != "" && g.Tax != tax {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Tax", Message: "conflicting values for the same SKU/group"})
			res.Skipped++
			continue
		}
		g.Tax = tax

		if v := cell(row, supplierIdx); v != "" {
			if g.DefaultSupplier != nil && *g.DefaultSupplier != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Default Supplier", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.DefaultSupplier = &v
		}

		if v := cell(row, costIdx); v != "" {
			if f, ok := parseFloatLoose(v); ok {
				if g.CostPrice != nil && *g.CostPrice != f {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Cost Price", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.CostPrice = &f
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Cost Price", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}
		if v := cell(row, sellIdx); v != "" {
			if f, ok := parseFloatLoose(v); ok {
				if g.SellingPrice != nil && *g.SellingPrice != f {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Selling Price", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.SellingPrice = &f
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Selling Price", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}
		if v := cell(row, reorderIdx); v != "" {
			if n, ok := parseIntLoose(v); ok {
				if g.ReorderLevel != nil && *g.ReorderLevel != n {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Reorder Level", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.ReorderLevel = &n
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Reorder Level", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}
		if v := cell(row, weightIdx); v != "" {
			if f, ok := parseFloatLoose(v); ok {
				if g.Weight != nil && *g.Weight != f {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Weight", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.Weight = &f
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Weight", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}
		if v := cell(row, dimIdx); v != "" {
			if g.Dimensions != nil && *g.Dimensions != v {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Dimensions", Message: "conflicting values for the same SKU/group"})
				res.Skipped++
				continue
			}
			g.Dimensions = &v
		}
		if v := cell(row, serializedIdx); v != "" {
			if b, ok := parseBoolLoose(v); ok {
				if g.IsSerialized != nil && *g.IsSerialized != b {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Serialized", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.IsSerialized = &b
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Serialized", Message: "invalid boolean (use true/false)"})
				res.Skipped++
				continue
			}
		}
		if v := cell(row, activeIdx); v != "" {
			if b, ok := parseBoolLoose(v); ok {
				if g.IsActive != nil && *g.IsActive != b {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Active", Message: "conflicting values for the same SKU/group"})
					res.Skipped++
					continue
				}
				g.IsActive = &b
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Active", Message: "invalid boolean (use true/false)"})
				res.Skipped++
				continue
			}
		}

		barcode := cell(row, barcodeIdx)
		if barcode == "" {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Barcode", Message: "barcode is required"})
			res.Skipped++
			continue
		}
		barcodes = append(barcodes, barcode)

		packSize := 1
		if v := cell(row, packIdx); v != "" {
			if n, ok := parseIntLoose(v); ok && n >= 1 {
				packSize = n
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Pack Size", Message: "invalid number (min 1)"})
				res.Skipped++
				continue
			}
		}

		var bcCost *float64
		if v := cell(row, bcCostIdx); v != "" {
			if f, ok := parseFloatLoose(v); ok {
				bcCost = &f
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Barcode Cost Price", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}
		var bcSell *float64
		if v := cell(row, bcSellIdx); v != "" {
			if f, ok := parseFloatLoose(v); ok {
				bcSell = &f
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Barcode Selling Price", Message: "invalid number"})
				res.Skipped++
				continue
			}
		}

		isPrimary := false
		if v := cell(row, primaryIdx); v != "" {
			if b, ok := parseBoolLoose(v); ok {
				isPrimary = b
			} else {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Primary Barcode", Message: "invalid boolean (use true/false)"})
				res.Skipped++
				continue
			}
		}

		g.Barcodes = append(g.Barcodes, models.ProductBarcode{
			Barcode:      barcode,
			PackSize:     packSize,
			CostPrice:    bcCost,
			SellingPrice: bcSell,
			IsPrimary:    isPrimary,
		})
	}

	if len(groups) == 0 {
		res.Count = 0
		return res, nil
	}

	// Build lookup maps for IDs
	catByName := map[string]int{}
	brandByName := map[string]int{}
	unitByName := map[string]int{}
	taxByName := map[string]int{}
	supByName := map[string]int{}

	if rows, err := s.db.Query(`SELECT category_id, name FROM categories WHERE company_id=$1 AND is_active=TRUE`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				catByName[normalizeHeader(name)] = id
			}
		}
	}
	if rows, err := s.db.Query(`SELECT brand_id, name FROM brands WHERE company_id=$1 AND is_active=TRUE`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				brandByName[normalizeHeader(name)] = id
			}
		}
	}
	if rows, err := s.db.Query(`SELECT unit_id, name, COALESCE(symbol,'') FROM units`); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			var sym string
			if err := rows.Scan(&id, &name, &sym); err == nil {
				if name != "" {
					unitByName[normalizeHeader(name)] = id
				}
				if sym != "" {
					unitByName[normalizeHeader(sym)] = id
				}
			}
		}
	}
	if rows, err := s.db.Query(`SELECT tax_id, name FROM taxes WHERE company_id=$1 AND is_active=TRUE`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				taxByName[normalizeHeader(name)] = id
			}
		}
	}
	if rows, err := s.db.Query(`SELECT supplier_id, name FROM suppliers WHERE company_id=$1 AND is_active=TRUE`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				supByName[normalizeHeader(name)] = id
			}
		}
	}

	resolveID := func(raw *string, byName map[string]int) (*int, error) {
		if raw == nil {
			return nil, nil
		}
		v := strings.TrimSpace(*raw)
		if v == "" {
			return nil, nil
		}
		if id, ok := parseIntLoose(v); ok && id > 0 {
			return &id, nil
		}
		if id, ok := byName[normalizeHeader(v)]; ok {
			return &id, nil
		}
		return nil, fmt.Errorf("unknown value: %s", v)
	}
	resolveTaxID := func(raw string) (int, error) {
		v := strings.TrimSpace(raw)
		if v == "" {
			return 0, fmt.Errorf("tax is required")
		}
		if id, ok := parseIntLoose(v); ok && id > 0 {
			return id, nil
		}
		if id, ok := taxByName[normalizeHeader(v)]; ok {
			return id, nil
		}
		return 0, fmt.Errorf("unknown tax: %s", v)
	}

	skuToProductID := map[string]int{}
	if len(skus) > 0 {
		rows, err := s.db.Query(`SELECT product_id, sku FROM products WHERE company_id=$1 AND is_deleted=FALSE AND sku = ANY($2)`, companyID, pq.Array(skus))
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var id int
				var sku sql.NullString
				if err := rows.Scan(&id, &sku); err == nil && sku.Valid {
					skuToProductID[sku.String] = id
				}
			}
		}
	}
	barcodeToProductID := map[string]int{}
	if len(barcodes) > 0 {
		rows, err := s.db.Query(`
			SELECT p.product_id, pb.barcode
			FROM products p
			JOIN product_barcodes pb ON pb.product_id = p.product_id
			WHERE p.company_id=$1 AND p.is_deleted=FALSE AND pb.barcode = ANY($2)
		`, companyID, pq.Array(barcodes))
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var id int
				var bc string
				if err := rows.Scan(&id, &bc); err == nil {
					barcodeToProductID[bc] = id
				}
			}
		}
	}

	ps := NewProductService()
	for _, g := range groups {
		if len(g.Barcodes) == 0 {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': no barcodes provided", g.Name)})
			res.Skipped++
			continue
		}

		primaryCount := 0
		for i := range g.Barcodes {
			if g.Barcodes[i].IsPrimary {
				primaryCount++
			}
			if g.Barcodes[i].PackSize <= 0 {
				g.Barcodes[i].PackSize = 1
			}
		}
		if primaryCount == 0 {
			g.Barcodes[0].IsPrimary = true
		} else if primaryCount > 1 {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': multiple primary barcodes", g.Name)})
			res.Skipped++
			continue
		}

		taxID, err := resolveTaxID(g.Tax)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}
		catID, err := resolveID(g.Category, catByName)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': category %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}
		brandID, err := resolveID(g.Brand, brandByName)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': brand %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}
		unitID, err := resolveID(g.Unit, unitByName)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': unit %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}
		supID, err := resolveID(g.DefaultSupplier, supByName)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': default supplier %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}

		var productID int
		if g.SKU != "" {
			productID = skuToProductID[g.SKU]
		}
		barcodeIDs := make(map[int]struct{})
		for _, bc := range g.Barcodes {
			if id := barcodeToProductID[bc.Barcode]; id != 0 {
				barcodeIDs[id] = struct{}{}
			}
		}
		if len(barcodeIDs) > 1 {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': barcodes match multiple existing products", g.Name)})
			res.Skipped++
			continue
		}
		var barcodeProductID int
		for id := range barcodeIDs {
			barcodeProductID = id
		}
		if productID != 0 && barcodeProductID != 0 && productID != barcodeProductID {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': SKU and barcode refer to different products", g.Name)})
			res.Skipped++
			continue
		}
		if productID == 0 {
			productID = barcodeProductID
		}

		if productID == 0 {
			req := &models.CreateProductRequest{
				CategoryID:        catID,
				BrandID:           brandID,
				UnitID:            unitID,
				TaxID:             taxID,
				Name:              g.Name,
				SKU:               nil,
				Description:       g.Description,
				CostPrice:         g.CostPrice,
				SellingPrice:      g.SellingPrice,
				ReorderLevel:      0,
				Weight:            g.Weight,
				Dimensions:        g.Dimensions,
				IsSerialized:      false,
				Barcodes:          g.Barcodes,
				DefaultSupplierID: supID,
			}
			if g.SKU != "" {
				req.SKU = &g.SKU
			}
			if g.ReorderLevel != nil {
				req.ReorderLevel = *g.ReorderLevel
			}
			if g.IsSerialized != nil {
				req.IsSerialized = *g.IsSerialized
			}

			if err := utils.ValidateStruct(req); err != nil {
				res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': validation failed", g.Name)})
				res.Skipped++
				continue
			}

			p, err := ps.CreateProduct(companyID, userID, req)
			if err != nil {
				res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': %s", g.Name, err.Error())})
				res.Skipped++
				continue
			}
			res.Created++

			if g.IsActive != nil && *g.IsActive == false {
				_, _ = ps.UpdateProduct(p.ProductID, companyID, userID, &models.UpdateProductRequest{IsActive: g.IsActive})
			}
			continue
		}

		req := &models.UpdateProductRequest{
			CategoryID:        catID,
			BrandID:           brandID,
			UnitID:            unitID,
			TaxID:             &taxID,
			Barcodes:          g.Barcodes,
			DefaultSupplierID: supID,
		}
		name := g.Name
		req.Name = &name
		if g.SKU != "" {
			req.SKU = &g.SKU
		}
		req.Description = g.Description
		req.CostPrice = g.CostPrice
		req.SellingPrice = g.SellingPrice
		req.ReorderLevel = g.ReorderLevel
		req.Weight = g.Weight
		req.Dimensions = g.Dimensions
		req.IsSerialized = g.IsSerialized
		req.IsActive = g.IsActive

		if _, err := ps.UpdateProduct(productID, companyID, userID, req); err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Message: fmt.Sprintf("product '%s': %s", g.Name, err.Error())})
			res.Skipped++
			continue
		}
		res.Updated++
	}

	res.Count = res.Created + res.Updated
	return res, nil
}

// ExportInventory returns inventory data as an Excel file
func (s *InventoryService) ExportInventory(companyID int) ([]byte, error) {
	type prod struct {
		ID           int
		SKU          sql.NullString
		Name         string
		Description  sql.NullString
		Category     sql.NullString
		Brand        sql.NullString
		Unit         sql.NullString
		Tax          sql.NullString
		Supplier     sql.NullString
		CostPrice    sql.NullFloat64
		SellingPrice sql.NullFloat64
		ReorderLevel int
		Weight       sql.NullFloat64
		Dimensions   sql.NullString
		IsSerialized bool
		IsActive     bool
	}

	rows, err := s.db.Query(`
		SELECT p.product_id, p.sku, p.name,
		       COALESCE(p.description,''), COALESCE(c.name,''), COALESCE(b.name,''),
		       COALESCE(NULLIF(u.symbol,''), u.name, ''), COALESCE(t.name,''), COALESCE(sup.name,''),
		       p.cost_price, p.selling_price, p.reorder_level, p.weight, p.dimensions, p.is_serialized, p.is_active
		FROM products p
		LEFT JOIN categories c ON p.category_id = c.category_id
		LEFT JOIN brands b ON p.brand_id = b.brand_id
		LEFT JOIN units u ON p.unit_id = u.unit_id
		LEFT JOIN taxes t ON p.tax_id = t.tax_id
		LEFT JOIN suppliers sup ON p.default_supplier_id = sup.supplier_id
		WHERE p.company_id=$1 AND p.is_deleted=FALSE
		ORDER BY p.name
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch products: %w", err)
	}
	defer rows.Close()

	products := make([]prod, 0)
	productIDs := make([]int, 0)
	for rows.Next() {
		var p prod
		if err := rows.Scan(
			&p.ID, &p.SKU, &p.Name, &p.Description, &p.Category, &p.Brand, &p.Unit, &p.Tax, &p.Supplier,
			&p.CostPrice, &p.SellingPrice, &p.ReorderLevel, &p.Weight, &p.Dimensions, &p.IsSerialized, &p.IsActive,
		); err != nil {
			return nil, fmt.Errorf("failed to scan product: %w", err)
		}
		products = append(products, p)
		productIDs = append(productIDs, p.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read products: %w", err)
	}

	type bc struct {
		ProductID    int
		Barcode      string
		PackSize     int
		CostPrice    sql.NullFloat64
		SellingPrice sql.NullFloat64
		IsPrimary    bool
	}
	barcodesByProduct := make(map[int][]bc)
	if len(productIDs) > 0 {
		bRows, err := s.db.Query(`
			SELECT product_id, barcode, pack_size, cost_price, selling_price, is_primary
			FROM product_barcodes
			WHERE product_id = ANY($1)
			ORDER BY product_id, is_primary DESC, barcode_id
		`, pq.Array(productIDs))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch barcodes: %w", err)
		}
		defer bRows.Close()
		for bRows.Next() {
			var b bc
			if err := bRows.Scan(&b.ProductID, &b.Barcode, &b.PackSize, &b.CostPrice, &b.SellingPrice, &b.IsPrimary); err != nil {
				return nil, fmt.Errorf("failed to scan barcode: %w", err)
			}
			barcodesByProduct[b.ProductID] = append(barcodesByProduct[b.ProductID], b)
		}
		if err := bRows.Err(); err != nil {
			return nil, fmt.Errorf("failed to read barcodes: %w", err)
		}
	}

	f := excelize.NewFile()
	sheet := "Inventory"
	f.SetSheetName("Sheet1", sheet)
	for i, h := range inventoryImportHeaders {
		cellName, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cellName, h)
	}
	_ = f.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, YSplit: 1, TopLeftCell: "A2", ActivePane: "bottomLeft"})
	_ = f.AutoFilter(sheet, "A1:T1", nil)

	rowNum := 2
	for _, p := range products {
		bcs := barcodesByProduct[p.ID]
		if len(bcs) == 0 {
			bcs = []bc{{ProductID: p.ID, Barcode: "", PackSize: 1, IsPrimary: true}}
		}
		for _, b := range bcs {
			if p.SKU.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("A%d", rowNum), p.SKU.String)
			}
			f.SetCellValue(sheet, fmt.Sprintf("B%d", rowNum), p.Name)
			if p.Description.Valid && p.Description.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("C%d", rowNum), p.Description.String)
			}
			if p.Category.Valid && p.Category.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("D%d", rowNum), p.Category.String)
			}
			if p.Brand.Valid && p.Brand.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("E%d", rowNum), p.Brand.String)
			}
			if p.Unit.Valid && p.Unit.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("F%d", rowNum), p.Unit.String)
			}
			if p.Tax.Valid && p.Tax.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("G%d", rowNum), p.Tax.String)
			}
			if p.Supplier.Valid && p.Supplier.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("H%d", rowNum), p.Supplier.String)
			}
			if p.CostPrice.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("I%d", rowNum), p.CostPrice.Float64)
			}
			if p.SellingPrice.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("J%d", rowNum), p.SellingPrice.Float64)
			}
			f.SetCellValue(sheet, fmt.Sprintf("K%d", rowNum), p.ReorderLevel)
			if p.Weight.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("L%d", rowNum), p.Weight.Float64)
			}
			if p.Dimensions.Valid && p.Dimensions.String != "" {
				f.SetCellValue(sheet, fmt.Sprintf("M%d", rowNum), p.Dimensions.String)
			}
			f.SetCellValue(sheet, fmt.Sprintf("N%d", rowNum), p.IsSerialized)
			f.SetCellValue(sheet, fmt.Sprintf("O%d", rowNum), p.IsActive)

			f.SetCellValue(sheet, fmt.Sprintf("P%d", rowNum), b.Barcode)
			f.SetCellValue(sheet, fmt.Sprintf("Q%d", rowNum), b.PackSize)
			if b.CostPrice.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("R%d", rowNum), b.CostPrice.Float64)
			}
			if b.SellingPrice.Valid {
				f.SetCellValue(sheet, fmt.Sprintf("S%d", rowNum), b.SellingPrice.Float64)
			}
			f.SetCellValue(sheet, fmt.Sprintf("T%d", rowNum), b.IsPrimary)
			rowNum++
		}
	}

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}

// GenerateBarcode creates barcode labels for the provided products
func (s *InventoryService) GenerateBarcode(companyID int, req *models.BarcodeRequest) ([]byte, error) {
	// Placeholder - return empty PDF/label content
	return []byte{}, nil
}

// GetProductTransactions returns a combined chronological list of stock-affecting
// transactions for a single product at an optional location.
func (s *InventoryService) GetProductTransactions(companyID int, productID int, locationID *int, limit *int, fromDate, toDate string) ([]models.ProductTransaction, error) {
	args := []interface{}{companyID, productID}
	idx := 3

	// Helper to add optional filters to each SELECT
	buildWhere := func(base string, locCol string, dateCol string) (string, []interface{}, int) {
		q := base
		a := make([]interface{}, 0)
		added := 0
		if locationID != nil {
			q += fmt.Sprintf(" AND %s = $%d", locCol, idx)
			a = append(a, *locationID)
			idx++
			added++
		}
		if fromDate != "" {
			q += fmt.Sprintf(" AND %s >= $%d", dateCol, idx)
			a = append(a, fromDate)
			idx++
			added++
		}
		if toDate != "" {
			q += fmt.Sprintf(" AND %s <= $%d", dateCol, idx)
			a = append(a, toDate)
			idx++
			added++
		}
		return q, a, added
	}

	selects := make([]string, 0)
	selectArgs := make([]interface{}, 0)

	// Sales (outgoing)
	{
		base := `
            SELECT
                'SALE' AS type,
                s.created_at AS occurred_at,
                s.sale_number AS reference,
                -sd.quantity AS quantity,
                s.location_id AS location_id,
                l.name AS location_name,
                c.name AS partner_name,
                'sale' AS entity,
                s.sale_id AS entity_id,
                s.notes AS notes
            FROM sale_details sd
            JOIN sales s ON sd.sale_id = s.sale_id
            JOIN locations l ON s.location_id = l.location_id
            LEFT JOIN customers c ON s.customer_id = c.customer_id
            WHERE l.company_id = $1 AND sd.product_id = $2 AND s.is_deleted = FALSE`
		with, a, _ := buildWhere(base, "s.location_id", "s.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Sale returns (incoming)
	{
		base := `
            SELECT
                'SALE_RETURN' AS type,
                sr.created_at AS occurred_at,
                sr.return_number AS reference,
                srd.quantity AS quantity,
                sr.location_id AS location_id,
                l.name AS location_name,
                c.name AS partner_name,
                'sale_return' AS entity,
                sr.return_id AS entity_id,
                NULL AS notes
            FROM sale_return_details srd
            JOIN sale_returns sr ON srd.return_id = sr.return_id
            JOIN locations l ON sr.location_id = l.location_id
            LEFT JOIN customers c ON sr.customer_id = c.customer_id
            WHERE l.company_id = $1 AND srd.product_id = $2 AND sr.is_deleted = FALSE`
		with, a, _ := buildWhere(base, "sr.location_id", "sr.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Purchases (incoming) via Goods Receipts - show GRN number and per-receipt quantities
	{
		base := `
            SELECT
                'PURCHASE' AS type,
                gr.received_date AS occurred_at,
                gr.receipt_number AS reference,
                gri.received_quantity AS quantity,
                gr.location_id AS location_id,
                l.name AS location_name,
                s.name AS partner_name,
                'goods_receipt' AS entity,
                gr.goods_receipt_id AS entity_id,
                NULL AS notes
            FROM goods_receipt_items gri
            JOIN goods_receipts gr ON gri.goods_receipt_id = gr.goods_receipt_id
            JOIN locations l ON gr.location_id = l.location_id
            LEFT JOIN suppliers s ON gr.supplier_id = s.supplier_id
            WHERE l.company_id = $1 AND gri.product_id = $2 AND gr.is_deleted = FALSE`
		with, a, _ := buildWhere(base, "gr.location_id", "gr.received_date")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Purchase returns (outgoing)
	{
		base := `
            SELECT
                'PURCHASE_RETURN' AS type,
                pr.created_at AS occurred_at,
                pr.return_number AS reference,
                -prd.quantity AS quantity,
                pr.location_id AS location_id,
                l.name AS location_name,
                s.name AS partner_name,
                'purchase_return' AS entity,
                pr.return_id AS entity_id,
                NULL AS notes
            FROM purchase_return_details prd
            JOIN purchase_returns pr ON prd.return_id = pr.return_id
            JOIN locations l ON pr.location_id = l.location_id
            LEFT JOIN suppliers s ON pr.supplier_id = s.supplier_id
            WHERE l.company_id = $1 AND prd.product_id = $2 AND pr.is_deleted = FALSE`
		with, a, _ := buildWhere(base, "pr.location_id", "pr.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Stock adjustments (could be +/-). If originating document exists, show its number and link to document.
	{
		base := `
            SELECT
                'ADJUSTMENT' AS type,
                sa.created_at AS occurred_at,
                COALESCE(d.document_number, CONCAT('ADJ-', sa.adjustment_id)) AS reference,
                sa.adjustment AS quantity,
                sa.location_id AS location_id,
                l.name AS location_name,
                NULL AS partner_name,
                CASE WHEN d.document_id IS NULL THEN 'stock_adjustment' ELSE 'stock_adjustment_document' END AS entity,
                COALESCE(d.document_id, sa.adjustment_id) AS entity_id,
                sa.reason AS notes
            FROM stock_adjustments sa
            JOIN locations l ON sa.location_id = l.location_id
            LEFT JOIN stock_adjustment_documents d
              ON d.location_id = sa.location_id
             AND sa.reason LIKE d.document_number || '%'
            WHERE l.company_id = $1 AND sa.product_id = $2`
		with, a, _ := buildWhere(base, "sa.location_id", "sa.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Transfers OUT (outgoing from source)
	{
		base := `
            SELECT
                'TRANSFER_OUT' AS type,
                st.created_at AS occurred_at,
                st.transfer_number AS reference,
                -std.quantity AS quantity,
                st.from_location_id AS location_id,
                lf.name AS location_name,
                NULL AS partner_name,
                'transfer' AS entity,
                st.transfer_id AS entity_id,
                st.notes AS notes
            FROM stock_transfer_details std
            JOIN stock_transfers st ON std.transfer_id = st.transfer_id
            JOIN locations lf ON st.from_location_id = lf.location_id
            JOIN locations lt ON st.to_location_id = lt.location_id
            WHERE (lf.company_id = $1 OR lt.company_id = $1) AND std.product_id = $2`
		with, a, _ := buildWhere(base, "st.from_location_id", "st.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Transfers IN (incoming to destination)
	{
		base := `
            SELECT
                'TRANSFER_IN' AS type,
                st.created_at AS occurred_at,
                st.transfer_number AS reference,
                std.quantity AS quantity,
                st.to_location_id AS location_id,
                lt.name AS location_name,
                NULL AS partner_name,
                'transfer' AS entity,
                st.transfer_id AS entity_id,
                st.notes AS notes
            FROM stock_transfer_details std
            JOIN stock_transfers st ON std.transfer_id = st.transfer_id
            JOIN locations lf ON st.from_location_id = lf.location_id
            JOIN locations lt ON st.to_location_id = lt.location_id
            WHERE (lf.company_id = $1 OR lt.company_id = $1) AND std.product_id = $2`
		with, a, _ := buildWhere(base, "st.to_location_id", "st.created_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	query := "(" + selects[0] + ")"
	for i := 1; i < len(selects); i++ {
		query += " UNION ALL (" + selects[i] + ")"
	}
	query += " ORDER BY occurred_at DESC"
	if limit != nil && *limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", idx)
		selectArgs = append(selectArgs, *limit)
		idx++
	}

	// Final args: base (company, product) + per-select additions + optional limit
	finalArgs := append([]interface{}{}, args...)
	finalArgs = append(finalArgs, selectArgs...)

	rows, err := s.db.Query(query, finalArgs...)
	if err != nil {
		return nil, fmt.Errorf("failed to get product transactions: %w", err)
	}
	defer rows.Close()

	res := make([]models.ProductTransaction, 0)
	for rows.Next() {
		var t models.ProductTransaction
		var occurredAt time.Time
		var partner *string
		var notes *string
		var locationName string
		if err := rows.Scan(&t.Type, &occurredAt, &t.Reference, &t.Quantity, &t.LocationID, &locationName, &partner, &t.Entity, &t.EntityID, &notes); err != nil {
			return nil, fmt.Errorf("failed to scan product transaction: %w", err)
		}
		t.OccurredAt = occurredAt
		t.LocationName = locationName
		t.PartnerName = partner
		t.Notes = notes
		res = append(res, t)
	}
	return res, nil
}
