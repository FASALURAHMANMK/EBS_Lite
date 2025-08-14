package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type POSService struct {
	db           *sql.DB
	salesService *SalesService
}

func NewPOSService() *POSService {
	return &POSService{
		db:           database.GetDB(),
		salesService: NewSalesService(),
	}
}

func (s *POSService) GetPOSProducts(companyID, locationID int) ([]models.POSProductResponse, error) {
	query := `
		SELECT p.product_id, p.name, 
			   COALESCE(p.selling_price, 0) as price,
			   COALESCE(st.quantity, 0) as stock,
			   p.barcode,
			   c.name as category_name
		FROM products p
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

	// TODO: Implement actual printing logic
	// This would typically involve:
	// 1. Getting printer settings for the location
	// 2. Formatting the invoice data
	// 3. Sending to printer via appropriate driver/API
	// 4. Logging the print job

	// For now, just log that print was requested
	fmt.Printf("Print requested for invoice ID: %d\n", invoiceID)

	return nil
}

func (s *POSService) GetHeldSales(companyID, locationID int) ([]models.Sale, error) {
	filters := map[string]string{
		"pos_status": "HOLD",
	}

	return s.salesService.GetSales(companyID, locationID, filters)
}

func (s *POSService) SearchProducts(companyID, locationID int, searchTerm string) ([]models.POSProductResponse, error) {
	query := `
		SELECT p.product_id, p.name, 
			   COALESCE(p.selling_price, 0) as price,
			   COALESCE(st.quantity, 0) as stock,
			   p.barcode,
			   c.name as category_name
		FROM products p
		LEFT JOIN stock st ON p.product_id = st.product_id AND st.location_id = $2
		LEFT JOIN categories c ON p.category_id = c.category_id
		WHERE p.company_id = $1 AND p.is_active = TRUE AND p.is_deleted = FALSE
		AND (
			LOWER(p.name) LIKE LOWER($3) OR 
			LOWER(p.sku) LIKE LOWER($3) OR 
			p.barcode = $4
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
			COALESCE(AVG(total_amount), 0) as average_ticket
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
		&summary.TotalSales, &summary.TotalTransactions, &summary.AverageTicket,
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
