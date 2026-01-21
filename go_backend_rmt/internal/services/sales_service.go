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

// CalculateTotals computes the subtotal, total tax, and final total for a sale
// request. It is used by handlers for validation and internally by the service
// before persisting a sale.
func (s *SalesService) CalculateTotals(companyID int, req *models.CreateSaleRequest) (float64, float64, float64, error) {
	subtotal := float64(0)
	totalTax := float64(0)

	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount
		subtotal += lineTotal

		// Resolve tax: prefer explicit tax_id, otherwise fallback to product's tax_id field
		var productTaxID *int
		if item.ProductID != nil {
			var prodTaxID sql.NullInt64
			err := s.db.QueryRow(`SELECT tax_id FROM products WHERE product_id=$1 AND company_id=$2 AND is_deleted=FALSE`, *item.ProductID, companyID).Scan(&prodTaxID)
			if err == sql.ErrNoRows {
				return 0, 0, 0, fmt.Errorf("product not found")
			}
			if err != nil {
				return 0, 0, 0, fmt.Errorf("failed to resolve product tax: %w", err)
			}
			if prodTaxID.Valid && prodTaxID.Int64 > 0 {
				id := int(prodTaxID.Int64)
				productTaxID = &id
			}
		}

		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if productTaxID != nil {
			effectiveTaxID = productTaxID
		}
		if effectiveTaxID != nil {
			taxAmount, err := s.calculateTax(companyID, lineTotal, *effectiveTaxID)
			if err != nil {
				return 0, 0, 0, fmt.Errorf("failed to calculate tax: %w", err)
			}
			totalTax += taxAmount
		}
	}

	totalAmount := subtotal + totalTax - req.DiscountAmount

	return subtotal, totalTax, totalAmount, nil
}

func (s *SalesService) GetSales(companyID, locationID int, filters map[string]string) ([]models.Sale, error) {
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
		WHERE l.company_id = $1 AND s.location_id = $2 AND s.is_deleted = FALSE
	`

	args := []interface{}{companyID, locationID}
	argCount := 2

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

	// Filter by POS status if provided (e.g., HOLD, ACTIVE, COMPLETED)
	if posStatus := filters["pos_status"]; posStatus != "" {
		argCount++
		query += fmt.Sprintf(" AND s.pos_status = $%d", argCount)
		args = append(args, posStatus)
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
	items, err := s.getSaleItems(saleID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale items: %w", err)
	}
	sale.Items = items

	return &sale, nil
}

// GetSaleByNumber fetches a sale by its sale_number within a company.
func (s *SalesService) GetSaleByNumber(saleNumber string, companyID int) (*models.Sale, error) {
	query := `
        SELECT s.sale_id
        FROM sales s
        JOIN locations l ON s.location_id = l.location_id
        WHERE s.sale_number = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
    `
	var saleID int
	if err := s.db.QueryRow(query, saleNumber, companyID).Scan(&saleID); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("sale not found")
		}
		return nil, fmt.Errorf("failed to resolve sale by number: %w", err)
	}
	return s.GetSaleByID(saleID, companyID)
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

func (s *SalesService) CreateSale(companyID, locationID, userID int, req *models.CreateSaleRequest, idempotencyKey *string) (*models.Sale, error) {
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

	subtotal, totalTax, totalAmount, err := s.CalculateTotals(companyID, req)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate totals: %w", err)
	}

	if req.PaidAmount < 0 {
		return nil, fmt.Errorf("paid amount cannot be negative")
	}
	if req.PaidAmount > totalAmount {
		return nil, fmt.Errorf("paid amount cannot exceed total amount")
	}

	if err := s.validateLocationInCompany(locationID, companyID); err != nil {
		return nil, err
	}

	idemKey := ""
	if idempotencyKey != nil {
		idemKey = strings.TrimSpace(*idempotencyKey)
	}
	if idemKey != "" {
		existing, err := s.getSaleByIdempotencyKey(idemKey, companyID, locationID)
		if err != nil {
			return nil, err
		}
		if existing != nil {
			return existing, nil
		}
	}

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
                                                 payment_method_id, status, pos_status, is_quick_sale, notes, created_by, updated_by, idempotency_key)
               VALUES ($1, $2, $3, CURRENT_DATE, CURRENT_TIME, $4, $5, $6, $7, $8, $9, 'COMPLETED', 'COMPLETED', FALSE, $10, $11, $11, $12)
               RETURNING sale_id
       `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount,
		totalAmount, req.PaidAmount, req.PaymentMethodID, req.Notes, userID, nullIfEmpty(idemKey)).Scan(&saleID)

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
		// Resolve tax: prefer explicit tax_id, otherwise fallback to product's tax_id field
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ProductID != nil {
			var prodTaxID sql.NullInt64
			q := `SELECT tax_id FROM products WHERE product_id=$1 AND company_id=$2 AND is_deleted=FALSE`
			if err := tx.QueryRow(q, *item.ProductID, companyID).Scan(&prodTaxID); err == nil && prodTaxID.Valid && prodTaxID.Int64 > 0 {
				id := int(prodTaxID.Int64)
				effectiveTaxID = &id
			} else if err != nil && err != sql.ErrNoRows {
				return nil, fmt.Errorf("failed to resolve product tax: %w", err)
			}
		}
		if effectiveTaxID != nil {
			taxAmount, err = s.calculateTax(companyID, lineTotal, *effectiveTaxID)
			if err != nil {
				return nil, fmt.Errorf("failed to calculate tax: %w", err)
			}
		}

		// Validate serial numbers for serialized products
		if item.ProductID != nil {
			var isSerialized bool
			err = tx.QueryRow("SELECT is_serialized FROM products WHERE product_id = $1 AND company_id = $2 AND is_deleted = FALSE", *item.ProductID, companyID).Scan(&isSerialized)
			if err != nil {
				if err == sql.ErrNoRows {
					return nil, fmt.Errorf("product not found")
				}
				return nil, fmt.Errorf("failed to verify product: %w", err)
			}
			if isSerialized {
				if item.Quantity != float64(int(item.Quantity)) {
					return nil, fmt.Errorf("quantity must be a whole number for serialized products")
				}
				if len(item.SerialNumbers) != int(item.Quantity) {
					return nil, fmt.Errorf("serial numbers count must equal quantity for serialized products")
				}
				seen := make(map[string]struct{}, len(item.SerialNumbers))
				for _, srl := range item.SerialNumbers {
					if srl == "" {
						return nil, fmt.Errorf("serial numbers cannot be empty for serialized products")
					}
					if _, ok := seen[srl]; ok {
						return nil, fmt.Errorf("duplicate serial number '%s' in sale item", srl)
					}
					seen[srl] = struct{}{}
				}
			} else {
				if len(item.SerialNumbers) > 0 {
					return nil, fmt.Errorf("serial numbers provided for a non-serialized product")
				}
			}
		}

		// Insert sale detail
		_, err = tx.Exec(`
			INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
									 discount_percentage, discount_amount, tax_id, tax_amount, 
									 line_total, serial_numbers, notes)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		`, saleID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice,
			item.DiscountPercent, discountAmount, effectiveTaxID, taxAmount, lineTotal,
			pq.Array(item.SerialNumbers), item.Notes)

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
	_ = ledgerService.RecordSale(companyID, saleID, totalAmount, userID)

	// Award loyalty points if customer is provided (async operation)
	if req.CustomerID != nil {
		go func() {
			loyaltyService := NewLoyaltyService()
			err := loyaltyService.AwardPoints(companyID, *req.CustomerID, totalAmount, saleID)
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

func (s *SalesService) validateLocationInCompany(locationID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM locations
		WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE
	`, locationID, companyID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to validate location: %w", err)
	}
	if count == 0 {
		return fmt.Errorf("location not found")
	}
	return nil
}

func (s *SalesService) getSaleByIdempotencyKey(key string, companyID, locationID int) (*models.Sale, error) {
	var saleID int
	err := s.db.QueryRow(`
		SELECT s.sale_id FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.idempotency_key = $1 AND s.location_id = $2 AND l.company_id = $3 AND s.is_deleted = FALSE
	`, key, locationID, companyID).Scan(&saleID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to lookup idempotency key: %w", err)
	}
	return s.GetSaleByID(saleID, companyID)
}

func nullIfEmpty(value string) *string {
	if value == "" {
		return nil
	}
	v := value
	return &v
}

func (s *SalesService) UpdateSale(saleID, companyID, userID int, req *models.UpdateSaleRequest) error {
	// Verify sale exists and belongs to company
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	setParts := []string{}
	args := []interface{}{}
	argCount := 0
	changes := models.JSONB{}

	if req.PaymentMethodID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("payment_method_id = $%d", argCount))
		args = append(args, *req.PaymentMethodID)
		changes["payment_method_id"] = *req.PaymentMethodID
	}
	if req.Notes != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("notes = $%d", argCount))
		args = append(args, *req.Notes)
		changes["notes"] = *req.Notes
	}
	if req.Status != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("status = $%d", argCount))
		args = append(args, *req.Status)
		changes["status"] = *req.Status
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)

	argCount++
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf(`UPDATE sales s SET %s FROM locations l WHERE s.sale_id = $%d AND s.location_id = l.location_id AND l.company_id = $%d`,
		strings.Join(setParts, ", "), argCount, argCount+1)
	args = append(args, saleID, companyID)

	result, err := tx.Exec(query, args...)
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

	if len(changes) > 0 {
		recordID := saleID
		actorID := userID
		if err := LogAudit(tx, "UPDATE", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
			return fmt.Errorf("failed to log audit: %w", err)
		}
	}

	return tx.Commit()
}

func (s *SalesService) DeleteSale(saleID, companyID, userID int) error {
	// Verify sale exists and belongs to company
	err := s.verifySaleInCompany(saleID, companyID)
	if err != nil {
		return err
	}

	// Check if sale can be deleted (not finalized, etc.)
	var status string
	err = s.db.QueryRow(`
		SELECT s.status FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get sale status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed sales cannot be deleted")
	}

	query := `UPDATE sales s SET is_deleted = TRUE, updated_by = $2, updated_at = CURRENT_TIMESTAMP
		FROM locations l WHERE s.sale_id = $1 AND s.location_id = l.location_id AND l.company_id = $3`

	result, err := s.db.Exec(query, saleID, userID, companyID)
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

	query := `UPDATE sales s SET pos_status = 'HOLD', updated_by = $2, updated_at = CURRENT_TIMESTAMP
		FROM locations l WHERE s.sale_id = $1 AND s.location_id = l.location_id AND l.company_id = $3`

	result, err := s.db.Exec(query, saleID, userID, companyID)
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

	query := `UPDATE sales s SET pos_status = 'ACTIVE', updated_by = $2, updated_at = CURRENT_TIMESTAMP
		FROM locations l WHERE s.sale_id = $1 AND s.location_id = l.location_id AND l.company_id = $3`

	result, err := s.db.Exec(query, saleID, userID, companyID)
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
	sale, err := s.CreateSale(companyID, locationID, userID, createReq, nil)
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
func (s *SalesService) getSaleItems(saleID, companyID int) ([]models.SaleDetail, error) {
	query := `
		SELECT sd.sale_detail_id, sd.sale_id, sd.product_id, sd.product_name, sd.quantity,
			   sd.unit_price, sd.discount_percentage, sd.discount_amount, sd.tax_id,
			   sd.tax_amount, sd.line_total, sd.serial_numbers, sd.notes,
			   p.name as product_name_from_table
		FROM sale_details sd
		JOIN sales s ON sd.sale_id = s.sale_id
		JOIN locations l ON s.location_id = l.location_id
		LEFT JOIN products p ON sd.product_id = p.product_id
		WHERE sd.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
		ORDER BY sd.sale_detail_id
	`

	rows, err := s.db.Query(query, saleID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale items: %w", err)
	}
	defer rows.Close()

	var items []models.SaleDetail
	for rows.Next() {
		var item models.SaleDetail
		var serialNumbers pq.StringArray
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

		// Handle serial numbers (TEXT[])
		if len(serialNumbers) > 0 {
			item.SerialNumbers = []string(serialNumbers)
		}

		// Set product name from products table if available
		if productNameFromTable.Valid {
			item.ProductName = &productNameFromTable.String
		}

		items = append(items, item)
	}

	return items, nil
}

func (s *SalesService) calculateTax(companyID int, amount float64, taxID int) (float64, error) {
	var taxPercentage float64
	err := s.db.QueryRow("SELECT percentage FROM taxes WHERE tax_id = $1 AND company_id = $2 AND is_active = TRUE", taxID, companyID).Scan(&taxPercentage)
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
	if saleNumber := filters["sale_number"]; saleNumber != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_number ILIKE '%%' || $%d || '%%'", argCount)
		args = append(args, saleNumber)
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

// GetQuotes returns quotes for a company with optional filters.
func (s *SalesService) GetQuotes(companyID int, filters map[string]string) ([]models.Quote, error) {
	query := `
		SELECT q.quote_id, q.quote_number, q.location_id, q.customer_id, q.quote_date, q.valid_until,
			   q.subtotal, q.tax_amount, q.discount_amount, q.total_amount, q.status, q.notes,
			   q.created_by, q.updated_by, q.sync_status, q.created_at, q.updated_at,
			   c.name as customer_name
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		LEFT JOIN customers c ON q.customer_id = c.customer_id
		WHERE l.company_id = $1 AND q.is_deleted = FALSE
	`

	args := []interface{}{companyID}
	argCount := 1

	if filters != nil {
		if status := filters["status"]; status != "" {
			argCount++
			query += fmt.Sprintf(" AND q.status = $%d", argCount)
			args = append(args, status)
		}
		if customerID := filters["customer_id"]; customerID != "" {
			argCount++
			query += fmt.Sprintf(" AND q.customer_id = $%d", argCount)
			args = append(args, customerID)
		}
		if dateFrom := filters["date_from"]; dateFrom != "" {
			argCount++
			query += fmt.Sprintf(" AND q.quote_date >= $%d", argCount)
			args = append(args, dateFrom)
		}
		if dateTo := filters["date_to"]; dateTo != "" {
			argCount++
			query += fmt.Sprintf(" AND q.quote_date <= $%d", argCount)
			args = append(args, dateTo)
		}
	}

	query += " ORDER BY q.quote_date DESC, q.quote_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get quotes: %w", err)
	}
	defer rows.Close()

	var quotes []models.Quote
	for rows.Next() {
		var q models.Quote
		var customerName sql.NullString
		if err := rows.Scan(
			&q.QuoteID, &q.QuoteNumber, &q.LocationID, &q.CustomerID, &q.QuoteDate, &q.ValidUntil,
			&q.Subtotal, &q.TaxAmount, &q.DiscountAmount, &q.TotalAmount, &q.Status, &q.Notes,
			&q.CreatedBy, &q.UpdatedBy, &q.SyncStatus, &q.CreatedAt, &q.UpdatedAt,
			&customerName,
		); err != nil {
			return nil, fmt.Errorf("failed to scan quote: %w", err)
		}
		if customerName.Valid && q.CustomerID != nil {
			q.Customer = &models.Customer{CustomerID: *q.CustomerID, Name: customerName.String}
		}
		quotes = append(quotes, q)
	}

	return quotes, nil
}

// GetQuoteByID returns a single quote with its items.
func (s *SalesService) GetQuoteByID(quoteID, companyID int) (*models.Quote, error) {
	query := `
		SELECT q.quote_id, q.quote_number, q.location_id, q.customer_id, q.quote_date, q.valid_until,
			   q.subtotal, q.tax_amount, q.discount_amount, q.total_amount, q.status, q.notes,
			   q.created_by, q.updated_by, q.sync_status, q.created_at, q.updated_at,
			   c.name as customer_name
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		LEFT JOIN customers c ON q.customer_id = c.customer_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`

	var quote models.Quote
	var customerName sql.NullString
	if err := s.db.QueryRow(query, quoteID, companyID).Scan(
		&quote.QuoteID, &quote.QuoteNumber, &quote.LocationID, &quote.CustomerID, &quote.QuoteDate, &quote.ValidUntil,
		&quote.Subtotal, &quote.TaxAmount, &quote.DiscountAmount, &quote.TotalAmount, &quote.Status, &quote.Notes,
		&quote.CreatedBy, &quote.UpdatedBy, &quote.SyncStatus, &quote.CreatedAt, &quote.UpdatedAt,
		&customerName,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("quote not found")
		}
		return nil, fmt.Errorf("failed to get quote: %w", err)
	}
	if customerName.Valid && quote.CustomerID != nil {
		quote.Customer = &models.Customer{CustomerID: *quote.CustomerID, Name: customerName.String}
	}

	items, err := s.getQuoteItems(quoteID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get quote items: %w", err)
	}
	quote.Items = items

	return &quote, nil
}

// CreateQuote creates a new quote with items.
func (s *SalesService) CreateQuote(companyID, locationID, userID int, req *models.CreateQuoteRequest) (*models.Quote, error) {
	if req.CustomerID != nil {
		if err := s.validateCustomerInCompany(*req.CustomerID, companyID); err != nil {
			return nil, err
		}
	}
	if err := s.validateLocationInCompany(locationID, companyID); err != nil {
		return nil, err
	}

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

	subtotal := float64(0)
	totalTax := float64(0)
	type itemCalc struct {
		item         models.CreateQuoteItemRequest
		discountAmt  float64
		taxAmt       float64
		lineTotal    float64
		effectiveTax *int
	}
	calcs := make([]itemCalc, 0, len(req.Items))

	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount

		var productTaxID *int
		if item.ProductID != nil {
			var prodTaxID sql.NullInt64
			if err := tx.QueryRow(`SELECT tax_id FROM products WHERE product_id = $1 AND company_id = $2 AND is_deleted = FALSE`, *item.ProductID, companyID).Scan(&prodTaxID); err != nil {
				if err == sql.ErrNoRows {
					return nil, fmt.Errorf("product not found")
				}
				return nil, fmt.Errorf("failed to resolve product tax: %w", err)
			}
			if prodTaxID.Valid && prodTaxID.Int64 > 0 {
				id := int(prodTaxID.Int64)
				productTaxID = &id
			}
		}

		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if productTaxID != nil {
			effectiveTaxID = productTaxID
		}

		var taxAmount float64
		if effectiveTaxID != nil {
			taxAmount, err = s.calculateTax(companyID, lineTotal, *effectiveTaxID)
			if err != nil {
				return nil, fmt.Errorf("failed to calculate tax: %w", err)
			}
		}

		subtotal += lineTotal
		totalTax += taxAmount
		calcs = append(calcs, itemCalc{
			item:         item,
			discountAmt:  discountAmount,
			taxAmt:       taxAmount,
			lineTotal:    lineTotal,
			effectiveTax: effectiveTaxID,
		})
	}

	totalAmount := subtotal + totalTax - req.DiscountAmount
	if totalAmount < 0 {
		totalAmount = 0
	}

	var quoteID int
	validUntil := req.ValidUntil.Time
	var validUntilPtr *time.Time
	if !validUntil.IsZero() {
		validUntilPtr = &validUntil
	}
	err = tx.QueryRow(`
		INSERT INTO quotes (quote_number, location_id, customer_id, quote_date, valid_until,
							subtotal, tax_amount, discount_amount, total_amount, status, notes, created_by, updated_by)
		VALUES ($1, $2, $3, CURRENT_DATE, $4, $5, $6, $7, $8, 'DRAFT', $9, $10, $10)
		RETURNING quote_id
	`, quoteNumber, locationID, req.CustomerID, validUntilPtr, subtotal, totalTax, req.DiscountAmount, totalAmount, req.Notes, userID).Scan(&quoteID)
	if err != nil {
		return nil, fmt.Errorf("failed to insert quote: %w", err)
	}

	for _, calc := range calcs {
		_, err = tx.Exec(`
			INSERT INTO quote_items (quote_id, product_id, product_name, quantity, unit_price,
									discount_percentage, discount_amount, tax_id, tax_amount,
									line_total, serial_numbers, notes)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		`, quoteID, calc.item.ProductID, calc.item.ProductName, calc.item.Quantity, calc.item.UnitPrice,
			calc.item.DiscountPercent, calc.discountAmt, calc.effectiveTax, calc.taxAmt,
			calc.lineTotal, pq.Array(calc.item.SerialNumbers), calc.item.Notes)
		if err != nil {
			return nil, fmt.Errorf("failed to insert quote item: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit quote: %w", err)
	}

	return s.GetQuoteByID(quoteID, companyID)
}

// UpdateQuote updates an existing quote, including items if provided.
func (s *SalesService) UpdateQuote(quoteID, companyID, userID int, req *models.UpdateQuoteRequest) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var existingDiscount float64
	err = tx.QueryRow(`
		SELECT q.discount_amount
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&existingDiscount)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("quote not found")
		}
		return fmt.Errorf("failed to load quote: %w", err)
	}

	discountAmount := existingDiscount
	if req.DiscountAmount != nil {
		discountAmount = *req.DiscountAmount
	}

	subtotal := float64(0)
	totalTax := float64(0)
	recalcTotals := false

	if req.Items != nil {
		if len(req.Items) == 0 {
			return fmt.Errorf("items are required")
		}
		recalcTotals = true

		_, err := tx.Exec(`
			DELETE FROM quote_items qi
			USING quotes q
			JOIN locations l ON q.location_id = l.location_id
			WHERE qi.quote_id = q.quote_id AND q.quote_id = $1 AND l.company_id = $2
		`, quoteID, companyID)
		if err != nil {
			return fmt.Errorf("failed to clear quote items: %w", err)
		}

		for _, item := range req.Items {
			lineTotal := item.Quantity * item.UnitPrice
			discountAmt := lineTotal * (item.DiscountPercent / 100)
			lineTotal -= discountAmt

			var productTaxID *int
			if item.ProductID != nil {
				var prodTaxID sql.NullInt64
				if err := tx.QueryRow(`SELECT tax_id FROM products WHERE product_id = $1 AND company_id = $2 AND is_deleted = FALSE`, *item.ProductID, companyID).Scan(&prodTaxID); err != nil {
					if err == sql.ErrNoRows {
						return fmt.Errorf("product not found")
					}
					return fmt.Errorf("failed to resolve product tax: %w", err)
				}
				if prodTaxID.Valid && prodTaxID.Int64 > 0 {
					id := int(prodTaxID.Int64)
					productTaxID = &id
				}
			}

			var effectiveTaxID *int
			if item.TaxID != nil {
				effectiveTaxID = item.TaxID
			} else if productTaxID != nil {
				effectiveTaxID = productTaxID
			}

			var taxAmount float64
			if effectiveTaxID != nil {
				taxAmount, err = s.calculateTax(companyID, lineTotal, *effectiveTaxID)
				if err != nil {
					return fmt.Errorf("failed to calculate tax: %w", err)
				}
			}

			subtotal += lineTotal
			totalTax += taxAmount

			_, err = tx.Exec(`
				INSERT INTO quote_items (quote_id, product_id, product_name, quantity, unit_price,
										discount_percentage, discount_amount, tax_id, tax_amount,
										line_total, serial_numbers, notes)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
			`, quoteID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice,
				item.DiscountPercent, discountAmt, effectiveTaxID, taxAmount,
				lineTotal, pq.Array(item.SerialNumbers), item.Notes)
			if err != nil {
				return fmt.Errorf("failed to insert quote item: %w", err)
			}
		}
	} else if req.DiscountAmount != nil {
		recalcTotals = true
		if err := tx.QueryRow(`
			SELECT COALESCE(SUM(qi.line_total), 0), COALESCE(SUM(qi.tax_amount), 0)
			FROM quote_items qi
			JOIN quotes q ON qi.quote_id = q.quote_id
			JOIN locations l ON q.location_id = l.location_id
			WHERE qi.quote_id = $1 AND l.company_id = $2
		`, quoteID, companyID).Scan(&subtotal, &totalTax); err != nil {
			return fmt.Errorf("failed to recalc totals: %w", err)
		}
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Status != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("status = $%d", argCount))
		args = append(args, *req.Status)
	}
	if req.Notes != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("notes = $%d", argCount))
		args = append(args, *req.Notes)
	}
	if req.ValidUntil != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("valid_until = $%d", argCount))
		args = append(args, req.ValidUntil.Time)
	}
	if recalcTotals {
		totalAmount := subtotal + totalTax - discountAmount
		if totalAmount < 0 {
			totalAmount = 0
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("subtotal = $%d", argCount))
		args = append(args, subtotal)
		argCount++
		setParts = append(setParts, fmt.Sprintf("tax_amount = $%d", argCount))
		args = append(args, totalTax)
		argCount++
		setParts = append(setParts, fmt.Sprintf("discount_amount = $%d", argCount))
		args = append(args, discountAmount)
		argCount++
		setParts = append(setParts, fmt.Sprintf("total_amount = $%d", argCount))
		args = append(args, totalAmount)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)

	argCount++
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf(`UPDATE quotes q SET %s FROM locations l WHERE q.quote_id = $%d AND q.location_id = l.location_id AND l.company_id = $%d`,
		strings.Join(setParts, ", "), argCount, argCount+1)
	args = append(args, quoteID, companyID)

	res, err := tx.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update quote: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if affected == 0 {
		return fmt.Errorf("quote not found")
	}

	return tx.Commit()
}

// DeleteQuote deletes a quote.
func (s *SalesService) DeleteQuote(quoteID, companyID int) error {
	res, err := s.db.Exec(`
		UPDATE quotes q SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP
		FROM locations l WHERE q.quote_id = $1 AND q.location_id = l.location_id AND l.company_id = $2
	`, quoteID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete quote: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if affected == 0 {
		return fmt.Errorf("quote not found")
	}
	return nil
}

// PrintQuote marks a quote as sent and validates ownership.
func (s *SalesService) PrintQuote(quoteID, companyID int) error {
	_, err := s.db.Exec(`
		UPDATE quotes q SET status = CASE WHEN status = 'DRAFT' THEN 'SENT' ELSE status END, updated_at = CURRENT_TIMESTAMP
		FROM locations l WHERE q.quote_id = $1 AND q.location_id = l.location_id AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID)
	if err != nil {
		return fmt.Errorf("failed to update quote status: %w", err)
	}
	return nil
}

// ShareQuote marks a quote as sent and logs the share request.
func (s *SalesService) ShareQuote(quoteID, companyID int, req *models.ShareQuoteRequest) error {
	if err := s.PrintQuote(quoteID, companyID); err != nil {
		return err
	}
	fmt.Printf("Share requested for quote ID: %d with %s\n", quoteID, req.Email)
	return nil
}

func (s *SalesService) getQuoteItems(quoteID, companyID int) ([]models.QuoteItem, error) {
	query := `
		SELECT qi.quote_item_id, qi.quote_id, qi.product_id, qi.product_name, qi.quantity,
			   qi.unit_price, qi.discount_percentage, qi.discount_amount, qi.tax_id, qi.tax_amount,
			   qi.line_total, qi.serial_numbers, qi.notes, p.name as product_name_from_table
		FROM quote_items qi
		JOIN quotes q ON qi.quote_id = q.quote_id
		JOIN locations l ON q.location_id = l.location_id
		LEFT JOIN products p ON qi.product_id = p.product_id
		WHERE qi.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
		ORDER BY qi.quote_item_id
	`

	rows, err := s.db.Query(query, quoteID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get quote items: %w", err)
	}
	defer rows.Close()

	var items []models.QuoteItem
	for rows.Next() {
		var item models.QuoteItem
		var serialNumbers pq.StringArray
		var productName sql.NullString
		if err := rows.Scan(
			&item.QuoteItemID, &item.QuoteID, &item.ProductID, &item.ProductName, &item.Quantity,
			&item.UnitPrice, &item.DiscountPercent, &item.DiscountAmount, &item.TaxID, &item.TaxAmount,
			&item.LineTotal, &serialNumbers, &item.Notes, &productName,
		); err != nil {
			return nil, fmt.Errorf("failed to scan quote item: %w", err)
		}
		if len(serialNumbers) > 0 {
			item.SerialNumbers = []string(serialNumbers)
		}
		if productName.Valid {
			item.ProductName = &productName.String
		}
		items = append(items, item)
	}
	return items, nil
}

// ExportQuotes returns quotes that match provided filters.
func (s *SalesService) ExportQuotes(companyID int, filters map[string]string) ([]models.Quote, error) {
	return s.GetQuotes(companyID, filters)
}
