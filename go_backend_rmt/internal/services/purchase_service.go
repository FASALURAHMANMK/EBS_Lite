package services

import (
    "database/sql"
    "fmt"
    "strings"
    "time"

    "github.com/lib/pq"

    "erp-backend/internal/database"
    "erp-backend/internal/models"
)

type PurchaseService struct {
	db *sql.DB
}

func NewPurchaseService() *PurchaseService {
	return &PurchaseService{
		db: database.GetDB(),
	}
}

func (s *PurchaseService) GetPurchases(companyID, locationID int, filters map[string]string) ([]models.Purchase, error) {
    query := `
        SELECT p.purchase_id, p.purchase_number, p.location_id, p.supplier_id, p.purchase_date,
               p.subtotal, p.tax_amount, p.discount_amount, p.total_amount, p.paid_amount,
               p.payment_terms, p.due_date, p.status, p.reference_number, p.notes,
               p.created_by, p.updated_by, p.sync_status, p.created_at, p.updated_at,
               s.name as supplier_name, l.name as location_name
        FROM purchases p
        JOIN suppliers s ON p.supplier_id = s.supplier_id
        JOIN locations l ON p.location_id = l.location_id
        WHERE s.company_id = $1 AND p.location_id = $2 AND p.is_deleted = FALSE
    `

	args := []interface{}{companyID, locationID}
	argCount := 2

	// Apply filters
	if supplierID, ok := filters["supplier_id"]; ok && supplierID != "" {
		argCount++
		query += fmt.Sprintf(" AND p.supplier_id = $%d", argCount)
		args = append(args, supplierID)
	}

	if dateFrom, ok := filters["date_from"]; ok && dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND p.purchase_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo, ok := filters["date_to"]; ok && dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND p.purchase_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	if status, ok := filters["status"]; ok && status != "" {
		argCount++
		query += fmt.Sprintf(" AND p.status = $%d", argCount)
		args = append(args, status)
	}

	query += " ORDER BY p.purchase_date DESC, p.purchase_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get purchases: %w", err)
	}
	defer rows.Close()

	var purchases []models.Purchase
	for rows.Next() {
		var p models.Purchase
		var supplierName, locationName string

        err := rows.Scan(
            &p.PurchaseID, &p.PurchaseNumber, &p.LocationID, &p.SupplierID, &p.PurchaseDate,
            &p.Subtotal, &p.TaxAmount, &p.DiscountAmount, &p.TotalAmount, &p.PaidAmount,
            &p.PaymentTerms, &p.DueDate, &p.Status, &p.ReferenceNumber, &p.Notes,
            &p.CreatedBy, &p.UpdatedBy, &p.SyncStatus, &p.CreatedAt, &p.UpdatedAt,
            &supplierName, &locationName,
        )
		if err != nil {
			return nil, fmt.Errorf("failed to scan purchase: %w", err)
		}

		// Set supplier and location info
		p.Supplier = &models.Supplier{Name: supplierName}
		p.Location = &models.Location{Name: locationName}

		purchases = append(purchases, p)
	}

	return purchases, nil
}

func (s *PurchaseService) GetPurchaseByID(purchaseID, companyID int) (*models.PurchaseWithDetails, error) {
	// Get purchase header
    query := `
        SELECT p.purchase_id, p.purchase_number, p.location_id, p.supplier_id, p.purchase_date,
               p.subtotal, p.tax_amount, p.discount_amount, p.total_amount, p.paid_amount,
               p.payment_terms, p.due_date, p.status, p.reference_number, p.notes,
               p.created_by, p.updated_by, p.sync_status, p.created_at, p.updated_at,
               s.name as supplier_name, s.contact_person, s.phone, s.email,
               l.name as location_name
        FROM purchases p
        JOIN suppliers s ON p.supplier_id = s.supplier_id
        JOIN locations l ON p.location_id = l.location_id
        WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
    `

	var purchase models.PurchaseWithDetails
	var supplierName, contactPerson, phone, email, locationName sql.NullString

    err := s.db.QueryRow(query, purchaseID, companyID).Scan(
        &purchase.PurchaseID, &purchase.PurchaseNumber, &purchase.LocationID, &purchase.SupplierID, &purchase.PurchaseDate,
        &purchase.Subtotal, &purchase.TaxAmount, &purchase.DiscountAmount, &purchase.TotalAmount, &purchase.PaidAmount,
        &purchase.PaymentTerms, &purchase.DueDate, &purchase.Status, &purchase.ReferenceNumber, &purchase.Notes,
        &purchase.CreatedBy, &purchase.UpdatedBy, &purchase.SyncStatus, &purchase.CreatedAt, &purchase.UpdatedAt,
        &supplierName, &contactPerson, &phone, &email, &locationName,
    )
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase not found")
		}
		return nil, fmt.Errorf("failed to get purchase: %w", err)
	}

	// Set supplier info
	purchase.Supplier = &models.Supplier{
		SupplierID:    purchase.SupplierID,
		Name:          supplierName.String,
		ContactPerson: &contactPerson.String,
		Phone:         &phone.String,
		Email:         &email.String,
	}

	purchase.Location = &models.Location{Name: locationName.String}

	// Get purchase details
    detailsQuery := `
                SELECT pd.purchase_detail_id, pd.purchase_id, pd.product_id, pd.quantity,
                           pd.unit_price, pd.discount_percentage, pd.discount_amount, pd.tax_id,
                           pd.tax_amount, pd.line_total, pd.received_quantity, pd.serial_numbers,
                           pd.expiry_date, pd.batch_number,
                           p.name as product_name, p.sku
                FROM purchase_details pd
                JOIN products p ON pd.product_id = p.product_id
                WHERE pd.purchase_id = $1
                ORDER BY pd.purchase_detail_id
        `

	rows, err := s.db.Query(detailsQuery, purchaseID)
	if err != nil {
		return nil, fmt.Errorf("failed to get purchase details: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
    var detail models.PurchaseDetail
        var productName, sku sql.NullString

        err := rows.Scan(
            &detail.PurchaseDetailID, &detail.PurchaseID, &detail.ProductID, &detail.Quantity,
            &detail.UnitPrice, &detail.DiscountPercentage, &detail.DiscountAmount, &detail.TaxID,
            &detail.TaxAmount, &detail.LineTotal, &detail.ReceivedQuantity, pq.Array(&detail.SerialNumbers),
            &detail.ExpiryDate, &detail.BatchNumber,
            &productName, &sku,
        )
		if err != nil {
			return nil, fmt.Errorf("failed to scan purchase detail: %w", err)
		}

		// Set product info
        detail.Product = &models.Product{
            ProductID: detail.ProductID,
            Name:      productName.String,
            SKU:       nullStringToStringPtr(sku),
        }

		purchase.Items = append(purchase.Items, detail)
	}

	return &purchase, nil
}

func nullStringToStringPtr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	return &ns.String
}

func (s *PurchaseService) CreatePurchase(companyID, locationID, userID int, req *models.CreatePurchaseRequest) (*models.Purchase, error) {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Verify supplier belongs to company
	var supplierCompanyID int
	err = tx.QueryRow("SELECT company_id FROM suppliers WHERE supplier_id = $1 AND is_active = TRUE",
		req.SupplierID).Scan(&supplierCompanyID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("supplier not found")
		}
		return nil, fmt.Errorf("failed to verify supplier: %w", err)
	}

	if supplierCompanyID != companyID {
		return nil, fmt.Errorf("supplier does not belong to company")
	}

	// Use provided location or default from context
	if req.LocationID != nil {
		locationID = *req.LocationID
	}

	// Generate purchase number using numbering sequence
	ns := NewNumberingSequenceService()
	purchaseNumber, err := ns.NextNumber(tx, "purchase", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate purchase number: %w", err)
	}

	// Set purchase date
	purchaseDate := time.Now()
	if req.PurchaseDate != nil {
		purchaseDate = *req.PurchaseDate
	}

	// Calculate totals
	var subtotal, totalTax, totalDiscount float64
	for _, item := range req.Items {
		// Verify product belongs to company
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

		// Apply discount
		discountAmount := float64(0)
		if item.DiscountPercentage != nil {
			discountAmount = lineTotal * (*item.DiscountPercentage / 100)
		}
		if item.DiscountAmount != nil {
			discountAmount = *item.DiscountAmount
		}

		lineTotal -= discountAmount
		totalDiscount += discountAmount

		// Calculate tax
		taxAmount := float64(0)
		if item.TaxID != nil {
			var taxPercentage float64
			err = tx.QueryRow("SELECT percentage FROM taxes WHERE tax_id = $1 AND company_id = $2 AND is_active = TRUE",
				*item.TaxID, companyID).Scan(&taxPercentage)
			if err == nil {
				taxAmount = lineTotal * (taxPercentage / 100)
			}
		}

		totalTax += taxAmount
		subtotal += (lineTotal + taxAmount)
	}

	totalAmount := subtotal

	// Set due date based on payment terms
	var dueDate *time.Time
	paymentTerms := 0
	if req.PaymentTerms != nil {
		paymentTerms = *req.PaymentTerms
	}
	if paymentTerms > 0 {
		due := purchaseDate.AddDate(0, 0, paymentTerms)
		dueDate = &due
	}

	// Insert purchase
	insertQuery := `
		INSERT INTO purchases (purchase_number, location_id, supplier_id, purchase_date,
							  subtotal, tax_amount, discount_amount, total_amount, paid_amount,
							  payment_terms, due_date, status, reference_number, notes, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		RETURNING purchase_id, created_at
	`

	var purchase models.Purchase
	err = tx.QueryRow(insertQuery,
		purchaseNumber, locationID, req.SupplierID, purchaseDate,
		subtotal, totalTax, totalDiscount, totalAmount, 0,
		paymentTerms, dueDate, "PENDING", req.ReferenceNumber, req.Notes, userID,
	).Scan(&purchase.PurchaseID, &purchase.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert purchase: %w", err)
	}

	// Insert purchase details
	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice

		// Apply discount
		discountAmount := float64(0)
		if item.DiscountPercentage != nil {
			discountAmount = lineTotal * (*item.DiscountPercentage / 100)
		}
		if item.DiscountAmount != nil {
			discountAmount = *item.DiscountAmount
		}

		lineTotal -= discountAmount

		// Calculate tax
		taxAmount := float64(0)
		if item.TaxID != nil {
			var taxPercentage float64
			err = tx.QueryRow("SELECT percentage FROM taxes WHERE tax_id = $1 AND company_id = $2 AND is_active = TRUE",
				*item.TaxID, companyID).Scan(&taxPercentage)
			if err == nil {
				taxAmount = lineTotal * (taxPercentage / 100)
			}
		}

		finalLineTotal := lineTotal + taxAmount

        // Validate serial numbers if product is serialized
        var isSerialized bool
        if err = tx.QueryRow("SELECT is_serialized FROM products WHERE product_id = $1 AND is_deleted = FALSE", item.ProductID).Scan(&isSerialized); err != nil {
            if err == sql.ErrNoRows {
                return nil, fmt.Errorf("product with ID %d not found", item.ProductID)
            }
            return nil, fmt.Errorf("failed to verify product: %w", err)
        }
        if isSerialized {
            // quantity must be whole number and equal to serial count
            if item.Quantity != float64(int(item.Quantity)) {
                return nil, fmt.Errorf("quantity must be a whole number for serialized products (product_id=%d)", item.ProductID)
            }
            if len(item.SerialNumbers) != int(item.Quantity) {
                return nil, fmt.Errorf("serial numbers count must equal quantity for serialized products (product_id=%d)", item.ProductID)
            }
            seen := make(map[string]struct{}, len(item.SerialNumbers))
            for _, srl := range item.SerialNumbers {
                if srl == "" {
                    return nil, fmt.Errorf("serial numbers cannot be empty for serialized products (product_id=%d)", item.ProductID)
                }
                if _, ok := seen[srl]; ok {
                    return nil, fmt.Errorf("duplicate serial number '%s' in purchase item (product_id=%d)", srl, item.ProductID)
                }
                seen[srl] = struct{}{}
            }
        } else if len(item.SerialNumbers) > 0 {
            return nil, fmt.Errorf("serial numbers provided for a non-serialized product (product_id=%d)", item.ProductID)
        }

        _, err = tx.Exec(`
            INSERT INTO purchase_details (purchase_id, product_id, quantity, unit_price,
                                       discount_percentage, discount_amount, tax_id, tax_amount,
                                       line_total, received_quantity, serial_numbers, expiry_date, batch_number)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        `,
            purchase.PurchaseID, item.ProductID, item.Quantity, item.UnitPrice,
            item.DiscountPercentage, discountAmount, item.TaxID, taxAmount,
            finalLineTotal, 0, pq.Array(item.SerialNumbers), item.ExpiryDate, item.BatchNumber,
        )
        if err != nil {
            return nil, fmt.Errorf("failed to insert purchase detail: %w", err)
        }
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	ledgerService := NewLedgerService()
	_ = ledgerService.RecordPurchase(companyID, purchase.PurchaseID, totalAmount, userID)

	// Set response data
	purchase.PurchaseNumber = purchaseNumber
	purchase.LocationID = locationID
	purchase.SupplierID = req.SupplierID
	purchase.PurchaseDate = purchaseDate
	purchase.Subtotal = subtotal
	purchase.TaxAmount = totalTax
	purchase.DiscountAmount = totalDiscount
	purchase.TotalAmount = totalAmount
	purchase.PaidAmount = 0
	purchase.PaymentTerms = paymentTerms
	purchase.DueDate = dueDate
	purchase.Status = "PENDING"
	purchase.ReferenceNumber = req.ReferenceNumber
	purchase.Notes = req.Notes
	purchase.CreatedBy = userID

	return &purchase, nil
}

// ReceivePurchase marks a purchase as received and updates inventory
func (s *PurchaseService) ReceivePurchase(purchaseID, companyID, userID int, req *models.ReceivePurchaseRequest) error {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

    // Verify purchase exists and can be received
    var currentStatus string
    var locationID int
    var supplierID int
    err = tx.QueryRow(`
        SELECT p.status, p.location_id, p.supplier_id FROM purchases p
        JOIN suppliers s ON p.supplier_id = s.supplier_id
        WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
    `, purchaseID, companyID).Scan(&currentStatus, &locationID, &supplierID)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("purchase not found")
		}
		return fmt.Errorf("failed to verify purchase: %w", err)
	}

	if currentStatus != "PENDING" {
		return fmt.Errorf("purchase with status %s cannot be received", currentStatus)
	}

    // Create Goods Receipt header (auto-numbered) if table exists
    ns := NewNumberingSequenceService()
    var goodsReceiptID int
    grSupported := true
    receiptNumber := ""
    if rn, err := ns.NextNumber(tx, "grn", companyID, &locationID); err == nil {
        receiptNumber = rn
    } else {
        // If numbering sequences not available, skip GRN persistence but continue receiving
        grSupported = false
    }
    if err := tx.QueryRow(`
        INSERT INTO goods_receipts (receipt_number, purchase_id, location_id, supplier_id, received_date, received_by)
        VALUES ($1, $2, $3, $4, CURRENT_DATE, $5)
        RETURNING goods_receipt_id
    `, receiptNumber, purchaseID, locationID, supplierID, userID).Scan(&goodsReceiptID); err != nil {
        if pqErr, ok := err.(*pq.Error); ok && (string(pqErr.Code) == "42P01" || string(pqErr.Code) == "42703") {
            // Table or column missing; gracefully disable GRN persistence
            grSupported = false
        } else {
            return fmt.Errorf("failed to insert goods receipt: %w", err)
        }
    }

    // Update purchase details with received quantities
    for _, item := range req.Items {
		// Verify purchase detail exists
		var currentQuantity float64
		err = tx.QueryRow(`
			SELECT quantity FROM purchase_details 
			WHERE purchase_detail_id = $1 AND purchase_id = $2
		`, item.PurchaseDetailID, purchaseID).Scan(&currentQuantity)
		if err != nil {
			if err == sql.ErrNoRows {
				return fmt.Errorf("purchase detail with ID %d not found", item.PurchaseDetailID)
			}
			return fmt.Errorf("failed to verify purchase detail: %w", err)
		}

		if item.ReceivedQuantity > currentQuantity {
			return fmt.Errorf("received quantity cannot exceed ordered quantity for detail ID %d", item.PurchaseDetailID)
		}

		// Update received quantity
		_, err = tx.Exec(`
			UPDATE purchase_details 
			SET received_quantity = $1
			WHERE purchase_detail_id = $2
		`, item.ReceivedQuantity, item.PurchaseDetailID)
		if err != nil {
			return fmt.Errorf("failed to update received quantity: %w", err)
		}

		// Get product ID for stock update
		var productID int
		var costPrice float64
		err = tx.QueryRow(`
			SELECT product_id, unit_price FROM purchase_details 
			WHERE purchase_detail_id = $1
		`, item.PurchaseDetailID).Scan(&productID, &costPrice)
		if err != nil {
			return fmt.Errorf("failed to get product details: %w", err)
		}

		// Validate serial numbers for serialized products
		var isSerialized bool
		if err = tx.QueryRow("SELECT is_serialized FROM products WHERE product_id = $1 AND is_deleted = FALSE", productID).Scan(&isSerialized); err != nil {
			if err == sql.ErrNoRows {
				return fmt.Errorf("product not found")
			}
			return fmt.Errorf("failed to verify product: %w", err)
		}
		if isSerialized {
			if item.ReceivedQuantity != float64(int(item.ReceivedQuantity)) {
				return fmt.Errorf("received quantity must be a whole number for serialized products")
			}
			if len(item.SerialNumbers) != int(item.ReceivedQuantity) {
				return fmt.Errorf("serial numbers count must equal received quantity for serialized products")
			}
			seen := make(map[string]struct{}, len(item.SerialNumbers))
			for _, srl := range item.SerialNumbers {
				if srl == "" {
					return fmt.Errorf("serial numbers cannot be empty for serialized products")
				}
				if _, ok := seen[srl]; ok {
					return fmt.Errorf("duplicate serial number '%s' in received items", srl)
				}
				seen[srl] = struct{}{}
			}
		} else if len(item.SerialNumbers) > 0 {
			return fmt.Errorf("serial numbers provided for a non-serialized product")
		}

        // Insert goods receipt item row (if supported)
        if grSupported {
            lineTotal := item.ReceivedQuantity * costPrice
            if _, err := tx.Exec(`
                INSERT INTO goods_receipt_items (goods_receipt_id, product_id, received_quantity, unit_price, line_total)
                VALUES ($1, $2, $3, $4, $5)
            `, goodsReceiptID, productID, item.ReceivedQuantity, costPrice, lineTotal); err != nil {
                if pqErr, ok := err.(*pq.Error); ok && (string(pqErr.Code) == "42P01" || string(pqErr.Code) == "42703") {
                    grSupported = false
                } else {
                    return fmt.Errorf("failed to insert goods receipt item: %w", err)
                }
            }
        }

        // Update or insert stock
        _, err = tx.Exec(`
            INSERT INTO stock (location_id, product_id, quantity, last_updated)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
            ON CONFLICT (location_id, product_id)
            DO UPDATE SET 
                quantity = stock.quantity + $3,
                last_updated = CURRENT_TIMESTAMP
        `, locationID, productID, item.ReceivedQuantity)
        if err != nil {
            return fmt.Errorf("failed to update stock: %w", err)
        }

        // Create stock lot entry for FIFO tracking
        if item.ReceivedQuantity > 0 {
            // Try inserting with goods_receipt_id if supported; otherwise fallback to legacy columns
            if grSupported {
                _, err = tx.Exec(`
                    INSERT INTO stock_lots (product_id, location_id, supplier_id, purchase_id, goods_receipt_id,
                                           quantity, remaining_quantity, cost_price, received_date,
                                           expiry_date, batch_number, serial_numbers)
                    SELECT pd.product_id, $1, p.supplier_id, p.purchase_id, $2,
                           $3, $3, pd.unit_price, CURRENT_DATE,
                           $4, $5, $6
                    FROM purchase_details pd
                    JOIN purchases p ON pd.purchase_id = p.purchase_id
                    WHERE pd.purchase_detail_id = $7
                `, locationID, goodsReceiptID, item.ReceivedQuantity, item.ExpiryDate, item.BatchNumber,
                    pq.Array(item.SerialNumbers), item.PurchaseDetailID)
                if err != nil {
                    if pqErr, ok := err.(*pq.Error); ok && string(pqErr.Code) == "42703" {
                        // Column goods_receipt_id missing; fallback to legacy insert
                        _, err = tx.Exec(`
                            INSERT INTO stock_lots (product_id, location_id, supplier_id, purchase_id,
                                                   quantity, remaining_quantity, cost_price, received_date,
                                                   expiry_date, batch_number, serial_numbers)
                            SELECT pd.product_id, $1, p.supplier_id, p.purchase_id,
                                   $2, $2, pd.unit_price, CURRENT_DATE,
                                   $3, $4, $5
                            FROM purchase_details pd
                            JOIN purchases p ON pd.purchase_id = p.purchase_id
                            WHERE pd.purchase_detail_id = $6
                        `, locationID, item.ReceivedQuantity, item.ExpiryDate, item.BatchNumber,
                            pq.Array(item.SerialNumbers), item.PurchaseDetailID)
                        if err != nil {
                            return fmt.Errorf("failed to create stock lot: %w", err)
                        }
                    } else if err != nil {
                        return fmt.Errorf("failed to create stock lot: %w", err)
                    }
                }
            } else {
                _, err = tx.Exec(`
                    INSERT INTO stock_lots (product_id, location_id, supplier_id, purchase_id,
                                           quantity, remaining_quantity, cost_price, received_date,
                                           expiry_date, batch_number, serial_numbers)
                    SELECT pd.product_id, $1, p.supplier_id, p.purchase_id,
                           $2, $2, pd.unit_price, CURRENT_DATE,
                           $3, $4, $5
                    FROM purchase_details pd
                    JOIN purchases p ON pd.purchase_id = p.purchase_id
                    WHERE pd.purchase_detail_id = $6
                `, locationID, item.ReceivedQuantity, item.ExpiryDate, item.BatchNumber,
                    pq.Array(item.SerialNumbers), item.PurchaseDetailID)
                if err != nil {
                    return fmt.Errorf("failed to create stock lot: %w", err)
                }
            }
        }

		// Update product cost price if this is a newer purchase
		_, err = tx.Exec(`
			UPDATE products 
			SET cost_price = $1, updated_at = CURRENT_TIMESTAMP
			WHERE product_id = $2 AND (cost_price IS NULL OR cost_price = 0)
		`, costPrice, productID)
		if err != nil {
			return fmt.Errorf("failed to update product cost price: %w", err)
		}
	}

	// Check if all items are fully received
	var pendingItems int
	err = tx.QueryRow(`
		SELECT COUNT(*) FROM purchase_details 
		WHERE purchase_id = $1 AND quantity > received_quantity
	`, purchaseID).Scan(&pendingItems)
	if err != nil {
		return fmt.Errorf("failed to check pending items: %w", err)
	}

	// Update purchase status
	newStatus := "PARTIALLY_RECEIVED"
	if pendingItems == 0 {
		newStatus = "RECEIVED"
	}

	_, err = tx.Exec(`
		UPDATE purchases 
		SET status = $1, updated_by = $2, updated_at = CURRENT_TIMESTAMP
		WHERE purchase_id = $3
	`, newStatus, userID, purchaseID)
	if err != nil {
		return fmt.Errorf("failed to update purchase status: %w", err)
	}

	return tx.Commit()
}

// Add this method to get pending purchases for receiving
func (s *PurchaseService) GetPendingPurchases(companyID, locationID int) ([]models.Purchase, error) {
	query := `
		SELECT p.purchase_id, p.purchase_number, p.supplier_id, p.purchase_date,
			   p.total_amount, p.status, s.name as supplier_name
		FROM purchases p
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE s.company_id = $1 AND p.location_id = $2 
		AND p.status IN ('PENDING', 'PARTIALLY_RECEIVED') 
		AND p.is_deleted = FALSE
		ORDER BY p.purchase_date ASC
	`

	rows, err := s.db.Query(query, companyID, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending purchases: %w", err)
	}
	defer rows.Close()

	var purchases []models.Purchase
	for rows.Next() {
		var p models.Purchase
		var supplierName string

		err := rows.Scan(
			&p.PurchaseID, &p.PurchaseNumber, &p.SupplierID, &p.PurchaseDate,
			&p.TotalAmount, &p.Status, &supplierName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan purchase: %w", err)
		}

		p.Supplier = &models.Supplier{Name: supplierName}
		purchases = append(purchases, p)
	}

	return purchases, nil
}

// GetGoodsReceipts returns goods receipts for a location with optional filters
func (s *PurchaseService) GetGoodsReceipts(companyID, locationID int, filters map[string]string) ([]models.GoodsReceipt, error) {
    query := `
        SELECT gr.goods_receipt_id, gr.receipt_number, gr.purchase_id, gr.location_id, gr.supplier_id,
               gr.received_date, gr.received_by,
               s.name as supplier_name, l.name as location_name
        FROM goods_receipts gr
        JOIN suppliers s ON gr.supplier_id = s.supplier_id
        JOIN locations l ON gr.location_id = l.location_id
        WHERE s.company_id = $1 AND gr.location_id = $2 AND gr.is_deleted = FALSE
    `

    args := []interface{}{companyID, locationID}
    arg := 2
    if search, ok := filters["search"]; ok && strings.TrimSpace(search) != "" {
        arg += 1
        query += fmt.Sprintf(" AND (gr.receipt_number ILIKE $%d OR s.name ILIKE $%d)", arg, arg)
        args = append(args, "%"+strings.TrimSpace(search)+"%")
    }

    query += " ORDER BY gr.received_date DESC, gr.goods_receipt_id DESC"

    rows, err := s.db.Query(query, args...)
    if err != nil {
        return nil, fmt.Errorf("failed to get goods receipts: %w", err)
    }
    defer rows.Close()

    var list []models.GoodsReceipt
    for rows.Next() {
        var gr models.GoodsReceipt
        var supplierName, locationName string
        if err := rows.Scan(&gr.GoodsReceiptID, &gr.ReceiptNumber, &gr.PurchaseID, &gr.LocationID, &gr.SupplierID,
            &gr.ReceivedDate, &gr.ReceivedBy, &supplierName, &locationName); err != nil {
            return nil, fmt.Errorf("failed to scan goods receipt: %w", err)
        }
        gr.Supplier = &models.Supplier{Name: supplierName}
        gr.Location = &models.Location{Name: locationName}
        list = append(list, gr)
    }
    return list, nil
}

func (s *PurchaseService) UpdatePurchase(purchaseID, companyID, userID int, req *models.UpdatePurchaseRequest) error {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Verify purchase exists and belongs to company
	var currentStatus string
	err = tx.QueryRow(`
		SELECT p.status FROM purchases p
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, purchaseID, companyID).Scan(&currentStatus)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("purchase not found")
		}
		return fmt.Errorf("failed to verify purchase: %w", err)
	}

	// Check if purchase can be updated
	if currentStatus == "RECEIVED" || currentStatus == "CANCELLED" {
		return fmt.Errorf("cannot update purchase with status %s", currentStatus)
	}

	// Build update query
	updates := []string{}
	args := []interface{}{}
	argCount := 0

	if req.ReferenceNumber != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("reference_number = $%d", argCount))
		args = append(args, *req.ReferenceNumber)
	}

	if req.PaymentTerms != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("payment_terms = $%d", argCount))
		args = append(args, *req.PaymentTerms)

		// Update due date if payment terms changed
		argCount++
		updates = append(updates, fmt.Sprintf("due_date = purchase_date + INTERVAL '%d days'", *req.PaymentTerms))
	}

	if req.Notes != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("notes = $%d", argCount))
		args = append(args, *req.Notes)
	}

	if req.Status != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("status = $%d", argCount))
		args = append(args, *req.Status)
	}

	if len(updates) > 0 {
		argCount++
		updates = append(updates, fmt.Sprintf("updated_by = $%d", argCount))
		args = append(args, userID)

		argCount++
		updates = append(updates, fmt.Sprintf("updated_at = $%d", argCount))
		args = append(args, time.Now())

		argCount++
		query := fmt.Sprintf("UPDATE purchases SET %s WHERE purchase_id = $%d",
			strings.Join(updates, ", "), argCount)
		args = append(args, purchaseID)

		_, err = tx.Exec(query, args...)
		if err != nil {
			return fmt.Errorf("failed to update purchase: %w", err)
		}
	}

	// Update items if provided
	if req.Items != nil {
		// Delete existing items
		_, err = tx.Exec("DELETE FROM purchase_details WHERE purchase_id = $1", purchaseID)
		if err != nil {
			return fmt.Errorf("failed to delete existing purchase details: %w", err)
		}

		// Insert new items
		for _, item := range req.Items {
			lineTotal := item.Quantity * item.UnitPrice

			// Apply discount
			discountAmount := float64(0)
			if item.DiscountPercentage != nil {
				discountAmount = lineTotal * (*item.DiscountPercentage / 100)
			}
			if item.DiscountAmount != nil {
				discountAmount = *item.DiscountAmount
			}

			lineTotal -= discountAmount

			// Calculate tax
			taxAmount := float64(0)
			if item.TaxID != nil {
				var taxPercentage float64
				err = tx.QueryRow("SELECT percentage FROM taxes WHERE tax_id = $1 AND is_active = TRUE",
					*item.TaxID).Scan(&taxPercentage)
				if err == nil {
					taxAmount = lineTotal * (taxPercentage / 100)
				}
			}

			finalLineTotal := lineTotal + taxAmount

			// Validate serial numbers if product is serialized
			var isSerialized bool
			if err = tx.QueryRow("SELECT is_serialized FROM products WHERE product_id = $1 AND is_deleted = FALSE", item.ProductID).Scan(&isSerialized); err != nil {
				if err == sql.ErrNoRows {
					return fmt.Errorf("product with ID %d not found", item.ProductID)
				}
				return fmt.Errorf("failed to verify product: %w", err)
			}
			if isSerialized {
				if item.Quantity != float64(int(item.Quantity)) {
					return fmt.Errorf("quantity must be a whole number for serialized products (product_id=%d)", item.ProductID)
				}
				if len(item.SerialNumbers) != int(item.Quantity) {
					return fmt.Errorf("serial numbers count must equal quantity for serialized products (product_id=%d)", item.ProductID)
				}
				seen := make(map[string]struct{}, len(item.SerialNumbers))
				for _, srl := range item.SerialNumbers {
					if srl == "" {
						return fmt.Errorf("serial numbers cannot be empty for serialized products (product_id=%d)", item.ProductID)
					}
					if _, ok := seen[srl]; ok {
						return fmt.Errorf("duplicate serial number '%s' in purchase item (product_id=%d)", srl, item.ProductID)
					}
					seen[srl] = struct{}{}
				}
			} else if len(item.SerialNumbers) > 0 {
				return fmt.Errorf("serial numbers provided for a non-serialized product (product_id=%d)", item.ProductID)
			}

			_, err = tx.Exec(`
				INSERT INTO purchase_details (purchase_id, product_id, quantity, unit_price,
											discount_percentage, discount_amount, tax_id, tax_amount,
											line_total, received_quantity, serial_numbers, expiry_date, batch_number)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
			`,
				purchaseID, item.ProductID, item.Quantity, item.UnitPrice,
				item.DiscountPercentage, discountAmount, item.TaxID, taxAmount,
				finalLineTotal, 0, pq.Array(item.SerialNumbers), item.ExpiryDate, item.BatchNumber,
			)
			if err != nil {
				return fmt.Errorf("failed to insert purchase detail: %w", err)
			}
		}

		// Recalculate totals
		var subtotal, totalTax, totalDiscount float64
		rows, err := tx.Query(`
			SELECT COALESCE(SUM(line_total), 0), COALESCE(SUM(tax_amount), 0), COALESCE(SUM(discount_amount), 0)
			FROM purchase_details WHERE purchase_id = $1
		`, purchaseID)
		if err != nil {
			return fmt.Errorf("failed to calculate totals: %w", err)
		}
		defer rows.Close()

		if rows.Next() {
			err = rows.Scan(&subtotal, &totalTax, &totalDiscount)
			if err != nil {
				return fmt.Errorf("failed to scan totals: %w", err)
			}
		}

		// Update purchase totals
		_, err = tx.Exec(`
			UPDATE purchases SET subtotal = $1, tax_amount = $2, discount_amount = $3, 
							   total_amount = $1, updated_by = $4, updated_at = $5
			WHERE purchase_id = $6
		`, subtotal, totalTax, totalDiscount, userID, time.Now(), purchaseID)
		if err != nil {
			return fmt.Errorf("failed to update purchase totals: %w", err)
		}
	}

	return tx.Commit()
}

// SetPurchaseInvoiceFile updates purchases.invoice_file for a purchase within the company
func (s *PurchaseService) SetPurchaseInvoiceFile(purchaseID, companyID int, path string) error {
    // Verify belongs to company
    var exists int
    if err := s.db.QueryRow(`
        SELECT COUNT(*) FROM purchases p
        JOIN suppliers s ON p.supplier_id = s.supplier_id
        WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
    `, purchaseID, companyID).Scan(&exists); err != nil {
        return fmt.Errorf("failed to verify purchase: %w", err)
    }
    if exists == 0 {
        return fmt.Errorf("purchase not found")
    }
    // Check if column exists; if not, skip update for backward compatibility
    var colCount int
    if err := s.db.QueryRow(`SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'invoice_file'`).Scan(&colCount); err == nil && colCount == 0 {
        // Silently ignore missing column
        return nil
    }
    if _, err := s.db.Exec(`UPDATE purchases SET invoice_file = $1, updated_at = CURRENT_TIMESTAMP WHERE purchase_id = $2`, path, purchaseID); err != nil {
        return fmt.Errorf("failed to set invoice file: %w", err)
    }
    return nil
}

func (s *PurchaseService) DeletePurchase(purchaseID, companyID int) error {
	// Verify purchase exists and can be deleted
	var status string
	err := s.db.QueryRow(`
		SELECT p.status FROM purchases p
		JOIN suppliers s ON p.supplier_id = s.supplier_id
		WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, purchaseID, companyID).Scan(&status)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("purchase not found")
		}
		return fmt.Errorf("failed to verify purchase: %w", err)
	}

	if status == "RECEIVED" {
		return fmt.Errorf("cannot delete received purchase")
	}

	// Soft delete
	_, err = s.db.Exec(`
		UPDATE purchases SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP
		WHERE purchase_id = $1
	`, purchaseID)
	if err != nil {
		return fmt.Errorf("failed to delete purchase: %w", err)
	}

	return nil
}

// ApprovePurchaseOrder sets a purchase order's status to APPROVED
func (s *PurchaseService) ApprovePurchaseOrder(purchaseID, companyID, userID int) error {
	_, err := s.db.Exec(`
                UPDATE purchases p
                SET status = 'APPROVED', updated_by = $1, updated_at = CURRENT_TIMESTAMP
                FROM suppliers s
                WHERE p.purchase_id = $2 AND p.supplier_id = s.supplier_id AND s.company_id = $3 AND p.is_deleted = FALSE
        `, userID, purchaseID, companyID)
	if err != nil {
		return fmt.Errorf("failed to approve purchase: %w", err)
	}
	return nil
}

// RecordGoodsReceipt records a goods receipt note for a purchase
func (s *PurchaseService) RecordGoodsReceipt(purchaseID, companyID, userID int, req *models.RecordGoodsReceiptRequest) error {
	receiveReq := &models.ReceivePurchaseRequest{Items: req.Items}
	return s.ReceivePurchase(purchaseID, companyID, userID, receiveReq)
}
