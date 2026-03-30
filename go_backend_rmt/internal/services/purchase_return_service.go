package services

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type PurchaseReturnService struct {
	db *sql.DB
}

type purchaseReturnAllocation struct {
	PurchaseDetailID int
	ProductID        int
	BarcodeID        *int
	Quantity         float64
	UnitPrice        float64
	StockQuantity    float64
	StockUnitID      *int
	PurchaseUnitID   *int
	PurchaseUOMMode  string
	PurchaseToStock  float64
}

func NewPurchaseReturnService() *PurchaseReturnService {
	return &PurchaseReturnService{
		db: database.GetDB(),
	}
}

// VerifyReturnInCompany is an exported wrapper to reuse in handlers without duplicating logic
func (s *PurchaseReturnService) VerifyReturnInCompany(returnID, companyID int) error {
	return s.verifyReturnInCompany(returnID, companyID)
}

// SetPurchaseReturnReceiptFile stores a file path for the return; if optional columns are missing, it degrades gracefully.
func (s *PurchaseReturnService) SetPurchaseReturnReceiptFile(returnID, companyID int, path string, number *string) error {
	if err := s.verifyReturnInCompany(returnID, companyID); err != nil {
		return err
	}
	// Conditionally update receipt_file column
	var colCount int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'purchase_returns' AND column_name = 'receipt_file'`).Scan(&colCount); err == nil && colCount > 0 {
		if _, err := s.db.Exec(`
            UPDATE purchase_returns pr SET receipt_file = $1, updated_at = CURRENT_TIMESTAMP
            FROM purchases p
            JOIN suppliers s ON p.supplier_id = s.supplier_id
            WHERE pr.return_id = $2 AND pr.purchase_id = p.purchase_id AND s.company_id = $3
        `, path, returnID, companyID); err != nil {
			return fmt.Errorf("failed to set receipt file: %w", err)
		}
	}
	// Try to store number if provided
	if number != nil && *number != "" {
		// Prefer dedicated column reference_number if exists; otherwise append to reason
		colCount = 0
		if err := s.db.QueryRow(`SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'purchase_returns' AND column_name = 'reference_number'`).Scan(&colCount); err == nil && colCount > 0 {
			if _, err := s.db.Exec(`
                UPDATE purchase_returns pr SET reference_number = $1, updated_at = CURRENT_TIMESTAMP
                FROM purchases p
                JOIN suppliers s ON p.supplier_id = s.supplier_id
                WHERE pr.return_id = $2 AND pr.purchase_id = p.purchase_id AND s.company_id = $3
            `, *number, returnID, companyID); err != nil {
				return fmt.Errorf("failed to set reference number: %w", err)
			}
		} else {
			// Fallback: append to reason
			if _, err := s.db.Exec(`
                UPDATE purchase_returns pr SET reason = CONCAT(COALESCE(reason,''), CASE WHEN reason IS NULL OR reason = '' THEN '' ELSE ' | ' END, 'Receipt: ', $1),
                    updated_at = CURRENT_TIMESTAMP
                FROM purchases p
                JOIN suppliers s ON p.supplier_id = s.supplier_id
                WHERE pr.return_id = $2 AND pr.purchase_id = p.purchase_id AND s.company_id = $3
            `, *number, returnID, companyID); err != nil {
				return fmt.Errorf("failed to append receipt number to reason: %w", err)
			}
		}
	}
	return nil
}

func (s *PurchaseReturnService) GetPurchaseReturns(companyID, locationID int, filters map[string]string) ([]models.PurchaseReturn, error) {
	query := `
               SELECT pr.return_id, pr.return_number, pr.purchase_id, pr.location_id, pr.supplier_id,
                          pr.return_date, pr.total_amount, pr.reason, pr.status, pr.created_by, pr.approved_by, pr.approved_at,
                          pr.sync_status, pr.created_at, pr.updated_at,
                          p.purchase_number, s.name as supplier_name
               FROM purchase_returns pr
               JOIN purchases p ON pr.purchase_id = p.purchase_id
               JOIN suppliers s ON pr.supplier_id = s.supplier_id
               WHERE s.company_id = $1 AND pr.location_id = $2 AND pr.is_deleted = FALSE
       `

	args := []interface{}{companyID, locationID}
	argCount := 2

	// Apply filters
	if purchaseID, ok := filters["purchase_id"]; ok && purchaseID != "" {
		argCount++
		query += fmt.Sprintf(" AND pr.purchase_id = $%d", argCount)
		args = append(args, purchaseID)
	}

	if supplierID, ok := filters["supplier_id"]; ok && supplierID != "" {
		argCount++
		query += fmt.Sprintf(" AND pr.supplier_id = $%d", argCount)
		args = append(args, supplierID)
	}

	if dateFrom, ok := filters["date_from"]; ok && dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND pr.return_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo, ok := filters["date_to"]; ok && dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND pr.return_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	query += " ORDER BY pr.return_date DESC, pr.return_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get purchase returns: %w", err)
	}
	defer rows.Close()

	var returns []models.PurchaseReturn
	for rows.Next() {
		var pr models.PurchaseReturn
		var purchaseNumber, supplierName string

		err := rows.Scan(
			&pr.ReturnID, &pr.ReturnNumber, &pr.PurchaseID, &pr.LocationID, &pr.SupplierID,
			&pr.ReturnDate, &pr.TotalAmount, &pr.Reason, &pr.Status, &pr.CreatedBy, &pr.ApprovedBy, &pr.ApprovedAt,
			&pr.SyncStatus, &pr.CreatedAt, &pr.UpdatedAt,
			&purchaseNumber, &supplierName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan purchase return: %w", err)
		}

		// Set purchase and supplier info
		pr.Purchase = &models.Purchase{PurchaseNumber: purchaseNumber}
		pr.Supplier = &models.Supplier{Name: supplierName}

		returns = append(returns, pr)
	}

	return returns, nil
}

func (s *PurchaseReturnService) GetPurchaseReturnByID(returnID, companyID int) (*models.PurchaseReturn, error) {
	// Get return header
	query := `
               SELECT pr.return_id, pr.return_number, pr.purchase_id, pr.location_id, pr.supplier_id,
                          pr.return_date, pr.total_amount, pr.reason, pr.status, pr.created_by, pr.approved_by, pr.approved_at,
                          pr.sync_status, pr.created_at, pr.updated_at,
                          p.purchase_number, s.name as supplier_name
               FROM purchase_returns pr
               JOIN purchases p ON pr.purchase_id = p.purchase_id
               JOIN suppliers s ON pr.supplier_id = s.supplier_id
               WHERE pr.return_id = $1 AND s.company_id = $2 AND pr.is_deleted = FALSE
       `

	var returnData models.PurchaseReturn
	var purchaseNumber, supplierName string

	err := s.db.QueryRow(query, returnID, companyID).Scan(
		&returnData.ReturnID, &returnData.ReturnNumber, &returnData.PurchaseID, &returnData.LocationID, &returnData.SupplierID,
		&returnData.ReturnDate, &returnData.TotalAmount, &returnData.Reason, &returnData.Status, &returnData.CreatedBy, &returnData.ApprovedBy, &returnData.ApprovedAt,
		&returnData.SyncStatus, &returnData.CreatedAt, &returnData.UpdatedAt,
		&purchaseNumber, &supplierName,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase return not found")
		}
		return nil, fmt.Errorf("failed to get purchase return: %w", err)
	}

	// Set purchase and supplier info
	returnData.Purchase = &models.Purchase{PurchaseNumber: purchaseNumber}
	returnData.Supplier = &models.Supplier{Name: supplierName}

	// Get return details
	detailsQuery := `
                SELECT prd.return_detail_id, prd.return_id, prd.purchase_detail_id, prd.product_id,
                           prd.quantity, prd.unit_price, prd.line_total,
                           p.name as product_name, p.sku, pb.barcode
                FROM purchase_return_details prd
                JOIN purchase_returns pr ON prd.return_id = pr.return_id
                JOIN purchases pu ON pr.purchase_id = pu.purchase_id
                JOIN suppliers s ON pu.supplier_id = s.supplier_id
                JOIN products p ON prd.product_id = p.product_id
                LEFT JOIN product_barcodes pb ON p.product_id = pb.product_id AND pb.is_primary = TRUE
                WHERE prd.return_id = $1 AND s.company_id = $2 AND p.company_id = $2
                ORDER BY prd.return_detail_id
        `

	rows, err := s.db.Query(detailsQuery, returnID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get purchase return details: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var detail models.PurchaseReturnDetail
		var productName, sku, barcode sql.NullString

		err := rows.Scan(
			&detail.ReturnDetailID, &detail.ReturnID, &detail.PurchaseDetailID, &detail.ProductID,
			&detail.Quantity, &detail.UnitPrice, &detail.LineTotal,
			&productName, &sku, &barcode,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan purchase return detail: %w", err)
		}

		// Set product info
		detail.Product = &models.Product{
			ProductID: detail.ProductID,
			Name:      productName.String,
			SKU:       nullStringToStringPtr(sku),
			Barcodes: func() []models.ProductBarcode {
				if barcode.Valid {
					return []models.ProductBarcode{{Barcode: barcode.String, IsPrimary: true}}
				}
				return nil
			}(),
		}

		returnData.Items = append(returnData.Items, detail)
	}

	return &returnData, nil
}

func (s *PurchaseReturnService) CreatePurchaseReturn(companyID, locationID, userID int, req *models.CreatePurchaseReturnRequest) (*models.PurchaseReturn, error) {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()
	trackingSvc := newInventoryTrackingService(s.db)

	// Verify purchase exists and belongs to company
	var supplierID int
	var purchaseLocationID int
	err = tx.QueryRow(`
		SELECT p.supplier_id, p.location_id FROM purchases p
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, req.PurchaseID, companyID).Scan(&supplierID, &purchaseLocationID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase not found")
		}
		return nil, fmt.Errorf("failed to verify purchase: %w", err)
	}

	if locationID == 0 {
		locationID = purchaseLocationID
	} else if locationID != purchaseLocationID {
		return nil, fmt.Errorf("invalid location for purchase")
	}

	// Generate return number using numbering sequence service
	ns := NewNumberingSequenceService()
	returnNumber, err := ns.NextNumber(tx, "purchase_return", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate return number: %w", err)
	}

	// Insert purchase return
	insertQuery := `
               INSERT INTO purchase_returns (return_number, purchase_id, location_id, supplier_id,
                                                                        return_date, total_amount, reason, status, created_by, updated_by, approved_by, approved_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
               RETURNING return_id, created_at
       `

	var returnData models.PurchaseReturn
	var totalAmount float64
	now := time.Now()
	err = tx.QueryRow(insertQuery,
		returnNumber, req.PurchaseID, locationID, supplierID,
		now, totalAmount, req.Reason, "COMPLETED", userID, userID, userID, now,
	).Scan(&returnData.ReturnID, &returnData.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert purchase return: %w", err)
	}
	// Insert return details and update stock
	for _, item := range req.Items {
		allocations, err := s.allocatePurchaseReturnLines(tx, companyID, req.PurchaseID, item.ProductID, item.BarcodeID, item.Quantity, item.PurchaseDetailID)
		if err != nil {
			return nil, fmt.Errorf("failed to allocate purchase return item %d: %w", item.ProductID, err)
		}
		if len(allocations) > 1 && (len(item.SerialNumbers) > 0 || len(item.BatchAllocations) > 0) {
			return nil, fmt.Errorf("split purchase returns for tracked items require separate lines")
		}
		for _, allocation := range allocations {
			lineTotal := allocation.Quantity * item.UnitPrice
			totalAmount += lineTotal

			var returnDetailID int
			err = tx.QueryRow(`
				INSERT INTO purchase_return_details (return_id, purchase_detail_id, product_id, barcode_id,
												   quantity, unit_price, line_total,
												   stock_unit_id, purchase_unit_id, purchase_uom_mode, purchase_to_stock_factor, stock_quantity)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
				RETURNING return_detail_id
			`,
				returnData.ReturnID, allocation.PurchaseDetailID, allocation.ProductID, firstNonNilInt(item.BarcodeID, allocation.BarcodeID),
				allocation.Quantity, item.UnitPrice, lineTotal,
				allocation.StockUnitID, allocation.PurchaseUnitID, allocation.PurchaseUOMMode, allocation.PurchaseToStock, allocation.StockQuantity,
			).Scan(&returnDetailID)
			if err != nil {
				return nil, fmt.Errorf("failed to insert purchase return detail: %w", err)
			}

			if _, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "PURCHASE_RETURN", "purchase_return_detail", &returnDetailID, nil, inventorySelection{
				ProductID:        allocation.ProductID,
				BarcodeID:        firstNonNilInt(item.BarcodeID, allocation.BarcodeID),
				Quantity:         allocation.StockQuantity,
				SerialNumbers:    item.SerialNumbers,
				BatchAllocations: item.BatchAllocations,
				OverridePassword: req.OverridePassword,
			}); err != nil {
				return nil, fmt.Errorf("failed to update stock: %w", err)
			}
		}
	}

	if _, err := tx.Exec(`
		UPDATE purchase_returns
		SET total_amount = $1, updated_at = CURRENT_TIMESTAMP, updated_by = $2
		WHERE return_id = $3
	`, totalAmount, userID, returnData.ReturnID); err != nil {
		return nil, fmt.Errorf("failed to update purchase return total: %w", err)
	}

	if err := NewFinanceIntegrityServiceWithDB(s.db).EnqueueTx(tx, &models.FinanceOutboxEntry{
		CompanyID:     companyID,
		LocationID:    &locationID,
		EventType:     financeEventLedgerPurchaseReturn,
		AggregateType: "purchase_return",
		AggregateID:   returnData.ReturnID,
		Payload:       models.JSONB{},
		CreatedBy:     &userID,
	}); err != nil {
		return nil, fmt.Errorf("failed to enqueue purchase return ledger posting: %w", err)
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)

	}
	if err := NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "purchase_return", returnData.ReturnID); err != nil {
		log.Printf("purchase_return_service: failed to process finance outbox for purchase_return %d: %v", returnData.ReturnID, err)
	}

	// Set response data
	returnData.ReturnNumber = returnNumber
	returnData.PurchaseID = req.PurchaseID
	returnData.LocationID = locationID
	returnData.SupplierID = supplierID
	returnData.ReturnDate = now
	returnData.TotalAmount = totalAmount
	returnData.Reason = req.Reason
	returnData.Status = "COMPLETED"
	returnData.CreatedBy = userID
	returnData.ApprovedBy = &userID
	returnData.ApprovedAt = &now

	return &returnData, nil
}

func (s *PurchaseReturnService) UpdatePurchaseReturn(returnID, companyID, userID int, updates map[string]interface{}) error {
	if err := s.verifyReturnInCompany(returnID, companyID); err != nil {
		return err
	}

	var status string
	err := s.db.QueryRow(`
		SELECT pr.status FROM purchase_returns pr
		JOIN purchases p ON pr.purchase_id = p.purchase_id
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE pr.return_id = $1 AND s.company_id = $2 AND pr.is_deleted = FALSE
	`, returnID, companyID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get return status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed returns cannot be updated")
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	for field, value := range updates {
		switch field {
		case "reason":
			argCount++
			setParts = append(setParts, fmt.Sprintf("reason = $%d", argCount))
			args = append(args, value)
		case "status":
			argCount++
			setParts = append(setParts, fmt.Sprintf("status = $%d", argCount))
			args = append(args, value)
		}
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no valid fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)

	argCount++
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE purchase_returns pr SET %s FROM purchases p JOIN suppliers s ON p.supplier_id = s.supplier_id WHERE pr.return_id = $%d AND pr.purchase_id = p.purchase_id AND s.company_id = $%d",
		strings.Join(setParts, ", "), argCount, argCount+1)
	args = append(args, returnID, companyID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update purchase return: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *PurchaseReturnService) DeletePurchaseReturn(returnID, companyID, userID int) error {
	if err := s.verifyReturnInCompany(returnID, companyID); err != nil {
		return err
	}

	var status string
	err := s.db.QueryRow(`
		SELECT pr.status FROM purchase_returns pr
		JOIN purchases p ON pr.purchase_id = p.purchase_id
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE pr.return_id = $1 AND s.company_id = $2 AND pr.is_deleted = FALSE
	`, returnID, companyID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get return status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed returns cannot be deleted")
	}

	query := `UPDATE purchase_returns pr SET is_deleted = TRUE, updated_by = $2, updated_at = CURRENT_TIMESTAMP
		FROM purchases p
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE pr.return_id = $1 AND pr.purchase_id = p.purchase_id AND s.company_id = $3`

	result, err := s.db.Exec(query, returnID, userID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete purchase return: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *PurchaseReturnService) verifyReturnInCompany(returnID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
               SELECT COUNT(*) FROM purchase_returns pr
               JOIN purchases p ON pr.purchase_id = p.purchase_id
               JOIN suppliers s ON p.supplier_id = s.supplier_id
               WHERE pr.return_id = $1 AND s.company_id = $2 AND pr.is_deleted = FALSE
       `, returnID, companyID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to verify return: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *PurchaseReturnService) allocatePurchaseReturnLines(tx *sql.Tx, companyID, purchaseID, productID int, barcodeID *int, requestedQty float64, preferredDetailID *int) ([]purchaseReturnAllocation, error) {
	query := `
		SELECT
			pd.purchase_detail_id,
			pd.product_id,
			pd.barcode_id,
			pd.received_quantity::float8,
			pd.unit_price::float8,
			COALESCE(pd.purchase_to_stock_factor, 1.0)::float8,
			COALESCE(pd.purchase_uom_mode, 'LOOSE'),
			pd.stock_unit_id,
			pd.purchase_unit_id,
			COALESCE(ret.returned_qty, 0)::float8 AS returned_qty
		FROM purchase_details pd
		JOIN purchases p ON p.purchase_id = pd.purchase_id
		JOIN locations l ON l.location_id = p.location_id
		LEFT JOIN (
			SELECT
				prd.purchase_detail_id,
				COALESCE(SUM(prd.quantity), 0)::float8 AS returned_qty
			FROM purchase_return_details prd
			JOIN purchase_returns pr ON pr.return_id = prd.return_id
			WHERE pr.purchase_id = $1 AND pr.status = 'COMPLETED' AND prd.purchase_detail_id IS NOT NULL
			GROUP BY prd.purchase_detail_id
		) ret ON ret.purchase_detail_id = pd.purchase_detail_id
		WHERE pd.purchase_id = $1
		  AND pd.product_id = $2
		  AND l.company_id = $3
	`
	args := []interface{}{purchaseID, productID, companyID}
	nextArg := 4
	if barcodeID != nil && *barcodeID > 0 {
		query += fmt.Sprintf(" AND pd.barcode_id = $%d", nextArg)
		args = append(args, *barcodeID)
		nextArg++
	}
	if preferredDetailID != nil && *preferredDetailID > 0 {
		query += fmt.Sprintf(" AND pd.purchase_detail_id = $%d", nextArg)
		args = append(args, *preferredDetailID)
	}
	query += " ORDER BY pd.purchase_detail_id FOR UPDATE"

	rows, err := tx.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	remaining := requestedQty
	allocations := make([]purchaseReturnAllocation, 0)
	found := false
	for rows.Next() {
		found = true
		var purchaseDetailID int
		var barcodeID sql.NullInt64
		var receivedQty float64
		var unitPrice float64
		var purchaseToStock float64
		var purchaseUOMMode string
		var stockUnitID *int
		var purchaseUnitID *int
		var returnedQty float64
		if err := rows.Scan(&purchaseDetailID, &productID, &barcodeID, &receivedQty, &unitPrice, &purchaseToStock, &purchaseUOMMode, &stockUnitID, &purchaseUnitID, &returnedQty); err != nil {
			return nil, err
		}
		available := receivedQty - returnedQty
		if available <= 0 {
			continue
		}
		allocatedQty := available
		if allocatedQty > remaining {
			allocatedQty = remaining
		}
		if allocatedQty <= 0 {
			continue
		}
		allocations = append(allocations, purchaseReturnAllocation{
			PurchaseDetailID: purchaseDetailID,
			ProductID:        productID,
			BarcodeID:        intPtrFromNullInt64(barcodeID),
			Quantity:         allocatedQty,
			UnitPrice:        unitPrice,
			StockQuantity:    quantityInStockUOM(allocatedQty, purchaseToStock),
			StockUnitID:      stockUnitID,
			PurchaseUnitID:   purchaseUnitID,
			PurchaseUOMMode:  purchaseUOMMode,
			PurchaseToStock:  purchaseToStock,
		})
		remaining -= allocatedQty
		if remaining <= 0.000001 {
			break
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if !found {
		return nil, fmt.Errorf("product %d not found in original purchase", productID)
	}
	if remaining > 0.000001 {
		return nil, fmt.Errorf("invalid return quantity for product %d", productID)
	}
	return allocations, nil
}
