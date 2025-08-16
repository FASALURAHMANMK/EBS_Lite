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

type SalesService struct {
	db *sql.DB
}

func NewSalesService() *SalesService {
	return &SalesService{
		db: database.GetDB(),
	}
}

func (s *SalesService) GetSales(companyID, locationID int, filters map[string]string) ([]models.Sale, error) {
	query := `
		SELECT s.sale_id, s.sale_number, s.location_id, s.customer_id, s.sale_date, s.sale_time,
			   s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, s.notes,
			   s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
			   c.name as customer_name, pm.name as payment_method_name
		FROM sales s
		LEFT JOIN customers c ON s.customer_id = c.customer_id
		LEFT JOIN payment_methods pm ON s.payment_method_id = pm.method_id
		WHERE s.location_id = $1 AND s.is_deleted = FALSE
	`

	args := []interface{}{locationID}
	argCount := 1

	// Add filters
	if dateFrom := filters["date_from"]; dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo := filters["date_to"]; dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	if customerID := filters["customer_id"]; customerID != "" {
		argCount++
		query += fmt.Sprintf(" AND s.customer_id = $%d", argCount)
		args = append(args, customerID)
	}

	if status := filters["status"]; status != "" {
		argCount++
		query += fmt.Sprintf(" AND s.status = $%d", argCount)
		args = append(args, status)
	}

	query += " ORDER BY s.created_at DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get sales: %w", err)
	}
	defer rows.Close()

	var sales []models.Sale
	for rows.Next() {
		var sale models.Sale
		var customerName, paymentMethodName sql.NullString

		err := rows.Scan(
			&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sale.CustomerID,
			&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
			&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
			&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
			&sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
			&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale: %w", err)
		}

		// Set customer info if exists
		if customerName.Valid {
			sale.Customer = &models.Customer{
				CustomerID: *sale.CustomerID,
				Name:       customerName.String,
			}
		}

		// Set payment method info if exists
		if paymentMethodName.Valid {
			sale.PaymentMethod = &models.PaymentMethod{
				MethodID: *sale.PaymentMethodID,
				Name:     paymentMethodName.String,
			}
		}

		sales = append(sales, sale)
	}

	return sales, nil
}

func (s *SalesService) GetSaleByID(saleID, companyID int) (*models.Sale, error) {
	// Get sale details
	query := `
		SELECT s.sale_id, s.sale_number, s.location_id, s.customer_id, s.sale_date, s.sale_time,
			   s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, s.notes,
			   s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
			   c.name as customer_name, pm.name as payment_method_name
		FROM sales s
		LEFT JOIN customers c ON s.customer_id = c.customer_id
		LEFT JOIN payment_methods pm ON s.payment_method_id = pm.method_id
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`

	var sale models.Sale
	var customerName, paymentMethodName sql.NullString

	err := s.db.QueryRow(query, saleID, companyID).Scan(
		&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sale.CustomerID,
		&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
		&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
		&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
		&sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
		&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get sale: %w", err)
	}

	// Set customer info if exists
	if customerName.Valid {
		sale.Customer = &models.Customer{
			CustomerID: *sale.CustomerID,
			Name:       customerName.String,
		}
	}

	// Set payment method info if exists
	if paymentMethodName.Valid {
		sale.PaymentMethod = &models.PaymentMethod{
			MethodID: *sale.PaymentMethodID,
			Name:     paymentMethodName.String,
		}
	}

	// Get sale items
	items, err := s.getSaleItems(saleID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale items: %w", err)
	}
	sale.Items = items

	return &sale, nil
}

// func (s *SalesService) CreateSale(companyID, locationID, userID int, req *models.CreateSaleRequest) (*models.Sale, error) {
// 	// Validate customer belongs to company if provided
// 	if req.CustomerID != nil {
// 		err := s.validateCustomerInCompany(*req.CustomerID, companyID)
// 		if err != nil {
// 			return nil, err
// 		}
// 	}

// 	// Generate sale number
// 	saleNumber := fmt.Sprintf("SALE-%d-%d", time.Now().Unix(), locationID)

// 	// Calculate totals
// 	subtotal := float64(0)
// 	totalTax := float64(0)

// 	for _, item := range req.Items {
// 		lineTotal := item.Quantity * item.UnitPrice
// 		discountAmount := lineTotal * (item.DiscountPercent / 100)
// 		lineTotal -= discountAmount
// 		subtotal += lineTotal

// 		// Calculate tax if tax_id is provided
// 		if item.TaxID != nil {
// 			taxAmount, err := s.calculateTax(lineTotal, *item.TaxID)
// 			if err != nil {
// 				return nil, fmt.Errorf("failed to calculate tax: %w", err)
// 			}
// 			totalTax += taxAmount
// 		}
// 	}

// 	totalAmount := subtotal + totalTax - req.DiscountAmount

// 	// Start transaction
// 	tx, err := s.db.Begin()
// 	if err != nil {
// 		return nil, fmt.Errorf("failed to start transaction: %w", err)
// 	}
// 	defer tx.Rollback()

// 	// Create sale
// 	var saleID int
// 	err = tx.QueryRow(`
// 		INSERT INTO sales (sale_number, location_id, customer_id, sale_date, sale_time,
// 						  subtotal, tax_amount, discount_amount, total_amount, paid_amount,
// 						  payment_method_id, status, pos_status, is_quick_sale, notes, created_by)
// 		VALUES ($1, $2, $3, CURRENT_DATE, CURRENT_TIME, $4, $5, $6, $7, $7, $8, 'COMPLETED', 'COMPLETED', FALSE, $9, $10)
// 		RETURNING sale_id
// 	`, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount,
// 		totalAmount, req.PaymentMethodID, req.Notes, userID).Scan(&saleID)

// 	if err != nil {
// 		return nil, fmt.Errorf("failed to create sale: %w", err)
// 	}

// 	// Create sale items and update stock
// 	for _, item := range req.Items {
// 		// Calculate line total and tax
// 		lineTotal := item.Quantity * item.UnitPrice
// 		discountAmount := lineTotal * (item.DiscountPercent / 100)
// 		lineTotal -= discountAmount

// 		var taxAmount float64
// 		if item.TaxID != nil {
// 			taxAmount, err = s.calculateTax(lineTotal, *item.TaxID)
// 			if err != nil {
// 				return nil, fmt.Errorf("failed to calculate tax: %w", err)
// 			}
// 		}

// 		// Insert sale detail
// 		_, err = tx.Exec(`
// 			INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
// 									 discount_percentage, discount_amount, tax_id, tax_amount,
// 									 line_total, serial_numbers, notes)
// 			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
// 		`, saleID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice,
// 			item.DiscountPercent, discountAmount, item.TaxID, taxAmount, lineTotal,
// 			strings.Join(item.SerialNumbers, ","), item.Notes)

// 		if err != nil {
// 			return nil, fmt.Errorf("failed to create sale item: %w", err)
// 		}

// 		// Update stock if product_id is provided
// 		if item.ProductID != nil {
// 			err = s.updateStock(tx, locationID, *item.ProductID, -item.Quantity)
// 			if err != nil {
// 				return nil, fmt.Errorf("failed to update stock: %w", err)
// 			}
// 		}
// 	}

// 	// Commit transaction
// 	if err = tx.Commit(); err != nil {
// 		return nil, fmt.Errorf("failed to commit transaction: %w", err)
// 	}

// 	// Return created sale
// 	return s.GetSaleByID(saleID, companyID)
// }

func (s *SalesService) CreateSale(companyID, locationID, userID int, req *models.CreateSaleRequest) (*models.Sale, error) {
	// Validate customer belongs to company if provided
	if req.CustomerID != nil {
		err := s.validateCustomerInCompany(*req.CustomerID, companyID)
		if err != nil {
			return nil, err
		}
	}

	// Check for applicable promotions
	var totalDiscount float64
	var appliedPromotions []int
	if req.CustomerID != nil {
		loyaltyService := NewLoyaltyService()

		// Calculate subtotal for promotion eligibility
		subtotal := float64(0)
		for _, item := range req.Items {
			lineTotal := item.Quantity * item.UnitPrice
			discountAmount := lineTotal * (item.DiscountPercent / 100)
			lineTotal -= discountAmount
			subtotal += lineTotal
		}

		// Check promotion eligibility
		eligibilityReq := &models.PromotionEligibilityRequest{
			CustomerID:  req.CustomerID,
			TotalAmount: subtotal,
			ProductIDs:  []int{},
			CategoryIDs: []int{},
		}

		productIDSet := make(map[int]struct{})
		for _, item := range req.Items {
			if item.ProductID == nil {
				continue
			}
			id := *item.ProductID
			if _, exists := productIDSet[id]; exists {
				continue
			}
			productIDSet[id] = struct{}{}
			eligibilityReq.ProductIDs = append(eligibilityReq.ProductIDs, id)
		}

		// Fetch categories for the collected products
		if len(eligibilityReq.ProductIDs) > 0 {
			rows, err := s.db.Query("SELECT product_id, category_id FROM products WHERE product_id = ANY($1)", pq.Array(eligibilityReq.ProductIDs))
			if err != nil {
				return nil, fmt.Errorf("failed to get product categories: %w", err)
			}
			defer rows.Close()

			categorySet := make(map[int]struct{})
			for rows.Next() {
				var pid int
				var cid sql.NullInt64
				if err := rows.Scan(&pid, &cid); err != nil {
					return nil, fmt.Errorf("failed to scan product category: %w", err)
				}
				if cid.Valid {
					id := int(cid.Int64)
					if _, exists := categorySet[id]; !exists {
						categorySet[id] = struct{}{}
						eligibilityReq.CategoryIDs = append(eligibilityReq.CategoryIDs, id)
					}
				}
			}
		}

		eligibility, err := loyaltyService.CheckPromotionEligibility(companyID, eligibilityReq)
		if err == nil && eligibility.TotalDiscount > 0 {
			totalDiscount = eligibility.TotalDiscount
			for _, promo := range eligibility.EligiblePromotions {
				appliedPromotions = append(appliedPromotions, promo.PromotionID)
			}
		}
	}

	// Add promotion discount to existing discount
	req.DiscountAmount += totalDiscount

	// Calculate totals
	subtotal := float64(0)
	totalTax := float64(0)

	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount
		subtotal += lineTotal

		// Calculate tax if tax_id is provided
		if item.TaxID != nil {
			taxAmount, err := s.calculateTax(lineTotal, *item.TaxID)
			if err != nil {
				return nil, fmt.Errorf("failed to calculate tax: %w", err)
			}
			totalTax += taxAmount
		}
	}

	totalAmount := subtotal + totalTax - req.DiscountAmount

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Generate sale number using numbering sequence service
	ns := NewNumberingSequenceService()
	saleNumber, err := ns.NextNumber(tx, "sale", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate sale number: %w", err)
	}

	// Create sale
	var saleID int
	err = tx.QueryRow(`
               INSERT INTO sales (sale_number, location_id, customer_id, sale_date, sale_time,
                                                 subtotal, tax_amount, discount_amount, total_amount, paid_amount,
                                                 payment_method_id, status, pos_status, is_quick_sale, notes, created_by, updated_by)
               VALUES ($1, $2, $3, CURRENT_DATE, CURRENT_TIME, $4, $5, $6, $7, $8, $9, 'COMPLETED', 'COMPLETED', FALSE, $10, $11, $11)
               RETURNING sale_id
       `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount,
		totalAmount, req.PaidAmount, req.PaymentMethodID, req.Notes, userID).Scan(&saleID)

	if err != nil {
		return nil, fmt.Errorf("failed to create sale: %w", err)
	}

	// Create sale items and update stock
	for _, item := range req.Items {
		// Calculate line total and tax
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount

		var taxAmount float64
		if item.TaxID != nil {
			taxAmount, err = s.calculateTax(lineTotal, *item.TaxID)
			if err != nil {
				return nil, fmt.Errorf("failed to calculate tax: %w", err)
			}
		}

		// Insert sale detail
		_, err = tx.Exec(`
			INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
									 discount_percentage, discount_amount, tax_id, tax_amount, 
									 line_total, serial_numbers, notes)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		`, saleID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice,
			item.DiscountPercent, discountAmount, item.TaxID, taxAmount, lineTotal,
			strings.Join(item.SerialNumbers, ","), item.Notes)

		if err != nil {
			return nil, fmt.Errorf("failed to create sale item: %w", err)
		}

		// Update stock if product_id is provided
		if item.ProductID != nil {
			err = s.updateStock(tx, locationID, *item.ProductID, -item.Quantity)
			if err != nil {
				return nil, fmt.Errorf("failed to update stock: %w", err)
			}
		}
	}

	// Record applied promotions (if any)
	for _, promotionID := range appliedPromotions {
		_, err = tx.Exec(`
			INSERT INTO sale_promotions (sale_id, promotion_id, discount_amount)
			VALUES ($1, $2, $3)
		`, saleID, promotionID, totalDiscount/float64(len(appliedPromotions))) // Distribute discount evenly

		if err != nil {
			// Log error but don't fail the sale
			fmt.Printf("Warning: Failed to record promotion %d for sale %d: %v\n", promotionID, saleID, err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Record ledger entry
	ledgerService := NewLedgerService()
	_ = ledgerService.RecordSale(companyID, saleID, totalAmount)

	// Award loyalty points if customer is provided (async operation)
	if req.CustomerID != nil {
		go func() {
			loyaltyService := NewLoyaltyService()
			err := loyaltyService.AwardPoints(*req.CustomerID, totalAmount, saleID)
			if err != nil {
				// Log error but don't fail the sale
				fmt.Printf("Warning: Failed to award loyalty points for sale %d: %v\n", saleID, err)
			}
		}()
	}

	// Return created sale
	return s.GetSaleByID(saleID, companyID)
}

// Add this helper method to validate customer belongs to company
func (s *SalesService) validateCustomerInCompany(customerID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM customers 
		WHERE customer_id = $1 AND company_id = $2 AND is_deleted = FALSE
	`, customerID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to validate customer: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("customer not found")
	}

	return nil
}

func (s *SalesService) UpdateSale(saleID, companyID, userID int, req *models.UpdateSaleRequest) error {
	// Verify sale exists and belongs to company
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.PaymentMethodID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("payment_method_id = $%d", argCount))
		args = append(args, *req.PaymentMethodID)
	}
	if req.Notes != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("notes = $%d", argCount))
		args = append(args, *req.Notes)
	}
	if req.Status != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("status = $%d", argCount))
		args = append(args, *req.Status)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)

	argCount++
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE sales SET %s WHERE sale_id = $%d",
		strings.Join(setParts, ", "), argCount)
	args = append(args, saleID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update sale: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

func (s *SalesService) DeleteSale(saleID, companyID, userID int) error {
	// Verify sale exists and belongs to company
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	// Check if sale can be deleted (not finalized, etc.)
	var status string
	err = s.db.QueryRow("SELECT status FROM sales WHERE sale_id = $1", saleID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get sale status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed sales cannot be deleted")
	}

	query := `UPDATE sales SET is_deleted = TRUE, updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE sale_id = $1`

	result, err := s.db.Exec(query, saleID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete sale: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

func (s *SalesService) HoldSale(saleID, companyID, userID int) error {
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	query := `UPDATE sales SET pos_status = 'HOLD', updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE sale_id = $1`

	result, err := s.db.Exec(query, saleID, userID)
	if err != nil {
		return fmt.Errorf("failed to hold sale: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

func (s *SalesService) ResumeSale(saleID, companyID, userID int) error {
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	query := `UPDATE sales SET pos_status = 'ACTIVE', updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE sale_id = $1`

	result, err := s.db.Exec(query, saleID, userID)
	if err != nil {
		return fmt.Errorf("failed to resume sale: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

func (s *SalesService) CreateQuickSale(companyID, locationID, userID int, req *models.QuickSaleRequest) (*models.Sale, error) {
	createReq := &models.CreateSaleRequest{
		Items: req.Items,
	}

	// Mark as quick sale by updating after creation
	sale, err := s.CreateSale(companyID, locationID, userID, createReq)
	if err != nil {
		return nil, err
	}

	// Ensure quick sales are fully paid
	_, err = s.db.Exec("UPDATE sales SET paid_amount = total_amount, is_quick_sale = TRUE WHERE sale_id = $1", sale.SaleID)
	if err != nil {
		return nil, fmt.Errorf("failed to mark as quick sale: %w", err)
	}

	sale.IsQuickSale = true
	sale.PaidAmount = sale.TotalAmount
	return sale, nil
}

// Helper methods
func (s *SalesService) getSaleItems(saleID int) ([]models.SaleDetail, error) {
	query := `
		SELECT sd.sale_detail_id, sd.sale_id, sd.product_id, sd.product_name, sd.quantity,
			   sd.unit_price, sd.discount_percentage, sd.discount_amount, sd.tax_id,
			   sd.tax_amount, sd.line_total, sd.serial_numbers, sd.notes,
			   p.name as product_name_from_table
		FROM sale_details sd
		LEFT JOIN products p ON sd.product_id = p.product_id
		WHERE sd.sale_id = $1
		ORDER BY sd.sale_detail_id
	`

	rows, err := s.db.Query(query, saleID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale items: %w", err)
	}
	defer rows.Close()

	var items []models.SaleDetail
	for rows.Next() {
		var item models.SaleDetail
		var serialNumbers sql.NullString
		var productNameFromTable sql.NullString

		err := rows.Scan(
			&item.SaleDetailID, &item.SaleID, &item.ProductID, &item.ProductName,
			&item.Quantity, &item.UnitPrice, &item.DiscountPercent, &item.DiscountAmount,
			&item.TaxID, &item.TaxAmount, &item.LineTotal, &serialNumbers, &item.Notes,
			&productNameFromTable,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale item: %w", err)
		}

		// Handle serial numbers
		if serialNumbers.Valid && serialNumbers.String != "" {
			item.SerialNumbers = strings.Split(serialNumbers.String, ",")
		}

		// Set product name from products table if available
		if productNameFromTable.Valid {
			item.ProductName = &productNameFromTable.String
		}

		items = append(items, item)
	}

	return items, nil
}

func (s *SalesService) calculateTax(amount float64, taxID int) (float64, error) {
	var taxPercentage float64
	err := s.db.QueryRow("SELECT percentage FROM taxes WHERE tax_id = $1", taxID).Scan(&taxPercentage)
	if err != nil {
		return 0, fmt.Errorf("failed to get tax percentage: %w", err)
	}

	return amount * (taxPercentage / 100), nil
}

func (s *SalesService) updateStock(tx *sql.Tx, locationID, productID int, quantityChange float64) error {
	_, err := tx.Exec(`
		INSERT INTO stock (location_id, product_id, quantity, last_updated)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
		ON CONFLICT (location_id, product_id)
		DO UPDATE SET 
			quantity = stock.quantity + $3,
			last_updated = CURRENT_TIMESTAMP
	`, locationID, productID, quantityChange)

	return err
}

func (s *SalesService) verifySaleInCompany(saleID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to verify sale: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

// GetSalesHistory retrieves sales for a company with optional filtering by
// date range, customer, product and payment method. This is used for the sales
// history endpoint.
func (s *SalesService) GetSalesHistory(companyID int, filters map[string]string) ([]models.Sale, error) {
	query := `
                SELECT s.sale_id, s.sale_number, s.location_id, s.customer_id, s.sale_date, s.sale_time,
                       s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
                       s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, s.notes,
                       s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
                       c.name as customer_name, pm.name as payment_method_name
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                LEFT JOIN customers c ON s.customer_id = c.customer_id
                LEFT JOIN payment_methods pm ON s.payment_method_id = pm.method_id
                WHERE l.company_id = $1 AND s.is_deleted = FALSE
        `

	args := []interface{}{companyID}
	argCount := 1

	if dateFrom := filters["date_from"]; dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date >= $%d", argCount)
		args = append(args, dateFrom)
	}
	if dateTo := filters["date_to"]; dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date <= $%d", argCount)
		args = append(args, dateTo)
	}
	if customerID := filters["customer_id"]; customerID != "" {
		argCount++
		query += fmt.Sprintf(" AND s.customer_id = $%d", argCount)
		args = append(args, customerID)
	}
	if paymentMethodID := filters["payment_method_id"]; paymentMethodID != "" {
		argCount++
		query += fmt.Sprintf(" AND s.payment_method_id = $%d", argCount)
		args = append(args, paymentMethodID)
	}
	if productID := filters["product_id"]; productID != "" {
		argCount++
		query += fmt.Sprintf(" AND EXISTS (SELECT 1 FROM sale_details sd WHERE sd.sale_id = s.sale_id AND sd.product_id = $%d)", argCount)
		args = append(args, productID)
	}

	query += " ORDER BY s.created_at DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get sales history: %w", err)
	}
	defer rows.Close()

	var sales []models.Sale
	for rows.Next() {
		var sale models.Sale
		var customerName, paymentMethodName sql.NullString

		err := rows.Scan(
			&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sale.CustomerID,
			&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
			&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
			&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
			&sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
			&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale: %w", err)
		}

		if customerName.Valid {
			sale.Customer = &models.Customer{
				CustomerID: *sale.CustomerID,
				Name:       customerName.String,
			}
		}

		if paymentMethodName.Valid {
			sale.PaymentMethod = &models.PaymentMethod{
				MethodID: *sale.PaymentMethodID,
				Name:     paymentMethodName.String,
			}
		}

		sales = append(sales, sale)
	}

	return sales, nil
}

// ExportInvoices returns the list of sales matching the provided filters. In a
// real implementation this could generate files (PDF/CSV). For now it simply
// returns the sales data.
func (s *SalesService) ExportInvoices(companyID int, filters map[string]string) ([]models.Sale, error) {
	return s.GetSalesHistory(companyID, filters)
}

// Quote-related operations ---------------------------------------------------

// GetQuotes returns quotes for a company. Currently returns an empty list until
// a persistent store is introduced.
func (s *SalesService) GetQuotes(companyID int, filters map[string]string) ([]models.Quote, error) {
	return []models.Quote{}, nil
}

// GetQuoteByID returns a single quote. This is a stub implementation.
func (s *SalesService) GetQuoteByID(quoteID, companyID int) (*models.Quote, error) {
	return &models.Quote{QuoteID: quoteID}, nil
}

// CreateQuote creates a new quote. Currently this is an in-memory placeholder
// without persistence.
func (s *SalesService) CreateQuote(companyID, locationID, userID int, req *models.CreateQuoteRequest) (*models.Quote, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	ns := NewNumberingSequenceService()
	quoteNumber, err := ns.NextNumber(tx, "quote", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate quote number: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	quote := &models.Quote{
		QuoteID:     0,
		QuoteNumber: quoteNumber,
		LocationID:  locationID,
		CustomerID:  req.CustomerID,
		QuoteDate:   time.Now(),
		Status:      "draft",
		Items:       []models.QuoteItem{},
		CreatedBy:   userID,
	}
	return quote, nil
}

// UpdateQuote updates an existing quote.
func (s *SalesService) UpdateQuote(quoteID, companyID int, req *models.UpdateQuoteRequest) error {
	return nil
}

// DeleteQuote deletes a quote.
func (s *SalesService) DeleteQuote(quoteID, companyID int) error {
	return nil
}

// PrintQuote handles printing of a quote. For now it only logs the request.
func (s *SalesService) PrintQuote(quoteID, companyID int) error {
	fmt.Printf("Print requested for quote ID: %d\n", quoteID)
	return nil
}

// ShareQuote handles quote sharing logic. Currently a placeholder that logs the
// request.
func (s *SalesService) ShareQuote(quoteID, companyID int, req *models.ShareQuoteRequest) error {
	fmt.Printf("Share requested for quote ID: %d with %s\n", quoteID, req.Email)
	return nil
}

// ExportQuotes returns quotes that match provided filters.
func (s *SalesService) ExportQuotes(companyID int, filters map[string]string) ([]models.Quote, error) {
	return s.GetQuotes(companyID, filters)
}
