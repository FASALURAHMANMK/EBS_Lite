package services

import (
    "database/sql"
    "fmt"
    "log"

    "github.com/lib/pq"

    "erp-backend/internal/database"
    "erp-backend/internal/models"
)

type POSService struct {
	db           *sql.DB
	salesService *SalesService
	printService *PrintService
}

func NewPOSService() *POSService {
	return &POSService{
		db:           database.GetDB(),
		salesService: NewSalesService(),
		printService: NewPrintService(),
	}
}

func (s *POSService) GetPOSProducts(companyID, locationID int) ([]models.POSProductResponse, error) {
	query := `
                SELECT p.product_id, p.name,
                           COALESCE(pb.selling_price, p.selling_price, 0) as price,
                           COALESCE(st.quantity, 0) as stock,
                           pb.barcode,
                           c.name as category_name
                FROM products p
                LEFT JOIN product_barcodes pb ON p.product_id = pb.product_id AND pb.is_primary = TRUE
                LEFT JOIN stock st ON p.product_id = st.product_id AND st.location_id = $2
                LEFT JOIN categories c ON p.category_id = c.category_id
                WHERE p.company_id = $1 AND p.is_active = TRUE AND p.is_deleted = FALSE
                ORDER BY p.name
        `

	rows, err := s.db.Query(query, companyID, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get POS products: %w", err)
	}
	defer rows.Close()

	var products []models.POSProductResponse
	for rows.Next() {
		var product models.POSProductResponse
		err := rows.Scan(
			&product.ProductID, &product.Name, &product.Price, &product.Stock,
			&product.Barcode, &product.CategoryName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan POS product: %w", err)
		}
		products = append(products, product)
	}

	return products, nil
}

func (s *POSService) GetPOSCustomers(companyID int) ([]models.POSCustomerResponse, error) {
	query := `
		SELECT customer_id, name, phone, email
		FROM customers
		WHERE company_id = $1 AND is_active = TRUE AND is_deleted = FALSE
		ORDER BY name
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get POS customers: %w", err)
	}
	defer rows.Close()

	var customers []models.POSCustomerResponse
	for rows.Next() {
		var customer models.POSCustomerResponse
		err := rows.Scan(
			&customer.CustomerID, &customer.Name, &customer.Phone, &customer.Email,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan POS customer: %w", err)
		}
		customers = append(customers, customer)
	}

	return customers, nil
}

func (s *POSService) ProcessCheckout(companyID, locationID, userID int, req *models.POSCheckoutRequest) (*models.Sale, error) {
    // Validate stock availability for all items
    for _, item := range req.Items {
        if item.ProductID != nil {
            available, err := s.checkStockAvailability(locationID, *item.ProductID, item.Quantity)
            if err != nil {
                return nil, fmt.Errorf("failed to check stock for product %d: %w", *item.ProductID, err)
            }
            if !available {
                return nil, fmt.Errorf("insufficient stock for product %d", *item.ProductID)
            }
        }
    }

    if req.SaleID != nil {
        // Finalize an existing held sale and keep its sale_number
        sale, err := s.finalizeHeldSale(companyID, locationID, userID, *req.SaleID, req)
        if err != nil {
            return nil, fmt.Errorf("failed to finalize held sale: %w", err)
        }
        return sale, nil
    }

    // Normal flow: create a fresh sale
    saleReq := &models.CreateSaleRequest{
        CustomerID:      req.CustomerID,
        Items:           req.Items,
        PaymentMethodID: req.PaymentMethodID,
        DiscountAmount:  req.DiscountAmount,
        PaidAmount:      req.PaidAmount,
    }

    sale, err := s.salesService.CreateSale(companyID, locationID, userID, saleReq)
    if err != nil {
        return nil, fmt.Errorf("failed to process checkout: %w", err)
    }

    // Record payment breakdown if provided
    if len(req.Payments) > 0 {
        if err := s.recordSalePayments(nil, sale.SaleID, req.Payments); err != nil {
            log.Printf("warning: failed to record sale payments for sale %d: %v", sale.SaleID, err)
        }
    }

    return sale, nil
}

func (s *POSService) PrintInvoice(invoiceID, companyID int) error {
	// Verify invoice exists and belongs to company
	err := s.salesService.verifySaleInCompany(invoiceID, companyID)
	if err != nil {
		return fmt.Errorf("invoice not found")
	}

	if err := s.printService.PrintReceipt("invoice", invoiceID, companyID); err != nil {
		log.Printf("failed to print invoice %d: %v", invoiceID, err)
		return fmt.Errorf("failed to print invoice: %w", err)
	}

	log.Printf("invoice %d printed successfully", invoiceID)
	return nil
}

func (s *POSService) GetHeldSales(companyID, locationID int) ([]models.Sale, error) {
    filters := map[string]string{
        "pos_status": "HOLD",
        "status":     "DRAFT",
    }

    return s.salesService.GetSales(companyID, locationID, filters)
}

func (s *POSService) SearchProducts(companyID, locationID int, searchTerm string) ([]models.POSProductResponse, error) {
    // Enrich POS search to match:
    // - name (ILIKE)
    // - sku (ILIKE)
    // - barcode (exact OR LIKE)
    // - category name (ILIKE)
    // - attribute values (ILIKE)
    query := `
                SELECT p.product_id, p.name,
                           COALESCE(pb.selling_price, p.selling_price, 0) as price,
                           COALESCE(st.quantity, 0) as stock,
                           pb.barcode,
                           c.name as category_name
                FROM products p
                LEFT JOIN product_barcodes pb ON p.product_id = pb.product_id AND pb.is_primary = TRUE
                LEFT JOIN stock st ON p.product_id = st.product_id AND st.location_id = $2
                LEFT JOIN categories c ON p.category_id = c.category_id
                WHERE p.company_id = $1 AND p.is_active = TRUE AND p.is_deleted = FALSE
                AND (
                        LOWER(p.name) LIKE LOWER($3) OR
                        LOWER(p.sku) LIKE LOWER($3) OR
                        EXISTS (
                            SELECT 1 FROM product_barcodes pb2 
                            WHERE pb2.product_id = p.product_id 
                              AND (pb2.barcode = $4 OR pb2.barcode ILIKE $3)
                        ) OR
                        (c.name IS NOT NULL AND LOWER(c.name) LIKE LOWER($3)) OR
                        EXISTS (
                            SELECT 1 FROM product_attribute_values pav 
                            WHERE pav.product_id = p.product_id 
                              AND LOWER(pav.value) LIKE LOWER($3)
                        )
                )
                ORDER BY p.name
                LIMIT 50
        `

    searchPattern := "%" + searchTerm + "%"

    rows, err := s.db.Query(query, companyID, locationID, searchPattern, searchTerm)
	if err != nil {
		return nil, fmt.Errorf("failed to search products: %w", err)
	}
	defer rows.Close()

	var products []models.POSProductResponse
	for rows.Next() {
		var product models.POSProductResponse
		err := rows.Scan(
			&product.ProductID, &product.Name, &product.Price, &product.Stock,
			&product.Barcode, &product.CategoryName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan search result: %w", err)
		}
		products = append(products, product)
	}

	return products, nil
}

func (s *POSService) SearchCustomers(companyID int, searchTerm string) ([]models.POSCustomerResponse, error) {
	query := `
		SELECT customer_id, name, phone, email
		FROM customers
		WHERE company_id = $1 AND is_active = TRUE AND is_deleted = FALSE
		AND (
			LOWER(name) LIKE LOWER($2) OR 
			phone LIKE $3 OR 
			LOWER(email) LIKE LOWER($2)
		)
		ORDER BY name
		LIMIT 20
	`

	searchPattern := "%" + searchTerm + "%"

	rows, err := s.db.Query(query, companyID, searchPattern, searchTerm)
	if err != nil {
		return nil, fmt.Errorf("failed to search customers: %w", err)
	}
	defer rows.Close()

	var customers []models.POSCustomerResponse
	for rows.Next() {
		var customer models.POSCustomerResponse
		err := rows.Scan(
			&customer.CustomerID, &customer.Name, &customer.Phone, &customer.Email,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan customer search result: %w", err)
		}
		customers = append(customers, customer)
	}

	return customers, nil
}

func (s *POSService) GetPaymentMethods(companyID int) ([]models.PaymentMethod, error) {
	query := `
		SELECT method_id, company_id, name, type, external_integration, is_active
		FROM payment_methods
		WHERE (company_id = $1 OR company_id IS NULL) AND is_active = TRUE
		ORDER BY name
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get payment methods: %w", err)
	}
	defer rows.Close()

	var methods []models.PaymentMethod
	for rows.Next() {
		var method models.PaymentMethod
		err := rows.Scan(
			&method.MethodID, &method.CompanyID, &method.Name, &method.Type,
			&method.ExternalIntegration, &method.IsActive,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan payment method: %w", err)
		}
		methods = append(methods, method)
	}

	return methods, nil
}

func (s *POSService) GetSalesSummary(companyID, locationID int, dateFrom, dateTo string) (*models.SalesSummaryResponse, error) {
	query := `
                SELECT
                        COALESCE(SUM(total_amount), 0) as total_sales,
                       COUNT(*) as total_transactions,
                       COALESCE(AVG(total_amount), 0) as average_ticket,
                       COALESCE(SUM(total_amount - paid_amount), 0) as outstanding_amount
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                WHERE l.company_id = $1 AND s.location_id = $2 AND s.is_deleted = FALSE
                AND s.status = 'COMPLETED'
        `

	args := []interface{}{companyID, locationID}
	argCount := 2

	if dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND s.sale_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	var summary models.SalesSummaryResponse
	err := s.db.QueryRow(query, args...).Scan(
		&summary.TotalSales, &summary.TotalTransactions, &summary.AverageTicket, &summary.OutstandingAmount,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get sales summary: %w", err)
	}

	// Get top products
	topProductsQuery := `
		SELECT p.product_id, p.name, SUM(sd.quantity) as quantity, SUM(sd.line_total) as revenue
		FROM sale_details sd
		JOIN sales s ON sd.sale_id = s.sale_id
		JOIN products p ON sd.product_id = p.product_id
		JOIN locations l ON s.location_id = l.location_id
		WHERE l.company_id = $1 AND s.location_id = $2 AND s.is_deleted = FALSE
		AND s.status = 'COMPLETED' AND sd.product_id IS NOT NULL
	`

	topArgs := []interface{}{companyID, locationID}
	topArgCount := 2

	if dateFrom != "" {
		topArgCount++
		topProductsQuery += fmt.Sprintf(" AND s.sale_date >= $%d", topArgCount)
		topArgs = append(topArgs, dateFrom)
	}

	if dateTo != "" {
		topArgCount++
		topProductsQuery += fmt.Sprintf(" AND s.sale_date <= $%d", topArgCount)
		topArgs = append(topArgs, dateTo)
	}

	topProductsQuery += " GROUP BY p.product_id, p.name ORDER BY revenue DESC LIMIT 5"

	rows, err := s.db.Query(topProductsQuery, topArgs...)
	if err != nil {
		return nil, fmt.Errorf("failed to get top products: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var topProduct struct {
			ProductID   int     `json:"product_id"`
			ProductName string  `json:"product_name"`
			Quantity    float64 `json:"quantity"`
			Revenue     float64 `json:"revenue"`
		}
		err := rows.Scan(&topProduct.ProductID, &topProduct.ProductName, &topProduct.Quantity, &topProduct.Revenue)
		if err != nil {
			return nil, fmt.Errorf("failed to scan top product: %w", err)
		}
		summary.TopProducts = append(summary.TopProducts, topProduct)
	}

	return &summary, nil
}

// Helper methods
func (s *POSService) checkStockAvailability(locationID, productID int, requiredQuantity float64) (bool, error) {
	var availableStock float64
	err := s.db.QueryRow(`
		SELECT COALESCE(quantity, 0) FROM stock 
		WHERE location_id = $1 AND product_id = $2
	`, locationID, productID).Scan(&availableStock)

	if err != nil && err != sql.ErrNoRows {
		return false, err
	}

	return availableStock >= requiredQuantity, nil
}

// finalizeHeldSale replaces the details of an existing DRAFT sale, updates totals
// and stock, and marks it as COMPLETED while preserving sale_number.
func (s *POSService) finalizeHeldSale(companyID, locationID, userID, saleID int, req *models.POSCheckoutRequest) (*models.Sale, error) {
    // Verify sale exists, belongs to company & location, and is DRAFT
    var status, posStatus string
    var existingLocationID int
    err := s.db.QueryRow(`SELECT s.status, s.pos_status, s.location_id FROM sales s JOIN locations l ON s.location_id = l.location_id WHERE s.sale_id=$1 AND l.company_id=$2 AND s.is_deleted=FALSE`, saleID, companyID).Scan(&status, &posStatus, &existingLocationID)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("sale not found")
        }
        return nil, fmt.Errorf("failed to verify sale: %w", err)
    }
    if existingLocationID != locationID {
        return nil, fmt.Errorf("invalid location for sale")
    }
    if status != "DRAFT" {
        return nil, fmt.Errorf("sale already finalized")
    }

    tx, err := s.db.Begin()
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()

    // Recalculate totals (reusing SalesService for tax resolution)
    saleReq := &models.CreateSaleRequest{
        CustomerID:      req.CustomerID,
        Items:           req.Items,
        PaymentMethodID: req.PaymentMethodID,
        DiscountAmount:  req.DiscountAmount,
        PaidAmount:      req.PaidAmount,
    }
    subtotal, tax, total, err := s.salesService.CalculateTotals(saleReq)
    if err != nil {
        return nil, fmt.Errorf("failed to calculate totals: %w", err)
    }
    if req.PaidAmount < 0 || req.PaidAmount > total {
        // Clamp or return error; follow same validation as CreateSale
        return nil, fmt.Errorf("invalid paid amount")
    }

    // Replace sale details
    if _, err := tx.Exec(`DELETE FROM sale_details WHERE sale_id=$1`, saleID); err != nil {
        return nil, fmt.Errorf("failed to clear sale details: %w", err)
    }

    // Insert details and update stock
    for _, item := range req.Items {
        // Compute line
        lineTotal := item.Quantity * item.UnitPrice
        discountAmount := lineTotal * (item.DiscountPercent / 100)
        lineTotal -= discountAmount
        var taxAmount float64
        var effectiveTaxID *int
        if item.TaxID != nil {
            effectiveTaxID = item.TaxID
        } else if item.ProductID != nil {
            var prodTaxID int
            q := `SELECT tax_id FROM products WHERE product_id=$1 AND is_deleted=FALSE`
            if err := s.db.QueryRow(q, *item.ProductID).Scan(&prodTaxID); err == nil && prodTaxID > 0 {
                effectiveTaxID = &prodTaxID
            }
        }
        if effectiveTaxID != nil {
            taxAmount, err = s.salesService.calculateTax(lineTotal, *effectiveTaxID)
            if err != nil {
                return nil, fmt.Errorf("failed to calculate tax: %w", err)
            }
        }

        if _, err := tx.Exec(`
            INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
                                      discount_percentage, discount_amount, tax_id, tax_amount,
                                      line_total, serial_numbers, notes)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
        `, saleID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice, item.DiscountPercent, discountAmount, effectiveTaxID, taxAmount, lineTotal, pq.Array(item.SerialNumbers), item.Notes); err != nil {
            return nil, fmt.Errorf("failed to insert sale detail: %w", err)
        }

        if item.ProductID != nil {
            if err := s.salesService.updateStock(tx, locationID, *item.ProductID, -item.Quantity); err != nil {
                return nil, fmt.Errorf("failed to update stock: %w", err)
            }
        }
    }

    // Update sale header to completed
    if _, err := tx.Exec(`
        UPDATE sales SET customer_id=$1, subtotal=$2, tax_amount=$3, discount_amount=$4, total_amount=$5,
                          paid_amount=$6, payment_method_id=$7, status='COMPLETED', pos_status='COMPLETED',
                          is_quick_sale=FALSE, updated_by=$8, updated_at=CURRENT_TIMESTAMP
        WHERE sale_id=$9
    `, req.CustomerID, subtotal, tax, req.DiscountAmount, total, req.PaidAmount, req.PaymentMethodID, userID, saleID); err != nil {
        return nil, fmt.Errorf("failed to update sale: %w", err)
    }

    // Record payments (if any)
    if len(req.Payments) > 0 {
        if err := s.recordSalePaymentsTx(tx, saleID, req.Payments); err != nil {
            return nil, fmt.Errorf("failed to record payments: %w", err)
        }
    }

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit finalize: %w", err)
    }

    return s.salesService.GetSaleByID(saleID, companyID)
}

func (s *POSService) recordSalePayments(tx *sql.Tx, saleID int, lines []models.POSPaymentLine) error {
    // Use separate transaction if none provided
    if tx == nil {
        var err error
        tx, err = s.db.Begin()
        if err != nil {
            return err
        }
        defer func() {
            _ = tx.Commit()
        }()
    }
    return s.recordSalePaymentsTx(tx, saleID, lines)
}

func (s *POSService) recordSalePaymentsTx(tx *sql.Tx, saleID int, lines []models.POSPaymentLine) error {
    for _, p := range lines {
        var rate float64
        // Resolve exchange rate: method-specific overrides else currency rate else 1
        if p.CurrencyID != nil {
            err := tx.QueryRow(`
                SELECT COALESCE(pmc.exchange_rate, c.exchange_rate, 1.0)
                FROM currencies c
                LEFT JOIN payment_method_currencies pmc ON pmc.currency_id = c.currency_id AND pmc.method_id = $1
                WHERE c.currency_id = $2
            `, p.MethodID, *p.CurrencyID).Scan(&rate)
            if err != nil {
                if err == sql.ErrNoRows {
                    rate = 1.0
                } else {
                    return fmt.Errorf("failed to resolve exchange rate: %w", err)
                }
            }
        } else {
            rate = 1.0
        }
        base := p.Amount * rate
        if _, err := tx.Exec(`
            INSERT INTO sale_payments (sale_id, method_id, currency_id, amount, base_amount, exchange_rate)
            VALUES ($1,$2,$3,$4,$5,$6)
        `, saleID, p.MethodID, p.CurrencyID, p.Amount, base, rate); err != nil {
            return fmt.Errorf("failed to insert sale payment: %w", err)
        }
    }
    return nil
}

// VoidSale creates a new VOID invoice for a prior sale, consuming a new sale
// number. If the original sale was COMPLETED, this contains negative item
// lines to reverse stock and amounts. If original was DRAFT/HELD, a zero-total
// void invoice is created to record the event and advance numbering.
func (s *POSService) VoidSale(companyID, locationID, userID, originalSaleID int) (*models.Sale, error) {
    // Load original sale header and items
    var status string
    var origLocationID int
    var subtotal, tax, discount, total float64
    err := s.db.QueryRow(`
        SELECT s.status, s.location_id, s.subtotal, s.tax_amount, s.discount_amount, s.total_amount
        FROM sales s
        JOIN locations l ON s.location_id = l.location_id
        WHERE s.sale_id=$1 AND l.company_id=$2 AND s.is_deleted=FALSE
    `, originalSaleID, companyID).Scan(&status, &origLocationID, &subtotal, &tax, &discount, &total)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("sale not found")
        }
        return nil, fmt.Errorf("failed to get sale: %w", err)
    }
    if origLocationID != locationID {
        return nil, fmt.Errorf("invalid location for sale")
    }

    tx, err := s.db.Begin()
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()

    // Generate new sale number
    ns := NewNumberingSequenceService()
    voidNumber, err := ns.NextNumber(tx, "sale", companyID, &locationID)
    if err != nil {
        return nil, fmt.Errorf("failed to generate sale number: %w", err)
    }

    // Insert void sale header with negative totals if original completed
    var vSubtotal, vTax, vDiscount, vTotal float64
    if status == "COMPLETED" {
        vSubtotal = -subtotal
        vTax = -tax
        vDiscount = -discount
        vTotal = -total
    } else {
        vSubtotal, vTax, vDiscount, vTotal = 0, 0, 0, 0
    }

    var voidSaleID int
    if err := tx.QueryRow(`
        INSERT INTO sales (sale_number, location_id, customer_id, sale_date, sale_time,
                           subtotal, tax_amount, discount_amount, total_amount, paid_amount,
                           payment_method_id, status, pos_status, is_quick_sale, notes, created_by, updated_by)
        SELECT $1, s.location_id, s.customer_id, CURRENT_DATE, CURRENT_TIME,
               $2, $3, $4, $5, 0, NULL, 'VOID','COMPLETED', FALSE, 'Void of sale ' || s.sale_number, $6, $6
        FROM sales s WHERE s.sale_id=$7
        RETURNING sale_id
    `, voidNumber, vSubtotal, vTax, vDiscount, vTotal, userID, originalSaleID).Scan(&voidSaleID); err != nil {
        return nil, fmt.Errorf("failed to create void sale: %w", err)
    }

    if status == "COMPLETED" {
        // Copy items as negatives and adjust stock back
        rows, err := tx.Query(`
            SELECT product_id, product_name, quantity, unit_price, discount_percentage, discount_amount, tax_id, tax_amount, line_total, serial_numbers, notes
            FROM sale_details WHERE sale_id=$1
        `, originalSaleID)
        if err != nil {
            return nil, fmt.Errorf("failed to read original items: %w", err)
        }
        defer rows.Close()
        for rows.Next() {
            var productID *int
            var productName *string
            var quantity, unitPrice, discPct, discAmt, taxAmt, lineTotal float64
            var taxID *int
            var serials []string
            var notes *string
            if err := rows.Scan(&productID, &productName, &quantity, &unitPrice, &discPct, &discAmt, &taxID, &taxAmt, &lineTotal, pq.Array(&serials), &notes); err != nil {
                return nil, fmt.Errorf("failed to scan original item: %w", err)
            }
            nQty := -quantity
            nDiscAmt := -discAmt
            nTaxAmt := -taxAmt
            nLineTotal := -lineTotal
            if _, err := tx.Exec(`
                INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
                                          discount_percentage, discount_amount, tax_id, tax_amount,
                                          line_total, serial_numbers, notes)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
            `, voidSaleID, productID, productName, nQty, unitPrice, discPct, nDiscAmt, taxID, nTaxAmt, nLineTotal, pq.Array(serials), notes); err != nil {
                return nil, fmt.Errorf("failed to insert void item: %w", err)
            }
            if productID != nil {
                // For sale, stock change was -quantity; for void we add back +quantity
                if err := s.salesService.updateStock(tx, locationID, *productID, quantity); err != nil { // add back
                    return nil, fmt.Errorf("failed to revert stock: %w", err)
                }
            }
        }
    }

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit void: %w", err)
    }

    return s.salesService.GetSaleByID(voidSaleID, companyID)
}

// CreateHeldSale creates a sale with status=DRAFT and pos_status=HOLD without updating stock.
// It calculates totals similarly to a normal sale but does not decrement inventory
// or require payment method. This allows resuming later.
func (s *POSService) CreateHeldSale(companyID, locationID, userID int, req *models.POSCheckoutRequest) (*models.Sale, error) {
    if len(req.Items) == 0 {
        return nil, fmt.Errorf("at least one item is required")
    }

    // Start transaction
    tx, err := s.db.Begin()
    if err != nil {
        return nil, fmt.Errorf("failed to start transaction: %w", err)
    }
    defer tx.Rollback()

    // Generate sale number using numbering sequences
    ns := NewNumberingSequenceService()
    saleNumber, err := ns.NextNumber(tx, "sale", companyID, &locationID)
    if err != nil {
        return nil, fmt.Errorf("failed to generate sale number: %w", err)
    }

    // Calculate totals and per-line taxes
    subtotal := float64(0)
    totalTax := float64(0)

    // We'll also compute discount per line for persistence
    type lineComputed struct {
        qty      float64
        unit     float64
        discPct  float64
        discAmt  float64
        taxID    *int
        taxAmt   float64
        total    float64
        pid      *int
        pname    *string
        serials  []string
        notes    *string
    }
    lines := make([]lineComputed, 0, len(req.Items))

    for _, item := range req.Items {
        lineTotal := item.Quantity * item.UnitPrice
        discountAmount := lineTotal * (item.DiscountPercent / 100)
        lineTotal -= discountAmount
        var taxAmount float64
        var effectiveTaxID *int
        if item.TaxID != nil {
            effectiveTaxID = item.TaxID
        } else if item.ProductID != nil {
            var prodTaxID int
            if err := s.db.QueryRow(`SELECT tax_id FROM products WHERE product_id=$1 AND is_deleted=FALSE`, *item.ProductID).Scan(&prodTaxID); err == nil && prodTaxID > 0 {
                effectiveTaxID = &prodTaxID
            }
        }
        if effectiveTaxID != nil {
            taxAmount, err = NewSalesService().calculateTax(lineTotal, *effectiveTaxID)
            if err != nil {
                return nil, fmt.Errorf("failed to calculate tax: %w", err)
            }
        }
        subtotal += lineTotal
        totalTax += taxAmount
        lines = append(lines, lineComputed{
            qty:     item.Quantity,
            unit:    item.UnitPrice,
            discPct: item.DiscountPercent,
            discAmt: discountAmount,
            taxID:   effectiveTaxID,
            taxAmt:  taxAmount,
            total:   lineTotal,
            pid:     item.ProductID,
            pname:   item.ProductName,
            serials: item.SerialNumbers,
            notes:   item.Notes,
        })
    }

    totalAmount := subtotal + totalTax - req.DiscountAmount
    if totalAmount < 0 {
        totalAmount = 0
    }

    // Insert sale as DRAFT + HOLD with zero paid
    var saleID int
    err = tx.QueryRow(`
        INSERT INTO sales (sale_number, location_id, customer_id, sale_date, sale_time,
                           subtotal, tax_amount, discount_amount, total_amount, paid_amount,
                           payment_method_id, status, pos_status, is_quick_sale, notes, created_by, updated_by)
        VALUES ($1,$2,$3,CURRENT_DATE,CURRENT_TIME,$4,$5,$6,$7,$8,$9,'DRAFT','HOLD',FALSE,$10,$11,$11)
        RETURNING sale_id
    `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount, totalAmount, 0.0, nil, nil, userID).Scan(&saleID)
    if err != nil {
        return nil, fmt.Errorf("failed to create held sale: %w", err)
    }

    // Insert sale details (no stock updates)
    for _, lc := range lines {
        if _, err := tx.Exec(`
            INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
                                      discount_percentage, discount_amount, tax_id, tax_amount,
                                      line_total, serial_numbers, notes)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
        `, saleID, lc.pid, lc.pname, lc.qty, lc.unit, lc.discPct, lc.discAmt, lc.taxID, lc.taxAmt, lc.total, pq.Array(lc.serials), lc.notes); err != nil {
            return nil, fmt.Errorf("failed to create held sale item: %w", err)
        }
    }

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit held sale: %w", err)
    }

    return s.salesService.GetSaleByID(saleID, companyID)
}
