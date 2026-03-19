package services

import (
	"bytes"
	"database/sql"
	"encoding/json"
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

type transferLotSnapshot struct {
	LotID             int
	BatchNumber       *string
	ExpiryDate        *time.Time
	RemainingQuantity float64
	CostPrice         float64
}

type transferIssueSnapshot struct {
	Variant          *resolvedVariant
	BatchAllocations []models.InventoryBatchSelectionInput
}

func encodeBatchAllocations(inputs []models.InventoryBatchSelectionInput) []byte {
	if len(inputs) == 0 {
		return []byte("[]")
	}
	raw, err := json.Marshal(inputs)
	if err != nil {
		return []byte("[]")
	}
	return raw
}

func decodeBatchAllocations(raw []byte) []models.InventoryBatchSelectionInput {
	if len(raw) == 0 {
		return nil
	}
	var items []models.InventoryBatchSelectionInput
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil
	}
	return items
}

func (s *InventoryService) validateProductInCompanyTx(tx *sql.Tx, companyID, productID int) error {
	var productCompanyID int
	err := tx.QueryRow("SELECT company_id FROM products WHERE product_id = $1 AND is_deleted = FALSE", productID).Scan(&productCompanyID)
	if err == sql.ErrNoRows || productCompanyID != companyID {
		return fmt.Errorf("product not found")
	}
	if err != nil {
		return fmt.Errorf("failed to verify product: %w", err)
	}
	return nil
}

func (s *InventoryService) loadTransferLotSnapshotTx(tx *sql.Tx, companyID, fromLocationID int, lotID int) (*transferLotSnapshot, error) {
	var snap transferLotSnapshot
	err := tx.QueryRow(`
		SELECT lot_id, batch_number, expiry_date, remaining_quantity::float8, cost_price::float8
		FROM stock_lots
		WHERE company_id = $1 AND location_id = $2 AND lot_id = $3
		FOR UPDATE
	`, companyID, fromLocationID, lotID).Scan(
		&snap.LotID, &snap.BatchNumber, &snap.ExpiryDate, &snap.RemainingQuantity, &snap.CostPrice,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("selected batch not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load stock lot: %w", err)
	}
	return &snap, nil
}

func (s *InventoryService) loadTransferIssueUnitCostTx(tx *sql.Tx, companyID, fromLocationID, transferDetailID, lotID int) (float64, error) {
	var unitCost float64
	query := `
		SELECT ABS(unit_cost)::float8
		FROM inventory_movements
		WHERE company_id = $1
		  AND location_id = $2
		  AND movement_type = 'TRANSFER_OUT'
		  AND source_type = 'stock_transfer_detail'
		  AND source_line_id = $3
	`
	args := []interface{}{companyID, fromLocationID, transferDetailID}
	if lotID > 0 {
		query += ` AND stock_lot_id = $4`
		args = append(args, lotID)
	} else {
		query += ` AND stock_lot_id IS NULL`
	}
	query += ` LIMIT 1`
	err := tx.QueryRow(query, args...).Scan(&unitCost)
	if err == sql.ErrNoRows {
		return 0, fmt.Errorf("transfer issue cost not found")
	}
	if err != nil {
		return 0, fmt.Errorf("failed to load transfer issue cost: %w", err)
	}
	return unitCost, nil
}

func (s *InventoryService) GetStock(companyID, locationID int, productID *int, itemType *string) ([]models.StockWithProduct, error) {
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
            pb.barcode_id,
            CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END AS tracking_type,
            CASE WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized,
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
        LEFT JOIN LATERAL (
            SELECT barcode_id
            FROM product_barcodes
            WHERE product_id = p.product_id
              AND COALESCE(is_active, TRUE) = TRUE
            ORDER BY is_primary DESC, barcode_id
            LIMIT 1
        ) pb ON TRUE
        WHERE p.company_id = $1 AND p.is_deleted = FALSE
    `

	args := []interface{}{companyID, locationID}
	argCount := 2

	if productID != nil {
		argCount++
		query += fmt.Sprintf(" AND p.product_id = $%d", argCount)
		args = append(args, *productID)
	}
	if itemType != nil && strings.TrimSpace(*itemType) != "" {
		argCount++
		query += fmt.Sprintf(" AND COALESCE(p.item_type, 'PRODUCT') = $%d", argCount)
		args = append(args, normalizeProductItemType(*itemType))
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
			&item.BarcodeID, &item.TrackingType, &item.IsSerialized, &item.ReorderLevel, &item.CategoryID,
			&item.CategoryName, &item.BrandName, &item.UnitSymbol,
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

func (s *InventoryService) GetStockVariants(companyID, locationID, productID int) ([]models.StockVariant, error) {
	rows, err := s.db.Query(`
		SELECT
			COALESCE(sv.stock_variant_id, 0) AS stock_variant_id,
			$2 AS location_id,
			p.product_id,
			pb.barcode_id,
			pb.barcode,
			pb.variant_name,
			COALESCE(pb.variant_attributes, '{}'::jsonb),
			COALESCE(sv.quantity, 0)::float8 AS quantity,
			COALESCE(sv.reserved_quantity, 0)::float8 AS reserved_quantity,
			COALESCE(sv.average_cost, COALESCE(pb.cost_price, p.cost_price, 0))::float8 AS average_cost,
			COALESCE(pb.selling_price, p.selling_price, 0)::float8 AS selling_price,
			CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END AS tracking_type,
			CASE WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized,
			COALESCE(sv.last_updated, CURRENT_TIMESTAMP)
		FROM products p
		JOIN product_barcodes pb ON pb.product_id = p.product_id
		LEFT JOIN stock_variants sv ON sv.location_id = $2 AND sv.barcode_id = pb.barcode_id
		WHERE p.company_id = $1
		  AND p.product_id = $3
		  AND p.is_deleted = FALSE
		  AND COALESCE(pb.is_active, TRUE) = TRUE
		ORDER BY pb.is_primary DESC, pb.barcode_id
	`, companyID, locationID, productID)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock variants: %w", err)
	}
	defer rows.Close()

	items := make([]models.StockVariant, 0)
	for rows.Next() {
		var item models.StockVariant
		if err := rows.Scan(
			&item.StockVariantID, &item.LocationID, &item.ProductID, &item.BarcodeID,
			&item.Barcode, &item.VariantName, &item.VariantAttributes, &item.Quantity,
			&item.ReservedQuantity, &item.AverageCost, &item.SellingPrice, &item.TrackingType, &item.IsSerialized,
			&item.LastUpdated,
		); err != nil {
			return nil, fmt.Errorf("failed to scan stock variant: %w", err)
		}
		item.TrackingType = normalizeTrackingType(item.TrackingType)
		items = append(items, item)
	}
	return items, nil
}

func (s *InventoryService) GetStockBatches(companyID, locationID, productID int, barcodeID *int) ([]models.StockLot, error) {
	args := []interface{}{companyID, locationID, productID}
	query := `
		SELECT
			sl.lot_id, sl.company_id, sl.product_id, sl.barcode_id, sl.location_id,
			sl.batch_number, sl.expiry_date, sl.received_date, sl.quantity::float8,
			sl.remaining_quantity::float8, sl.cost_price::float8, pb.barcode, pb.variant_name,
			COALESCE(pb.variant_attributes, '{}'::jsonb)
		FROM stock_lots sl
		JOIN locations l ON l.location_id = sl.location_id
		LEFT JOIN product_barcodes pb ON pb.barcode_id = sl.barcode_id
		WHERE sl.company_id = $1
		  AND l.company_id = $1
		  AND sl.location_id = $2
		  AND sl.product_id = $3
		  AND sl.remaining_quantity > 0
	`
	if barcodeID != nil && *barcodeID > 0 {
		query += " AND sl.barcode_id = $4"
		args = append(args, *barcodeID)
	}
	query += " ORDER BY sl.expiry_date NULLS LAST, sl.received_date, sl.lot_id"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock batches: %w", err)
	}
	defer rows.Close()

	items := make([]models.StockLot, 0)
	for rows.Next() {
		var item models.StockLot
		if err := rows.Scan(
			&item.LotID, &item.CompanyID, &item.ProductID, &item.BarcodeID, &item.LocationID,
			&item.BatchNumber, &item.ExpiryDate, &item.ReceivedDate, &item.Quantity,
			&item.RemainingQuantity, &item.CostPrice, &item.Barcode, &item.VariantName,
			&item.VariantAttributes,
		); err != nil {
			return nil, fmt.Errorf("failed to scan stock batch: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *InventoryService) GetAvailableSerials(companyID, locationID, productID int, barcodeID *int) ([]models.ProductSerial, error) {
	args := []interface{}{companyID, locationID, productID}
	query := `
		SELECT
			ps.product_serial_id, ps.company_id, ps.product_id, ps.barcode_id, ps.stock_lot_id,
			ps.serial_number, ps.location_id, ps.status, ps.cost_price::float8,
			ps.received_at, ps.sold_at, ps.last_movement_at, pb.barcode, pb.variant_name,
			CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END AS tracking_type,
			sl.batch_number, sl.expiry_date
		FROM product_serials ps
		JOIN products p ON p.product_id = ps.product_id
		LEFT JOIN product_barcodes pb ON pb.barcode_id = ps.barcode_id
		LEFT JOIN stock_lots sl ON sl.lot_id = ps.stock_lot_id
		WHERE ps.company_id = $1
		  AND ps.location_id = $2
		  AND ps.product_id = $3
		  AND ps.status = 'IN_STOCK'
	`
	if barcodeID != nil && *barcodeID > 0 {
		query += " AND ps.barcode_id = $4"
		args = append(args, *barcodeID)
	}
	query += " ORDER BY ps.serial_number"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get serials: %w", err)
	}
	defer rows.Close()

	items := make([]models.ProductSerial, 0)
	for rows.Next() {
		var item models.ProductSerial
		if err := rows.Scan(
			&item.ProductSerialID, &item.CompanyID, &item.ProductID, &item.BarcodeID, &item.StockLotID,
			&item.SerialNumber, &item.LocationID, &item.Status, &item.CostPrice,
			&item.ReceivedAt, &item.SoldAt, &item.LastMovementAt, &item.Barcode, &item.VariantName,
			&item.TrackingType, &item.BatchNumber, &item.ExpiryDate,
		); err != nil {
			return nil, fmt.Errorf("failed to scan serial: %w", err)
		}
		item.TrackingType = normalizeTrackingType(item.TrackingType)
		items = append(items, item)
	}
	return items, nil
}

func (s *InventoryService) AdjustStock(companyID, locationID, userID int, req *models.CreateStockAdjustmentRequest) error {
	if req.Adjustment == 0 {
		return fmt.Errorf("adjustment must be non-zero")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()
	if err := s.validateProductInCompanyTx(tx, companyID, req.ProductID); err != nil {
		return err
	}

	trackingSvc := newInventoryTrackingService(s.db)
	movementReason := req.Reason
	selection := inventorySelection{
		ProductID:        req.ProductID,
		BarcodeID:        req.BarcodeID,
		Quantity:         req.Adjustment,
		BatchAllocations: req.BatchAllocations,
		SerialNumbers:    req.SerialNumbers,
		BatchNumber:      req.BatchNumber,
		ExpiryDate:       req.ExpiryDate,
		Notes:            &movementReason,
		OverridePassword: req.OverridePassword,
	}
	if req.Adjustment > 0 {
		selection.UnitCost = 0
		if _, err := trackingSvc.ReceiveStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_IN", "stock_adjustment", nil, nil, selection); err != nil {
			return err
		}
	} else {
		selection.Quantity = -req.Adjustment
		if _, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_OUT", "stock_adjustment", nil, nil, selection); err != nil {
			return err
		}
	}

	if _, err := tx.Exec(`
		INSERT INTO stock_adjustments (location_id, product_id, adjustment, reason, created_by)
		VALUES ($1, $2, $3, $4, $5)
	`, locationID, req.ProductID, req.Adjustment, req.Reason, userID); err != nil {
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
	trackingSvc := newInventoryTrackingService(s.db)

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
		if err := s.validateProductInCompanyTx(tx, companyID, it.ProductID); err != nil {
			return nil, err
		}
		if it.Adjustment == 0 {
			return nil, fmt.Errorf("adjustment must be non-zero")
		}

		var itemID int
		if err := tx.QueryRow(`
            INSERT INTO stock_adjustment_document_items (
                document_id, product_id, barcode_id, adjustment, serial_numbers, batch_allocations
            )
            VALUES ($1,$2,$3,$4,$5,$6)
            RETURNING item_id
        `, docID, it.ProductID, it.BarcodeID, it.Adjustment, pq.Array(it.SerialNumbers), encodeBatchAllocations(it.BatchAllocations)).Scan(&itemID); err != nil {
			return nil, fmt.Errorf("failed to add document item: %w", err)
		}

		movementReason := fmt.Sprintf("%s | %s", docNumber, req.Reason)
		selection := inventorySelection{
			ProductID:        it.ProductID,
			BarcodeID:        it.BarcodeID,
			Quantity:         it.Adjustment,
			BatchAllocations: it.BatchAllocations,
			SerialNumbers:    it.SerialNumbers,
			BatchNumber:      it.BatchNumber,
			ExpiryDate:       it.ExpiryDate,
			Notes:            &movementReason,
			OverridePassword: req.OverridePassword,
		}
		if it.Adjustment > 0 {
			selection.UnitCost = 0
			if _, err := trackingSvc.ReceiveStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_IN", "stock_adjustment_document_item", &itemID, nil, selection); err != nil {
				return nil, fmt.Errorf("failed to adjust stock: %w", err)
			}
		} else {
			selection.Quantity = -it.Adjustment
			if _, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_OUT", "stock_adjustment_document_item", &itemID, nil, selection); err != nil {
				return nil, fmt.Errorf("failed to adjust stock: %w", err)
			}
		}

		if _, err := tx.Exec(`
            INSERT INTO stock_adjustments (location_id, product_id, adjustment, reason, created_by)
            VALUES ($1,$2,$3,$4,$5)
        `, locationID, it.ProductID, it.Adjustment, movementReason, userID); err != nil {
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
            SELECT item_id, document_id, product_id, barcode_id, adjustment, serial_numbers, COALESCE(batch_allocations, '[]'::jsonb)
            FROM stock_adjustment_document_items
            WHERE document_id = $1
            ORDER BY item_id
        `, d.DocumentID)
		if err == nil {
			var items []models.StockAdjustmentDocumentItem
			for itsRows.Next() {
				var it models.StockAdjustmentDocumentItem
				var serials pq.StringArray
				var batchAllocRaw []byte
				if err := itsRows.Scan(&it.ItemID, &it.DocumentID, &it.ProductID, &it.BarcodeID, &it.Adjustment, &serials, &batchAllocRaw); err == nil {
					it.SerialNumbers = []string(serials)
					it.BatchAllocations = decodeBatchAllocations(batchAllocRaw)
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
        SELECT item_id, document_id, product_id, barcode_id, adjustment, serial_numbers, COALESCE(batch_allocations, '[]'::jsonb)
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
		var serials pq.StringArray
		var batchAllocRaw []byte
		if err := rows.Scan(&it.ItemID, &it.DocumentID, &it.ProductID, &it.BarcodeID, &it.Adjustment, &serials, &batchAllocRaw); err != nil {
			return nil, fmt.Errorf("failed to scan item: %w", err)
		}
		it.SerialNumbers = []string(serials)
		it.BatchAllocations = decodeBatchAllocations(batchAllocRaw)
		items = append(items, it)
	}
	d.Items = items
	return &d, nil
}

func (s *InventoryService) transferTrackedStockTx(tx *sql.Tx, companyID, fromLocationID, toLocationID, userID int, sourceLineID *int, sourceRef *string, selection inventorySelection) error {
	issue, err := s.issueTransferTrackedStockTx(tx, companyID, fromLocationID, userID, sourceLineID, sourceRef, selection)
	if err != nil {
		return err
	}
	selection.BarcodeID = &issue.Variant.BarcodeID
	if len(issue.BatchAllocations) > 0 {
		selection.BatchAllocations = issue.BatchAllocations
	}
	return s.receiveTransferTrackedStockTx(tx, companyID, fromLocationID, toLocationID, userID, sourceLineID, sourceRef, selection)
}

func (s *InventoryService) issueTransferTrackedStockTx(tx *sql.Tx, companyID, fromLocationID, userID int, sourceLineID *int, sourceRef *string, selection inventorySelection) (*transferIssueSnapshot, error) {
	trackingSvc := newInventoryTrackingService(s.db)
	variant, err := trackingSvc.resolveVariantTx(tx, companyID, selection.ProductID, selection.BarcodeID)
	if err != nil {
		return nil, err
	}
	if selection.Quantity <= 0 {
		return nil, fmt.Errorf("quantity must be greater than zero")
	}

	snapshot := &transferIssueSnapshot{Variant: variant}
	if variant.IsSerialized {
		if selection.Quantity != float64(int(selection.Quantity)) {
			return nil, fmt.Errorf("serialized quantities must be whole numbers")
		}
		if len(selection.SerialNumbers) != int(selection.Quantity) {
			return nil, fmt.Errorf("serial numbers count must equal quantity")
		}
		records, err := trackingSvc.loadSerialsForIssueTx(tx, companyID, fromLocationID, variant, selection.SerialNumbers)
		if err != nil {
			return nil, err
		}
		for _, rec := range records {
			if rec.StockLotID != nil {
				if err := trackingSvc.consumeLotTx(tx, *rec.StockLotID, 1); err != nil {
					return nil, err
				}
			}
			if err := trackingSvc.markSerialStatusTx(tx, rec.ProductSerialID, "TRANSFER_IN_TRANSIT", nil); err != nil {
				return nil, fmt.Errorf("failed to update serial status: %w", err)
			}
			if err := trackingSvc.createMovementTx(tx, companyID, fromLocationID, variant, "TRANSFER_OUT", "stock_transfer_detail", sourceLineID, sourceRef, nil, rec.StockLotID, &rec.ProductSerialID, -1, rec.CostPrice, userID, selection.Notes); err != nil {
				return nil, err
			}
		}
	} else {
		lots, err := trackingSvc.loadAvailableLotsTx(tx, companyID, fromLocationID, variant)
		if err != nil {
			return nil, err
		}
		method, err := trackingSvc.getCompanyCostingMethodTx(tx, companyID)
		if err != nil {
			return nil, err
		}
		avgCost := variant.DefaultCostPrice
		if err := tx.QueryRow(`
			SELECT COALESCE(average_cost, 0)::float8
			FROM stock_variants
			WHERE location_id = $1 AND barcode_id = $2
		`, fromLocationID, variant.BarcodeID).Scan(&avgCost); err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get source average cost: %w", err)
		}

		allocations := make([]models.InventoryBatchSelectionInput, 0)
		if len(selection.BatchAllocations) > 0 {
			allocations = append(allocations, selection.BatchAllocations...)
		} else {
			if variant.TrackingType == trackingTypeBatch {
				return nil, fmt.Errorf("batch selection is required")
			}
			remaining := selection.Quantity
			for _, lot := range lots {
				if remaining <= 1e-9 {
					break
				}
				consumeQty := lot.RemainingQuantity
				if consumeQty > remaining {
					consumeQty = remaining
				}
				if consumeQty <= 0 {
					continue
				}
				allocations = append(allocations, models.InventoryBatchSelectionInput{
					LotID:    lot.LotID,
					Quantity: consumeQty,
				})
				remaining -= consumeQty
			}
			if remaining > 1e-9 {
				if err := trackingSvc.validateNegativeStockPolicyTx(tx, companyID, selection.OverridePassword); err != nil {
					if _, ok := err.(*NegativeStockApprovalRequiredError); ok {
						return nil, err
					}
					if err.Error() == "insufficient stock" || variant.TrackingType != trackingTypeVariant || variant.IsSerialized {
						return nil, fmt.Errorf("insufficient stock")
					}
					return nil, err
				}
				if variant.TrackingType != trackingTypeVariant || variant.IsSerialized {
					return nil, fmt.Errorf("insufficient stock")
				}
				allocations = append(allocations, models.InventoryBatchSelectionInput{
					LotID:    0,
					Quantity: remaining,
				})
			}
		}

		coveredQty := 0.0
		for _, alloc := range allocations {
			coveredQty += alloc.Quantity
			var lotID *int
			unitCost := avgCost
			if alloc.LotID > 0 {
				snap, err := s.loadTransferLotSnapshotTx(tx, companyID, fromLocationID, alloc.LotID)
				if err != nil {
					return nil, err
				}
				if alloc.Quantity > snap.RemainingQuantity+1e-9 {
					return nil, fmt.Errorf("insufficient quantity in selected batch")
				}
				if err := trackingSvc.consumeLotTx(tx, alloc.LotID, alloc.Quantity); err != nil {
					return nil, err
				}
				unitCost = snap.CostPrice
				lotID = &alloc.LotID
			} else if unitCost <= 0 {
				unitCost = variant.DefaultCostPrice
			}
			if method == costingMethodWAC && avgCost > 0 {
				unitCost = avgCost
			}
			if err := trackingSvc.createMovementTx(tx, companyID, fromLocationID, variant, "TRANSFER_OUT", "stock_transfer_detail", sourceLineID, sourceRef, nil, lotID, nil, -alloc.Quantity, unitCost, userID, selection.Notes); err != nil {
				return nil, err
			}
		}
		if coveredQty+1e-9 < selection.Quantity {
			return nil, fmt.Errorf("batch allocations do not cover requested quantity")
		}
		snapshot.BatchAllocations = allocations
	}

	if _, _, err := trackingSvc.adjustVariantBalanceTx(tx, companyID, fromLocationID, variant, -selection.Quantity, 0, selection.OverridePassword); err != nil {
		return nil, err
	}
	if err := trackingSvc.updateProductCostSnapshotTx(tx, companyID, variant.ProductID); err != nil {
		return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
	}
	return snapshot, nil
}

func (s *InventoryService) receiveTransferTrackedStockTx(tx *sql.Tx, companyID, fromLocationID, toLocationID, userID int, sourceLineID *int, sourceRef *string, selection inventorySelection) error {
	trackingSvc := newInventoryTrackingService(s.db)
	variant, err := trackingSvc.resolveVariantTx(tx, companyID, selection.ProductID, selection.BarcodeID)
	if err != nil {
		return err
	}
	if selection.Quantity <= 0 {
		return fmt.Errorf("quantity must be greater than zero")
	}

	totalCost := 0.0
	if variant.IsSerialized {
		if selection.Quantity != float64(int(selection.Quantity)) {
			return fmt.Errorf("serialized quantities must be whole numbers")
		}
		if len(selection.SerialNumbers) != int(selection.Quantity) {
			return fmt.Errorf("serial numbers count must equal quantity")
		}
		records, err := trackingSvc.loadSerialsForTransferReceiveTx(tx, companyID, variant, selection.SerialNumbers)
		if err != nil {
			return err
		}
		for _, rec := range records {
			var batchNumber *string
			var expiryDate *time.Time
			if rec.StockLotID != nil {
				snap, err := s.loadTransferLotSnapshotTx(tx, companyID, fromLocationID, *rec.StockLotID)
				if err != nil {
					return err
				}
				batchNumber = snap.BatchNumber
				expiryDate = snap.ExpiryDate
			}
			destLotID, err := trackingSvc.createLotTx(tx, companyID, toLocationID, variant, inventorySelection{
				ProductID:     variant.ProductID,
				BarcodeID:     &variant.BarcodeID,
				Quantity:      1,
				BatchNumber:   batchNumber,
				ExpiryDate:    expiryDate,
				UnitCost:      rec.CostPrice,
				SerialNumbers: []string{rec.SerialNumber},
				Notes:         selection.Notes,
			})
			if err != nil {
				return err
			}
			if _, err := tx.Exec(`
				UPDATE product_serials
				SET stock_lot_id = $1,
				    location_id = $2,
				    status = 'IN_STOCK',
				    cost_price = $3,
				    last_movement_at = CURRENT_TIMESTAMP
				WHERE product_serial_id = $4
			`, destLotID, toLocationID, rec.CostPrice, rec.ProductSerialID); err != nil {
				return fmt.Errorf("failed to relocate serial: %w", err)
			}
			if err := trackingSvc.createMovementTx(tx, companyID, toLocationID, variant, "TRANSFER_IN", "stock_transfer_detail", sourceLineID, sourceRef, nil, &destLotID, &rec.ProductSerialID, 1, rec.CostPrice, userID, selection.Notes); err != nil {
				return err
			}
			totalCost += rec.CostPrice
		}
	} else {
		if len(selection.BatchAllocations) == 0 {
			return fmt.Errorf("approved transfer is missing issued batch allocations")
		}
		coveredQty := 0.0
		for _, alloc := range selection.BatchAllocations {
			coveredQty += alloc.Quantity
			var batchNumber *string
			var expiryDate *time.Time
			unitCost := variant.DefaultCostPrice
			if alloc.LotID > 0 {
				snap, err := s.loadTransferLotSnapshotTx(tx, companyID, fromLocationID, alloc.LotID)
				if err != nil {
					return err
				}
				batchNumber = snap.BatchNumber
				expiryDate = snap.ExpiryDate
				unitCost = snap.CostPrice
			}
			if sourceLineID != nil {
				unitCost, err = s.loadTransferIssueUnitCostTx(tx, companyID, fromLocationID, *sourceLineID, alloc.LotID)
				if err != nil {
					return err
				}
			}
			destLotID, err := trackingSvc.createLotTx(tx, companyID, toLocationID, variant, inventorySelection{
				ProductID:   variant.ProductID,
				BarcodeID:   &variant.BarcodeID,
				Quantity:    alloc.Quantity,
				BatchNumber: batchNumber,
				ExpiryDate:  expiryDate,
				UnitCost:    unitCost,
				Notes:       selection.Notes,
			})
			if err != nil {
				return err
			}
			if err := trackingSvc.createMovementTx(tx, companyID, toLocationID, variant, "TRANSFER_IN", "stock_transfer_detail", sourceLineID, sourceRef, nil, &destLotID, nil, alloc.Quantity, unitCost, userID, selection.Notes); err != nil {
				return err
			}
			totalCost += alloc.Quantity * unitCost
		}
		if coveredQty+1e-9 < selection.Quantity {
			return fmt.Errorf("batch allocations do not cover requested quantity")
		}
	}

	inboundUnitCost := 0.0
	if selection.Quantity > 0 {
		inboundUnitCost = totalCost / selection.Quantity
	}
	if _, _, err := trackingSvc.adjustVariantBalanceTx(tx, companyID, toLocationID, variant, selection.Quantity, inboundUnitCost, nil); err != nil {
		return err
	}
	if err := trackingSvc.updateProductCostSnapshotTx(tx, companyID, variant.ProductID); err != nil {
		return fmt.Errorf("failed to update product cost snapshot: %w", err)
	}
	return nil
}

func (s *InventoryService) CreateStockTransfer(companyID, fromLocationID, userID int, req *models.CreateStockTransferRequest) (*models.StockTransfer, error) {
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

	trackingSvc := newInventoryTrackingService(s.db)
	for _, item := range req.Items {
		if err := s.validateProductInCompanyTx(tx, companyID, item.ProductID); err != nil {
			return nil, err
		}
		variant, err := trackingSvc.resolveVariantTx(tx, companyID, item.ProductID, item.BarcodeID)
		if err != nil {
			return nil, err
		}
		if variant.TrackingType == trackingTypeBatch && !variant.IsSerialized && len(item.BatchAllocations) == 0 {
			return nil, fmt.Errorf("batch selection is required")
		}
		if variant.IsSerialized {
			if item.Quantity != float64(int(item.Quantity)) {
				return nil, fmt.Errorf("serialized quantities must be whole numbers")
			}
			if len(item.SerialNumbers) != int(item.Quantity) {
				return nil, fmt.Errorf("serial numbers count must equal quantity")
			}
		}
		if _, err := tx.Exec(`
			INSERT INTO stock_transfer_details (
				transfer_id, product_id, barcode_id, quantity, serial_numbers, batch_allocations
			)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, transferID, item.ProductID, item.BarcodeID, item.Quantity, pq.Array(item.SerialNumbers), encodeBatchAllocations(item.BatchAllocations)); err != nil {
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
func (s *InventoryService) ApproveStockTransfer(transferID, companyID, actingLocationID, userID int, overridePassword *string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var status string
	var fromLocationID int
	var transferNumber string
	err = tx.QueryRow(`
                SELECT st.status, st.from_location_id, st.transfer_number
                FROM stock_transfers st
                JOIN locations fl ON st.from_location_id = fl.location_id
                JOIN locations tl ON st.to_location_id = tl.location_id
                WHERE st.transfer_id = $1 AND (fl.company_id = $2 OR tl.company_id = $2)
        `, transferID, companyID).Scan(&status, &fromLocationID, &transferNumber)

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

	rows, err := tx.Query(`
        SELECT transfer_detail_id, product_id, barcode_id, quantity, serial_numbers, COALESCE(batch_allocations, '[]'::jsonb)
        FROM stock_transfer_details
        WHERE transfer_id = $1
        ORDER BY transfer_detail_id
    `, transferID)
	if err != nil {
		return fmt.Errorf("failed to get transfer items: %w", err)
	}
	var items []struct {
		transferDetailID int
		productID        int
		barcodeID        *int
		quantity         float64
		serials          []string
		batches          []models.InventoryBatchSelectionInput
	}
	for rows.Next() {
		var item struct {
			transferDetailID int
			productID        int
			barcodeID        *int
			quantity         float64
			serials          []string
			batches          []models.InventoryBatchSelectionInput
		}
		var serials pq.StringArray
		var batchAllocRaw []byte
		if err := rows.Scan(&item.transferDetailID, &item.productID, &item.barcodeID, &item.quantity, &serials, &batchAllocRaw); err != nil {
			rows.Close()
			return fmt.Errorf("failed to scan transfer item: %w", err)
		}
		item.serials = []string(serials)
		item.batches = decodeBatchAllocations(batchAllocRaw)
		items = append(items, item)
	}
	if err := rows.Close(); err != nil {
		return fmt.Errorf("failed to close items cursor: %w", err)
	}

	for _, it := range items {
		sourceRef := transferNumber
		issue, err := s.issueTransferTrackedStockTx(tx, companyID, fromLocationID, userID, &it.transferDetailID, &sourceRef, inventorySelection{
			ProductID:        it.productID,
			BarcodeID:        it.barcodeID,
			Quantity:         it.quantity,
			SerialNumbers:    it.serials,
			BatchAllocations: it.batches,
			Notes:            nil,
			OverridePassword: overridePassword,
		})
		if err != nil {
			return fmt.Errorf("failed to move transfer stock into transit: %w", err)
		}
		if _, err := tx.Exec(`
			UPDATE stock_transfer_details
			SET barcode_id = $2,
			    batch_allocations = $3
			WHERE transfer_detail_id = $1
		`, it.transferDetailID, issue.Variant.BarcodeID, encodeBatchAllocations(issue.BatchAllocations)); err != nil {
			return fmt.Errorf("failed to persist transfer issue details: %w", err)
		}
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
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var fromLocationID, toLocationID int
	var status, transferNumber string
	err = tx.QueryRow(`
		SELECT st.from_location_id, st.to_location_id, st.status, st.transfer_number
		FROM stock_transfers st
		JOIN locations fl ON fl.location_id = st.from_location_id
		JOIN locations tl ON tl.location_id = st.to_location_id
		WHERE st.transfer_id = $1
		  AND (fl.company_id = $2 OR tl.company_id = $2)
	`, transferID, companyID).Scan(&fromLocationID, &toLocationID, &status, &transferNumber)

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

	rows, err := tx.Query(`
        SELECT transfer_detail_id, product_id, barcode_id, quantity, serial_numbers, COALESCE(batch_allocations, '[]'::jsonb)
        FROM stock_transfer_details
        WHERE transfer_id = $1
        ORDER BY transfer_detail_id
    `, transferID)
	if err != nil {
		return fmt.Errorf("failed to get transfer items: %w", err)
	}
	var items []struct {
		transferDetailID int
		productID        int
		barcodeID        *int
		quantity         float64
		serials          []string
		batches          []models.InventoryBatchSelectionInput
	}
	for rows.Next() {
		var item struct {
			transferDetailID int
			productID        int
			barcodeID        *int
			quantity         float64
			serials          []string
			batches          []models.InventoryBatchSelectionInput
		}
		var serials pq.StringArray
		var batchAllocRaw []byte
		if err := rows.Scan(&item.transferDetailID, &item.productID, &item.barcodeID, &item.quantity, &serials, &batchAllocRaw); err != nil {
			rows.Close()
			return fmt.Errorf("failed to scan transfer item: %w", err)
		}
		item.serials = []string(serials)
		item.batches = decodeBatchAllocations(batchAllocRaw)
		items = append(items, item)
	}
	if err := rows.Close(); err != nil {
		return fmt.Errorf("failed to close items cursor: %w", err)
	}

	for _, it := range items {
		sourceRef := transferNumber
		if err := s.receiveTransferTrackedStockTx(tx, companyID, fromLocationID, toLocationID, userID, &it.transferDetailID, &sourceRef, inventorySelection{
			ProductID:        it.productID,
			BarcodeID:        it.barcodeID,
			Quantity:         it.quantity,
			SerialNumbers:    it.serials,
			BatchAllocations: it.batches,
			Notes:            nil,
		}); err != nil {
			return fmt.Errorf("failed to transfer stock: %w", err)
		}
		if _, err := tx.Exec(`
			UPDATE stock_transfer_details
			SET received_quantity = quantity
			WHERE transfer_detail_id = $1
		`, it.transferDetailID); err != nil {
			return fmt.Errorf("failed to update received quantity: %w", err)
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
		SELECT
			std.transfer_detail_id, std.product_id, std.barcode_id, std.quantity, std.received_quantity,
			p.name as product_name, p.sku as product_sku, u.symbol as unit_symbol,
			pb.barcode, pb.variant_name,
			COALESCE(p.tracking_type, CASE WHEN COALESCE(p.is_serialized, FALSE) THEN 'SERIAL' ELSE 'VARIANT' END) AS tracking_type,
			std.serial_numbers, COALESCE(std.batch_allocations, '[]'::jsonb)
		FROM stock_transfer_details std
		JOIN products p ON std.product_id = p.product_id
		LEFT JOIN product_barcodes pb ON pb.barcode_id = std.barcode_id
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
		var serials pq.StringArray
		var batchAllocRaw []byte
		err := rows.Scan(
			&item.TransferDetailID, &item.ProductID, &item.BarcodeID, &item.Quantity, &item.ReceivedQuantity,
			&item.ProductName, &item.ProductSKU, &item.UnitSymbol, &item.Barcode, &item.VariantName,
			&item.TrackingType, &serials, &batchAllocRaw,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan transfer item: %w", err)
		}
		item.SerialNumbers = []string(serials)
		item.BatchAllocations = decodeBatchAllocations(batchAllocRaw)
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

	// Asset capitalization from stock (outgoing)
	{
		base := `
            SELECT
                'ASSET_CAPITALIZATION' AS type,
                im.occurred_at AS occurred_at,
                COALESCE(ae.asset_tag, im.source_ref, CONCAT('AST-', im.movement_id)) AS reference,
                im.quantity AS quantity,
                im.location_id AS location_id,
                l.name AS location_name,
                NULL AS partner_name,
                'asset_register' AS entity,
                COALESCE(ae.asset_entry_id, 0) AS entity_id,
                COALESCE(im.notes, ae.notes) AS notes
            FROM inventory_movements im
            JOIN locations l ON im.location_id = l.location_id
            LEFT JOIN asset_register_entries ae
              ON im.source_type = 'asset_register_entry'
             AND ae.company_id = im.company_id
             AND ae.asset_tag = im.source_ref
            WHERE im.company_id = $1 AND im.product_id = $2 AND im.source_type = 'asset_register_entry'`
		with, a, _ := buildWhere(base, "im.location_id", "im.occurred_at")
		selects = append(selects, with)
		selectArgs = append(selectArgs, a...)
	}

	// Consumable usage from stock (outgoing)
	{
		base := `
            SELECT
                'CONSUMPTION' AS type,
                im.occurred_at AS occurred_at,
                COALESCE(ce.entry_number, im.source_ref, CONCAT('CON-', im.movement_id)) AS reference,
                im.quantity AS quantity,
                im.location_id AS location_id,
                l.name AS location_name,
                NULL AS partner_name,
                'consumable_entry' AS entity,
                COALESCE(ce.consumption_id, 0) AS entity_id,
                COALESCE(im.notes, ce.notes) AS notes
            FROM inventory_movements im
            JOIN locations l ON im.location_id = l.location_id
            LEFT JOIN consumable_entries ce
              ON im.source_type = 'consumable_entry'
             AND ce.company_id = im.company_id
             AND ce.entry_number = im.source_ref
            WHERE im.company_id = $1 AND im.product_id = $2 AND im.source_type = 'consumable_entry'`
		with, a, _ := buildWhere(base, "im.location_id", "im.occurred_at")
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
