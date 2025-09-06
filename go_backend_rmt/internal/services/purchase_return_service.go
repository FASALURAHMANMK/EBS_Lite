package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type PurchaseReturnService struct {
	db *sql.DB
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
        if _, err := s.db.Exec(`UPDATE purchase_returns SET receipt_file = $1, updated_at = CURRENT_TIMESTAMP WHERE return_id = $2`, path, returnID); err != nil {
            return fmt.Errorf("failed to set receipt file: %w", err)
        }
    }
    // Try to store number if provided
    if number != nil && *number != "" {
        // Prefer dedicated column reference_number if exists; otherwise append to reason
        colCount = 0
        if err := s.db.QueryRow(`SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'purchase_returns' AND column_name = 'reference_number'`).Scan(&colCount); err == nil && colCount > 0 {
            if _, err := s.db.Exec(`UPDATE purchase_returns SET reference_number = $1, updated_at = CURRENT_TIMESTAMP WHERE return_id = $2`, *number, returnID); err != nil {
                return fmt.Errorf("failed to set reference number: %w", err)
            }
        } else {
            // Fallback: append to reason
            if _, err := s.db.Exec(`UPDATE purchase_returns SET reason = CONCAT(COALESCE(reason,''), CASE WHEN reason IS NULL OR reason = '' THEN '' ELSE ' | ' END, 'Receipt: ', $1), updated_at = CURRENT_TIMESTAMP WHERE return_id = $2`, *number, returnID); err != nil {
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
                JOIN products p ON prd.product_id = p.product_id
                LEFT JOIN product_barcodes pb ON p.product_id = pb.product_id AND pb.is_primary = TRUE
                WHERE prd.return_id = $1
                ORDER BY prd.return_detail_id
        `

	rows, err := s.db.Query(detailsQuery, returnID)
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

	// Generate return number using numbering sequence service
	ns := NewNumberingSequenceService()
	returnNumber, err := ns.NextNumber(tx, "purchase_return", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate return number: %w", err)
	}

	// Calculate total amount
	var totalAmount float64
	for _, item := range req.Items {
		// Verify product exists
		var productCompanyID int
		err = tx.QueryRow("SELECT company_id FROM products WHERE product_id = $1 AND is_deleted = FALSE",
			item.ProductID).Scan(&productCompanyID)
		if err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("product with ID %d not found", item.ProductID)
			}
			return nil, fmt.Errorf("failed to verify product: %w", err)
		}

		if productCompanyID != companyID {
			return nil, fmt.Errorf("product with ID %d does not belong to company", item.ProductID)
		}

		lineTotal := item.Quantity * item.UnitPrice
		totalAmount += lineTotal
	}

	// Insert purchase return
	insertQuery := `
               INSERT INTO purchase_returns (return_number, purchase_id, location_id, supplier_id,
                                                                        return_date, total_amount, reason, status, created_by, updated_by, approved_by, approved_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
               RETURNING return_id, created_at
       `

	var returnData models.PurchaseReturn
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
		lineTotal := item.Quantity * item.UnitPrice

		_, err = tx.Exec(`
			INSERT INTO purchase_return_details (return_id, purchase_detail_id, product_id,
											   quantity, unit_price, line_total)
			VALUES ($1, $2, $3, $4, $5, $6)
		`,
			returnData.ReturnID, item.PurchaseDetailID, item.ProductID,
			item.Quantity, item.UnitPrice, lineTotal,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to insert purchase return detail: %w", err)
		}

		// Update stock - reduce quantity
		_, err = tx.Exec(`
			UPDATE stock SET quantity = quantity - $1, last_updated = CURRENT_TIMESTAMP
			WHERE location_id = $2 AND product_id = $3
		`, item.Quantity, locationID, item.ProductID)
		if err != nil {
			return nil, fmt.Errorf("failed to update stock: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)

	}
	ledgerService := NewLedgerService()
	_ = ledgerService.RecordPurchaseReturn(companyID, returnData.ReturnID, totalAmount, userID)

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
	err := s.db.QueryRow("SELECT status FROM purchase_returns WHERE return_id = $1", returnID).Scan(&status)
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

	query := fmt.Sprintf("UPDATE purchase_returns SET %s WHERE return_id = $%d", strings.Join(setParts, ", "), argCount)
	args = append(args, returnID)

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
	err := s.db.QueryRow("SELECT status FROM purchase_returns WHERE return_id = $1", returnID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get return status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed returns cannot be deleted")
	}

	query := `UPDATE purchase_returns SET is_deleted = TRUE, updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE return_id = $1`

	result, err := s.db.Exec(query, returnID, userID)
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
