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

	// Convert POS request to sale request
	saleReq := &models.CreateSaleRequest{
		CustomerID:      req.CustomerID,
		Items:           req.Items,
		PaymentMethodID: req.PaymentMethodID,
		DiscountAmount:  req.DiscountAmount,
		PaidAmount:      req.PaidAmount,
	}

	// Create the sale
	sale, err := s.salesService.CreateSale(companyID, locationID, userID, saleReq)
	if err != nil {
		return nil, fmt.Errorf("failed to process checkout: %w", err)
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
