package services

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

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
                           c.name as category_name,
                           COALESCE(p.is_weighable, FALSE) as is_weighable,
                           COALESCE(p.selling_uom_mode, 'LOOSE') as selling_uom_mode,
                           p.selling_unit_id,
                           su.name as selling_unit_name,
                           su.symbol as selling_unit_symbol
                FROM products p
                LEFT JOIN product_barcodes pb ON p.product_id = pb.product_id AND pb.is_primary = TRUE
                LEFT JOIN stock st ON p.product_id = st.product_id AND st.location_id = $2
                LEFT JOIN categories c ON p.category_id = c.category_id
                LEFT JOIN units su ON COALESCE(p.selling_unit_id, p.unit_id) = su.unit_id
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
			&product.Barcode, &product.CategoryName, &product.IsWeighable, &product.SellingUOMMode,
			&product.SellingUnitID, &product.SellingUnitName, &product.SellingUnitSymbol,
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

func (s *POSService) ProcessCheckout(companyID, locationID, userID int, req *models.POSCheckoutRequest, idempotencyKey string) (*models.Sale, error) {
	if err := s.validateLocationInCompany(locationID, companyID); err != nil {
		return nil, err
	}

	trainingEnabled, err := s.isTrainingModeEnabled(companyID, locationID)
	if err != nil {
		return nil, err
	}

	if req.SaleID != nil {
		// Finalize an existing held sale and keep its sale_number
		sale, err := s.finalizeHeldSale(companyID, locationID, userID, *req.SaleID, req, trainingEnabled)
		if err != nil {
			return nil, fmt.Errorf("failed to finalize held sale: %w", err)
		}
		return sale, nil
	}

	idemKey := strings.TrimSpace(idempotencyKey)
	if idemKey != "" {
		existing, err := s.salesService.getSaleByIdempotencyKey(idemKey, companyID, locationID)
		if err != nil {
			return nil, err
		}
		if existing != nil {
			// Best-effort: ensure cash register reflects the cash portion (idempotent by request id).
			if !trainingEnabled {
				s.recordCashRegisterForSale(companyID, locationID, userID, existing.SaleID, existing.SaleNumber, req, idemKey)
			}
			return existing, nil
		}
	}

	// Enforce role-based discount limits (staff limits) before creating a sale.
	// Loyalty redemption is not counted toward manual discount limits.
	manualDiscount := req.DiscountAmount
	_, _, preTotal, err := s.salesService.CalculateTotals(companyID, &models.CreateSaleRequest{
		CustomerID:     req.CustomerID,
		Items:          req.Items,
		DiscountAmount: 0,
	})
	if err != nil {
		return nil, err
	}
	overrideApproverID, overrideUsed, err := s.enforceDiscountLimits(
		companyID,
		userID,
		req.Items,
		manualDiscount,
		preTotal,
		req.ManagerOverrideToken,
		req.OverrideReason,
	)
	if err != nil {
		return nil, err
	}

	// Normal flow: create a fresh sale
	saleReq := &models.CreateSaleRequest{
		SaleNumber:      req.SaleNumber,
		CustomerID:      req.CustomerID,
		Items:           req.Items,
		PaymentMethodID: req.PaymentMethodID,
		DiscountAmount:  req.DiscountAmount,
		PaidAmount:      req.PaidAmount,
	}

	// Apply loyalty points redemption as additional discount if requested
	var plannedRedeemPoints float64
	var plannedRedeemValue float64
	if !trainingEnabled && req.CustomerID != nil && req.RedeemPoints != nil && *req.RedeemPoints > 0 {
		loyalty := NewLoyaltyService()
		// Fetch current points
		var current float64
		if err := s.db.QueryRow(`SELECT COALESCE(points,0) FROM loyalty_programs WHERE customer_id=$1`, *req.CustomerID).Scan(&current); err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get customer points: %w", err)
		}
		settings, err := loyalty.getLoyaltySettings(companyID)
		if err != nil {
			return nil, fmt.Errorf("failed to get loyalty settings: %w", err)
		}
		redeemable := current - float64(settings.MinPointsReserve)
		if redeemable > 0 {
			plannedRedeemPoints = *req.RedeemPoints
			if plannedRedeemPoints > redeemable {
				plannedRedeemPoints = redeemable
			}
			if settings.MinRedemptionPoints > 0 && plannedRedeemPoints < settings.MinRedemptionPoints {
				plannedRedeemPoints = 0
			}
			if plannedRedeemPoints > 0 {
				plannedRedeemValue = plannedRedeemPoints * settings.PointValue
				saleReq.DiscountAmount += plannedRedeemValue
			}
		}
	}

	// Credit limit check when the sale is not fully paid (i.e., creating new outstanding).
	if !trainingEnabled && req.CustomerID != nil {
		finalTotal := preTotal - manualDiscount - plannedRedeemValue
		if finalTotal < 0 {
			finalTotal = 0
		}
		outstandingDelta := finalTotal - req.PaidAmount
		if outstandingDelta > 0.0001 {
			if err := s.enforceCustomerCreditLimit(companyID, *req.CustomerID, outstandingDelta); err != nil {
				return nil, err
			}
		}
	}

	sale, err := s.salesService.CreateSaleWithOptions(
		companyID,
		locationID,
		userID,
		saleReq,
		&idempotencyKey,
		CreateSaleOptions{IsTraining: trainingEnabled},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to process checkout: %w", err)
	}

	// Align document date to the OPEN cash register's business date (important when
	// a register stays open past midnight).
	if !trainingEnabled && sale != nil {
		s.applyBusinessDateToSale(companyID, locationID, sale.SaleID)
	}

	// After sale is created, persist redemption and reduce points
	if !trainingEnabled && sale != nil && req.CustomerID != nil && plannedRedeemPoints > 0 {
		loyalty := NewLoyaltyService()
		if _, _, err := loyalty.RedeemPointsForSale(companyID, *req.CustomerID, sale.SaleID, plannedRedeemPoints); err != nil {
			// Log but do not fail sale; mismatch could happen if race condition
			log.Printf("Warning: failed to persist loyalty redemption for sale %d: %v", sale.SaleID, err)
		}
	}

	// Record payment breakdown if provided
	if len(req.Payments) > 0 {
		if err := s.recordSalePayments(nil, sale.SaleID, req.Payments); err != nil {
			log.Printf("warning: failed to record sale payments for sale %d: %v", sale.SaleID, err)
		}
	}

	// Best-effort: update cash register totals for cash payments (do not block checkout).
	if !trainingEnabled {
		s.recordCashRegisterForSale(companyID, locationID, userID, sale.SaleID, sale.SaleNumber, req, idemKey)
	}

	// Best-effort audit log when a manager override was used (do not fail the sale).
	if overrideUsed && sale != nil {
		tx, err := s.db.Begin()
		if err == nil {
			recordID := sale.SaleID
			actorID := userID
			changes := models.JSONB{
				"override":             true,
				"override_type":        "discount",
				"override_approver_id": overrideApproverID,
				"manual_bill_discount": manualDiscount,
			}
			_ = LogAudit(tx, "OVERRIDE", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil)
			_ = tx.Commit()
		}
	}

	return sale, nil
}

func (s *POSService) recordCashRegisterForSale(
	companyID, locationID, userID int,
	saleID int,
	saleNumber string,
	req *models.POSCheckoutRequest,
	idempotencyKey string,
) {
	cashIn, err := s.cashInBaseFromPOSRequest(req)
	if err != nil {
		log.Printf("warning: failed to compute cash-in for sale %d: %v", saleID, err)
		return
	}
	if cashIn <= 0 {
		return
	}
	note := fmt.Sprintf("sale_id=%d sale_number=%s", saleID, saleNumber)
	cr := &CashRegisterService{db: s.db}
	if err := cr.RecordCashTransactionTx(
		nil,
		companyID,
		locationID,
		userID,
		"IN",
		cashIn,
		"SALE",
		fmt.Sprintf("sale:%d", saleID),
		&note,
		"",
		strings.TrimSpace(idempotencyKey),
	); err != nil {
		log.Printf("warning: failed to record cash register sale event (sale_id=%d): %v", saleID, err)
	}
}

func (s *POSService) cashInBaseFromPOSRequest(req *models.POSCheckoutRequest) (float64, error) {
	if req == nil {
		return 0, nil
	}

	// If detailed payments are provided, sum CASH-method lines in base currency.
	if len(req.Payments) > 0 {
		methodIDs := make([]int, 0, len(req.Payments))
		seen := make(map[int]struct{}, len(req.Payments))
		for _, p := range req.Payments {
			if p.MethodID <= 0 {
				continue
			}
			if _, ok := seen[p.MethodID]; ok {
				continue
			}
			seen[p.MethodID] = struct{}{}
			methodIDs = append(methodIDs, p.MethodID)
		}

		methodTypes := map[int]string{}
		if len(methodIDs) > 0 {
			rows, err := s.db.Query(`SELECT method_id, type FROM payment_methods WHERE method_id = ANY($1)`, pq.Array(methodIDs))
			if err != nil {
				return 0, fmt.Errorf("failed to load payment method types: %w", err)
			}
			for rows.Next() {
				var id int
				var t string
				if err := rows.Scan(&id, &t); err == nil {
					methodTypes[id] = t
				}
			}
			rows.Close()
		}

		sum := float64(0)
		for _, p := range req.Payments {
			t := methodTypes[p.MethodID]
			if !strings.EqualFold(strings.TrimSpace(t), "CASH") {
				continue
			}
			rate := float64(1)
			if p.CurrencyID != nil {
				err := s.db.QueryRow(`
                    SELECT COALESCE(pmc.exchange_rate, c.exchange_rate, 1.0)
                    FROM currencies c
                    LEFT JOIN payment_method_currencies pmc ON pmc.currency_id = c.currency_id AND pmc.method_id = $1
                    WHERE c.currency_id = $2
                `, p.MethodID, *p.CurrencyID).Scan(&rate)
				if err != nil && err != sql.ErrNoRows {
					return 0, fmt.Errorf("failed to resolve exchange rate: %w", err)
				}
				if err == sql.ErrNoRows {
					rate = 1.0
				}
			}
			sum += p.Amount * rate
		}
		return sum, nil
	}

	// Legacy/simple payment fields.
	if req.PaymentMethodID != nil && req.PaidAmount > 0 {
		var t string
		if err := s.db.QueryRow(`SELECT type FROM payment_methods WHERE method_id = $1`, *req.PaymentMethodID).Scan(&t); err != nil {
			if err == sql.ErrNoRows {
				return 0, nil
			}
			return 0, fmt.Errorf("failed to load payment method type: %w", err)
		}
		if strings.EqualFold(strings.TrimSpace(t), "CASH") {
			return req.PaidAmount, nil
		}
	}

	return 0, nil
}

func (s *POSService) applyBusinessDateToSale(companyID, locationID, saleID int) {
	var d time.Time
	err := s.db.QueryRow(`
        SELECT cr.date
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        LIMIT 1
    `, locationID, companyID).Scan(&d)
	if err != nil {
		return
	}
	_, _ = s.db.Exec(`
        UPDATE sales s
        SET sale_date = $1, updated_at = CURRENT_TIMESTAMP
        FROM locations l
        WHERE s.sale_id = $2 AND s.location_id = l.location_id AND l.company_id = $3
    `, d, saleID, companyID)
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
                SELECT p.product_id, pb.barcode_id, p.name,
                           COALESCE(pb.selling_price, p.selling_price, 0) as price,
                           COALESCE(sv.quantity, 0) as stock,
                           pb.barcode,
                           pb.variant_name,
                           c.name as category_name,
                           COALESCE(p.is_weighable, FALSE) as is_weighable,
                           CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END as tracking_type,
                           CASE WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END as is_serialized,
                           COALESCE(p.selling_uom_mode, 'LOOSE') as selling_uom_mode,
                           p.selling_unit_id,
                           su.name as selling_unit_name,
                           su.symbol as selling_unit_symbol
                FROM products p
                JOIN product_barcodes pb ON p.product_id = pb.product_id AND COALESCE(pb.is_active, TRUE) = TRUE
                LEFT JOIN stock_variants sv ON pb.barcode_id = sv.barcode_id AND sv.location_id = $2
                LEFT JOIN categories c ON p.category_id = c.category_id
                LEFT JOIN units su ON COALESCE(p.selling_unit_id, p.unit_id) = su.unit_id
                WHERE p.company_id = $1 AND p.is_active = TRUE AND p.is_deleted = FALSE
                AND (
                        LOWER(p.name) LIKE LOWER($3) OR
                        LOWER(COALESCE(pb.variant_name, '')) LIKE LOWER($3) OR
                        LOWER(COALESCE(p.sku, '')) LIKE LOWER($3) OR
                        pb.barcode = $4 OR
                        pb.barcode ILIKE $3 OR
                        (c.name IS NOT NULL AND LOWER(c.name) LIKE LOWER($3)) OR
                        EXISTS (
                            SELECT 1 FROM product_attribute_values pav 
                            WHERE pav.product_id = p.product_id 
                              AND LOWER(pav.value) LIKE LOWER($3)
                        )
                )
                ORDER BY p.name, pb.is_primary DESC, pb.barcode_id
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
			&product.ProductID, &product.BarcodeID, &product.Name, &product.Price, &product.Stock,
			&product.Barcode, &product.VariantName, &product.CategoryName, &product.IsWeighable, &product.TrackingType, &product.IsSerialized, &product.SellingUOMMode,
			&product.SellingUnitID, &product.SellingUnitName, &product.SellingUnitSymbol,
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
		WHERE company_id = $1 AND is_active = TRUE
		ORDER BY LOWER(name), type, method_id ASC
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
                AND COALESCE(s.is_training, FALSE) = FALSE
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
		AND COALESCE(s.is_training, FALSE) = FALSE
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
func (s *POSService) checkStockAvailability(companyID, locationID, productID int, requiredQuantity float64) (bool, error) {
	var availableStock float64
	err := s.db.QueryRow(`
		SELECT COALESCE(st.quantity, 0)
		FROM stock st
		JOIN locations l ON st.location_id = l.location_id
		JOIN products p ON st.product_id = p.product_id
		WHERE st.location_id = $1 AND st.product_id = $2 AND l.company_id = $3 AND p.company_id = $3
	`, locationID, productID, companyID).Scan(&availableStock)

	if err != nil && err != sql.ErrNoRows {
		return false, err
	}

	return availableStock >= requiredQuantity, nil
}

func (s *POSService) validateLocationInCompany(locationID, companyID int) error {
	var count int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM locations WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE`, locationID, companyID).Scan(&count); err != nil {
		return fmt.Errorf("failed to validate location: %w", err)
	}
	if count == 0 {
		return fmt.Errorf("location not found")
	}
	return nil
}

// finalizeHeldSale replaces the details of an existing DRAFT sale, updates totals
// and stock, and marks it as COMPLETED while preserving sale_number.
func (s *POSService) finalizeHeldSale(companyID, locationID, userID, saleID int, req *models.POSCheckoutRequest, trainingOverride bool) (*models.Sale, error) {
	// Verify sale exists, belongs to company & location, and is DRAFT
	var status string
	var existingLocationID int
	var existingTraining bool
	err := s.db.QueryRow(`SELECT s.status, s.location_id, COALESCE(s.is_training, FALSE) FROM sales s JOIN locations l ON s.location_id = l.location_id WHERE s.sale_id=$1 AND l.company_id=$2 AND s.is_deleted=FALSE`, saleID, companyID).Scan(&status, &existingLocationID, &existingTraining)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("sale not found")
		}
		return nil, fmt.Errorf("failed to verify sale: %w", err)
	}
	if existingLocationID != locationID {
		return nil, fmt.Errorf("invalid location for sale")
	}
	if status == "COMPLETED" {
		return s.salesService.GetSaleByID(saleID, companyID)
	}
	if status != "DRAFT" {
		return nil, fmt.Errorf("sale already finalized")
	}

	isTraining := existingTraining || trainingOverride

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()
	trackingSvc := newInventoryTrackingService(s.db)

	// Recalculate totals (reusing SalesService for tax resolution)
	saleReq := &models.CreateSaleRequest{
		CustomerID:      req.CustomerID,
		Items:           req.Items,
		PaymentMethodID: req.PaymentMethodID,
		DiscountAmount:  req.DiscountAmount,
		PaidAmount:      req.PaidAmount,
	}
	subtotal, tax, total, err := s.salesService.CalculateTotals(companyID, saleReq)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate totals: %w", err)
	}
	if req.PaidAmount < 0 || req.PaidAmount > total {
		// Clamp or return error; follow same validation as CreateSale
		return nil, fmt.Errorf("invalid paid amount")
	}

	// Enforce role-based discount limits and credit limits during finalization as well
	// to prevent bypass via "hold → resume → finalize".
	preTotal := subtotal + tax
	overrideApproverID, overrideUsed, err := s.enforceDiscountLimits(
		companyID,
		userID,
		req.Items,
		req.DiscountAmount,
		preTotal,
		req.ManagerOverrideToken,
		req.OverrideReason,
	)
	if err != nil {
		return nil, err
	}
	if !isTraining && req.CustomerID != nil {
		outstandingDelta := total - req.PaidAmount
		if outstandingDelta > 0.0001 {
			if err := s.enforceCustomerCreditLimit(companyID, *req.CustomerID, outstandingDelta); err != nil {
				return nil, err
			}
		}
	}

	// Replace sale details
	if _, err := tx.Exec(`
        DELETE FROM sale_details sd
        USING sales s
        JOIN locations l ON s.location_id = l.location_id
        WHERE sd.sale_id = s.sale_id AND s.sale_id = $1 AND l.company_id = $2
    `, saleID, companyID); err != nil {
		return nil, fmt.Errorf("failed to clear sale details: %w", err)
	}

	productIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
	}
	metaByID, err := fetchProductMeta(tx, companyID, productIDs)
	if err != nil {
		return nil, err
	}
	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		var tid *int
		if item.TaxID != nil {
			tid = item.TaxID
		} else if item.ProductID != nil {
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			tid = meta.TaxID
		}
		if tid != nil {
			taxIDs = append(taxIDs, *tid)
		}
	}
	taxPctByID, err := fetchTaxPercentages(tx, companyID, taxIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate tax: %w", err)
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
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}
		if effectiveTaxID != nil {
			pct, ok := taxPctByID[*effectiveTaxID]
			if !ok {
				return nil, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			taxAmount = lineTotal * (pct / 100)
		}

		lineSnapshot := saleLineSnapshot{}
		if item.ProductID != nil {
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			lineSnapshot = newSaleLineSnapshot(meta, item.Quantity)
		}

		var saleDetailID int
		if err := tx.QueryRow(`
            INSERT INTO sale_details (sale_id, product_id, barcode_id, product_name, quantity, unit_price,
                                      discount_percentage, discount_amount, tax_id, tax_amount,
                                      line_total, serial_numbers, notes, cost_price,
                                      stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
            RETURNING sale_detail_id
        `, saleID, item.ProductID, item.BarcodeID, item.ProductName, item.Quantity, item.UnitPrice, item.DiscountPercent, discountAmount, effectiveTaxID, taxAmount, lineTotal, pq.Array(item.SerialNumbers), item.Notes, lineSnapshot.CostPricePerUnit, lineSnapshot.StockUnitID, lineSnapshot.SellingUnitID, lineSnapshot.SellingUOMMode, lineSnapshot.SellingToStock, lineSnapshot.StockQuantity).Scan(&saleDetailID); err != nil {
			return nil, fmt.Errorf("failed to insert sale detail: %w", err)
		}

		if item.ProductID != nil && !isTraining {
			issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "SALE", "sale_detail", &saleDetailID, nil, inventorySelection{
				ProductID:        *item.ProductID,
				BarcodeID:        item.BarcodeID,
				Quantity:         lineSnapshot.StockQuantity,
				SerialNumbers:    item.SerialNumbers,
				BatchAllocations: item.BatchAllocations,
				Notes:            item.Notes,
				OverridePassword: req.OverridePassword,
			})
			if err != nil {
				return nil, fmt.Errorf("failed to update stock: %w", err)
			}
			if _, err := tx.Exec(`
				UPDATE sale_details
				SET barcode_id = COALESCE($1, barcode_id),
				    cost_price = $2
				WHERE sale_detail_id = $3
			`, issue.BarcodeID, issue.UnitCost, saleDetailID); err != nil {
				return nil, fmt.Errorf("failed to update sale detail cost snapshot: %w", err)
			}
		}
	}

	// Update sale header to completed
	if _, err := tx.Exec(`
        UPDATE sales s SET customer_id=$1, subtotal=$2, tax_amount=$3, discount_amount=$4, total_amount=$5,
                          paid_amount=$6, payment_method_id=$7, status='COMPLETED', pos_status='COMPLETED',
                          is_quick_sale=FALSE, is_training=$8, updated_by=$9, updated_at=CURRENT_TIMESTAMP
        FROM locations l
        WHERE s.sale_id=$10 AND s.location_id = l.location_id AND l.company_id = $11
    `, req.CustomerID, subtotal, tax, req.DiscountAmount, total, req.PaidAmount, req.PaymentMethodID, isTraining, userID, saleID, companyID); err != nil {
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

	// Best-effort audit log when a manager override was used (do not fail the sale).
	if overrideUsed {
		tx2, err := s.db.Begin()
		if err == nil {
			recordID := saleID
			actorID := userID
			changes := models.JSONB{
				"override":             true,
				"override_type":        "discount",
				"override_approver_id": overrideApproverID,
				"manual_bill_discount": req.DiscountAmount,
			}
			_ = LogAudit(tx2, "OVERRIDE", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil)
			_ = tx2.Commit()
		}
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
func (s *POSService) VoidSale(companyID, locationID, userID, originalSaleID int, idempotencyKey string, reason string, overrideApproverID *int, requestID string) (*models.Sale, error) {
	// Load original sale header and items
	var status string
	var origLocationID int
	var subtotal, tax, discount, total float64
	var origTraining bool
	err := s.db.QueryRow(`
        SELECT s.status, s.location_id, s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, COALESCE(s.is_training, FALSE)
        FROM sales s
        JOIN locations l ON s.location_id = l.location_id
        WHERE s.sale_id=$1 AND l.company_id=$2 AND s.is_deleted=FALSE
    `, originalSaleID, companyID).Scan(&status, &origLocationID, &subtotal, &tax, &discount, &total, &origTraining)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("sale not found")
		}
		return nil, fmt.Errorf("failed to get sale: %w", err)
	}
	if origLocationID != locationID {
		return nil, fmt.Errorf("invalid location for sale")
	}

	idemKey := strings.TrimSpace(idempotencyKey)
	if idemKey != "" {
		existing, err := s.salesService.getSaleByIdempotencyKey(idemKey, companyID, locationID)
		if err != nil {
			return nil, err
		}
		if existing != nil {
			return existing, nil
		}
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
                           payment_method_id, status, pos_status, is_quick_sale, is_training, notes, created_by, updated_by, idempotency_key)
        SELECT $1, s.location_id, s.customer_id, CURRENT_DATE, CURRENT_TIME,
               $2, $3, $4, $5, 0, NULL, 'VOID','COMPLETED', FALSE, $6, 'Void of sale ' || s.sale_number, $7, $7, $9
        FROM sales s WHERE s.sale_id=$8
        RETURNING sale_id
    `, voidNumber, vSubtotal, vTax, vDiscount, vTotal, origTraining, userID, originalSaleID, nullIfEmpty(idemKey)).Scan(&voidSaleID); err != nil {
		return nil, fmt.Errorf("failed to create void sale: %w", err)
	}

	if status == "COMPLETED" {
		// Copy items as negatives and adjust stock back
		rows, err := tx.Query(`
            SELECT product_id, product_name, quantity, unit_price, discount_percentage, discount_amount, tax_id, tax_amount, line_total, serial_numbers, notes,
                   COALESCE(cost_price, 0)::float8,
                   stock_unit_id, selling_unit_id, COALESCE(selling_uom_mode, 'LOOSE'),
                   COALESCE(selling_to_stock_factor, 1.0)::float8,
                   COALESCE(NULLIF(stock_quantity, 0), quantity * COALESCE(selling_to_stock_factor, 1.0))::float8
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
			var costPrice float64
			var stockUnitID *int
			var sellingUnitID *int
			var sellingUOMMode string
			var sellingToStock float64
			var stockQuantity float64
			if err := rows.Scan(&productID, &productName, &quantity, &unitPrice, &discPct, &discAmt, &taxID, &taxAmt, &lineTotal, pq.Array(&serials), &notes, &costPrice, &stockUnitID, &sellingUnitID, &sellingUOMMode, &sellingToStock, &stockQuantity); err != nil {
				return nil, fmt.Errorf("failed to scan original item: %w", err)
			}
			nQty := -quantity
			nDiscAmt := -discAmt
			nTaxAmt := -taxAmt
			nLineTotal := -lineTotal
			nStockQuantity := -stockQuantity
			if _, err := tx.Exec(`
                INSERT INTO sale_details (sale_id, product_id, product_name, quantity, unit_price,
                                          discount_percentage, discount_amount, tax_id, tax_amount,
                                          line_total, serial_numbers, notes, cost_price,
                                          stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
            `, voidSaleID, productID, productName, nQty, unitPrice, discPct, nDiscAmt, taxID, nTaxAmt, nLineTotal, pq.Array(serials), notes, costPrice, stockUnitID, sellingUnitID, sellingUOMMode, sellingToStock, nStockQuantity); err != nil {
				return nil, fmt.Errorf("failed to insert void item: %w", err)
			}
			if !origTraining && productID != nil {
				if err := s.salesService.updateStock(tx, locationID, *productID, stockQuantity); err != nil {
					return nil, fmt.Errorf("failed to revert stock: %w", err)
				}
			}
		}
	}

	// Audit log (must be present for voids).
	{
		recordID := originalSaleID
		actorID := userID
		changes := models.JSONB{
			"void_sale_id": voidSaleID,
			"reason":       reason,
		}
		if overrideApproverID != nil && *overrideApproverID > 0 {
			changes["override_approver_id"] = *overrideApproverID
		}
		if strings.TrimSpace(requestID) != "" {
			changes["request_id"] = requestID
		}
		if err := LogAudit(tx, "VOID", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
			return nil, fmt.Errorf("failed to log audit: %w", err)
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
func (s *POSService) CreateHeldSale(companyID, locationID, userID int, req *models.POSCheckoutRequest, idempotencyKey string) (*models.Sale, error) {
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("at least one item is required")
	}
	if err := s.validateLocationInCompany(locationID, companyID); err != nil {
		return nil, err
	}

	isTraining, err := s.isTrainingModeEnabled(companyID, locationID)
	if err != nil {
		return nil, err
	}

	idemKey := strings.TrimSpace(idempotencyKey)
	if idemKey != "" {
		existing, err := s.salesService.getSaleByIdempotencyKey(idemKey, companyID, locationID)
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

	// Use client-provided sale number when present (offline-first). Otherwise,
	// allocate via numbering sequences.
	saleNumber := ""
	if req.SaleNumber != nil {
		saleNumber = strings.TrimSpace(*req.SaleNumber)
	}
	if saleNumber != "" {
		if len(saleNumber) > 100 {
			return nil, fmt.Errorf("sale number too long")
		}
	} else {
		ns := NewNumberingSequenceService()
		sequenceName := "sale"
		if isTraining {
			sequenceName = "sale_training"
		}
		saleNumber, err = ns.NextNumber(tx, sequenceName, companyID, &locationID)
		if err != nil {
			return nil, fmt.Errorf("failed to generate sale number: %w", err)
		}
	}

	// Calculate totals and per-line taxes
	subtotal := float64(0)
	totalTax := float64(0)

	productIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
	}
	metaByID, err := fetchProductMeta(tx, companyID, productIDs)
	if err != nil {
		return nil, err
	}
	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		var tid *int
		if item.TaxID != nil {
			tid = item.TaxID
		} else if item.ProductID != nil {
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			tid = meta.TaxID
		}
		if tid != nil {
			taxIDs = append(taxIDs, *tid)
		}
	}
	taxPctByID, err := fetchTaxPercentages(tx, companyID, taxIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate tax: %w", err)
	}

	// We'll also compute discount per line for persistence
	type lineComputed struct {
		qty       float64
		unit      float64
		discPct   float64
		discAmt   float64
		taxID     *int
		taxAmt    float64
		total     float64
		pid       *int
		barcodeID *int
		pname     *string
		serials   []string
		notes     *string
		snapshot  saleLineSnapshot
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
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}
		if effectiveTaxID != nil {
			pct, ok := taxPctByID[*effectiveTaxID]
			if !ok {
				return nil, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			taxAmount = lineTotal * (pct / 100)
		}
		subtotal += lineTotal
		totalTax += taxAmount
		lineSnapshot := saleLineSnapshot{}
		if item.ProductID != nil {
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			lineSnapshot = newSaleLineSnapshot(meta, item.Quantity)
		}
		lines = append(lines, lineComputed{
			qty:       item.Quantity,
			unit:      item.UnitPrice,
			discPct:   item.DiscountPercent,
			discAmt:   discountAmount,
			taxID:     effectiveTaxID,
			taxAmt:    taxAmount,
			total:     lineTotal,
			pid:       item.ProductID,
			barcodeID: item.BarcodeID,
			pname:     item.ProductName,
			serials:   item.SerialNumbers,
			notes:     item.Notes,
			snapshot:  lineSnapshot,
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
                           payment_method_id, status, pos_status, is_quick_sale, is_training, notes, created_by, updated_by, idempotency_key)
        VALUES ($1,$2,$3,CURRENT_DATE,CURRENT_TIME,$4,$5,$6,$7,$8,$9,'DRAFT','HOLD',FALSE,$10,$11,$12,$12,$13)
        RETURNING sale_id
    `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount, totalAmount, 0.0, nil, isTraining, nil, userID, nullIfEmpty(idemKey)).Scan(&saleID)
	if err != nil {
		return nil, fmt.Errorf("failed to create held sale: %w", err)
	}

	// Insert sale details (no stock updates)
	for _, lc := range lines {
		if _, err := tx.Exec(`
            INSERT INTO sale_details (sale_id, product_id, barcode_id, product_name, quantity, unit_price,
                                      discount_percentage, discount_amount, tax_id, tax_amount,
                                      line_total, serial_numbers, notes, cost_price,
                                      stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
        `, saleID, lc.pid, lc.barcodeID, lc.pname, lc.qty, lc.unit, lc.discPct, lc.discAmt, lc.taxID, lc.taxAmt, lc.total, pq.Array(lc.serials), lc.notes, lc.snapshot.CostPricePerUnit, lc.snapshot.StockUnitID, lc.snapshot.SellingUnitID, lc.snapshot.SellingUOMMode, lc.snapshot.SellingToStock, lc.snapshot.StockQuantity); err != nil {
			return nil, fmt.Errorf("failed to create held sale item: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit held sale: %w", err)
	}

	if !isTraining {
		s.applyBusinessDateToSale(companyID, locationID, saleID)
	}

	return s.salesService.GetSaleByID(saleID, companyID)
}

func (s *POSService) isTrainingModeEnabled(companyID, locationID int) (bool, error) {
	var enabled bool
	err := s.db.QueryRow(`
        SELECT COALESCE(cr.training_mode, FALSE)
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        LIMIT 1
    `, locationID, companyID).Scan(&enabled)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("failed to resolve training mode: %w", err)
	}
	return enabled, nil
}

func (s *POSService) enforceDiscountLimits(
	companyID int,
	userID int,
	items []models.CreateSaleDetailRequest,
	billDiscountAmount float64,
	preTotal float64,
	overrideToken *string,
	overrideReason *string,
) (approverUserID int, overrideUsed bool, err error) {
	// Resolve current user's role limits.
	permSvc := NewPermissionService()
	roleID, err := permSvc.GetUserRoleID(userID)
	if err != nil {
		return 0, false, err
	}
	limitsSvc := NewPOSLimitsService()
	limits, err := limitsSvc.GetLimitsForRole(roleID)
	if err != nil {
		return 0, false, err
	}

	// Max line discount (percent).
	maxLine := float64(0)
	for _, it := range items {
		if it.DiscountPercent > maxLine {
			maxLine = it.DiscountPercent
		}
	}

	// Bill discount percent derived from preTotal (subtotal+tax before bill discount).
	billPct := float64(0)
	if preTotal > 0 && billDiscountAmount > 0 {
		billPct = (billDiscountAmount / preTotal) * 100
	}

	needsOverride := maxLine > limits.MaxLineDiscountPct || billPct > limits.MaxBillDiscountPct
	if !needsOverride {
		return 0, false, nil
	}

	// Require a manager override token to proceed.
	token := ""
	if overrideToken != nil {
		token = strings.TrimSpace(*overrideToken)
	}
	if token == "" {
		return 0, false, &OverrideRequiredError{
			Message:             "Manager override required",
			RequiredPermissions: []string{"OVERRIDE_DISCOUNTS"},
			ReasonRequired:      true,
		}
	}

	ctx, err := ValidateOverrideToken(token, companyID, []string{"OVERRIDE_DISCOUNTS"})
	if err != nil {
		return 0, false, err
	}

	reason := ""
	if overrideReason != nil {
		reason = strings.TrimSpace(*overrideReason)
	}
	if reason == "" {
		return 0, false, fmt.Errorf("override_reason is required")
	}

	return ctx.ApproverUserID, true, nil
}

func (s *POSService) enforceCustomerCreditLimit(companyID, customerID int, additionalOutstanding float64) error {
	if additionalOutstanding <= 0 {
		return nil
	}

	var limit float64
	var current float64
	err := s.db.QueryRow(`
		SELECT c.credit_limit,
			   COALESCE(SUM(s.total_amount - s.paid_amount),0) AS credit_balance
		FROM customers c
		LEFT JOIN sales s ON c.customer_id = s.customer_id AND s.is_deleted = FALSE
		WHERE c.customer_id = $1 AND c.company_id = $2 AND c.is_deleted = FALSE
		GROUP BY c.credit_limit
	`, customerID, companyID).Scan(&limit, &current)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("customer not found")
		}
		return fmt.Errorf("failed to check credit limit: %w", err)
	}

	// A limit of 0 (or negative) means no credit allowed.
	if limit <= 0 {
		return &CreditLimitExceededError{CreditLimit: limit, CurrentBalance: current, AttemptedDelta: additionalOutstanding}
	}

	if current+additionalOutstanding > limit+0.0001 {
		return &CreditLimitExceededError{CreditLimit: limit, CurrentBalance: current, AttemptedDelta: additionalOutstanding}
	}

	return nil
}
