package services

import (
	"database/sql"
	"fmt"
	"log"
	"sort"
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

type sqlQueryer interface {
	Query(query string, args ...any) (*sql.Rows, error)
}

type productMeta struct {
	StockUnitID     *int
	PurchaseUnitID  *int
	SellingUnitID   *int
	TaxID           *int
	IsSerialized    bool
	CostPrice       float64
	PurchaseToStock float64
	SellingToStock  float64
	IsWeighable     bool
	PurchaseUOMMode string
	SellingUOMMode  string
}

func uniqueInts(in []int) []int {
	if len(in) == 0 {
		return nil
	}
	seen := make(map[int]struct{}, len(in))
	out := make([]int, 0, len(in))
	for _, v := range in {
		if v == 0 {
			continue
		}
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

func fetchProductMeta(q sqlQueryer, companyID int, productIDs []int) (map[int]productMeta, error) {
	ids := uniqueInts(productIDs)
	if len(ids) == 0 {
		return map[int]productMeta{}, nil
	}
	rows, err := q.Query(`
		SELECT product_id, unit_id, purchase_unit_id, selling_unit_id, tax_id, is_serialized, COALESCE(cost_price, 0)::float8,
		       COALESCE(purchase_to_stock_factor, 1.0)::float8,
		       COALESCE(selling_to_stock_factor, 1.0)::float8,
		       COALESCE(is_weighable, FALSE),
		       COALESCE(purchase_uom_mode, 'LOOSE'),
		       COALESCE(selling_uom_mode, 'LOOSE')
		FROM products
		WHERE company_id = $1 AND is_deleted = FALSE AND product_id = ANY($2)
	`, companyID, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch products: %w", err)
	}
	defer rows.Close()

	out := make(map[int]productMeta, len(ids))
	for rows.Next() {
		var pid int
		var stockUnitID sql.NullInt64
		var purchaseUnitID sql.NullInt64
		var sellingUnitID sql.NullInt64
		var taxID sql.NullInt64
		var isSerialized bool
		var costPrice float64
		var purchaseToStock float64
		var sellingToStock float64
		var isWeighable bool
		var purchaseUOMMode string
		var sellingUOMMode string
		if err := rows.Scan(&pid, &stockUnitID, &purchaseUnitID, &sellingUnitID, &taxID, &isSerialized, &costPrice, &purchaseToStock, &sellingToStock, &isWeighable, &purchaseUOMMode, &sellingUOMMode); err != nil {
			return nil, fmt.Errorf("failed to scan product: %w", err)
		}
		var tid *int
		if taxID.Valid && taxID.Int64 > 0 {
			v := int(taxID.Int64)
			tid = &v
		}
		out[pid] = productMeta{
			StockUnitID:     intPtrFromNullInt64(stockUnitID),
			PurchaseUnitID:  intPtrFromNullInt64(purchaseUnitID),
			SellingUnitID:   intPtrFromNullInt64(sellingUnitID),
			TaxID:           tid,
			IsSerialized:    isSerialized,
			CostPrice:       costPrice,
			PurchaseToStock: normalizeProductUOMFactor(&purchaseToStock),
			SellingToStock:  normalizeProductUOMFactor(&sellingToStock),
			IsWeighable:     isWeighable,
			PurchaseUOMMode: purchaseUOMMode,
			SellingUOMMode:  sellingUOMMode,
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read products: %w", err)
	}
	if len(out) != len(ids) {
		return nil, fmt.Errorf("product not found")
	}
	return out, nil
}

func fetchTaxPercentages(q sqlQueryer, companyID int, taxIDs []int) (map[int]float64, error) {
	ids := uniqueInts(taxIDs)
	if len(ids) == 0 {
		return map[int]float64{}, nil
	}
	rows, err := q.Query(`
		SELECT tax_id, percentage
		FROM taxes
		WHERE company_id = $1 AND is_active = TRUE AND tax_id = ANY($2)
	`, companyID, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to get tax percentage: %w", err)
	}
	defer rows.Close()

	out := make(map[int]float64, len(ids))
	for rows.Next() {
		var id int
		var pct float64
		if err := rows.Scan(&id, &pct); err != nil {
			return nil, fmt.Errorf("failed to scan tax percentage: %w", err)
		}
		out[id] = pct
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read tax percentages: %w", err)
	}
	return out, nil
}

// CalculateTotals computes the subtotal, total tax, and final total for a sale
// request. It is used by handlers for validation and internally by the service
// before persisting a sale.
func (s *SalesService) CalculateTotals(companyID int, req *models.CreateSaleRequest) (float64, float64, float64, error) {
	subtotal := float64(0)
	totalTax := float64(0)

	productIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
	}
	products, err := fetchProductMeta(s.db, companyID, productIDs)
	if err != nil {
		return 0, 0, 0, err
	}

	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.TaxID != nil {
			taxIDs = append(taxIDs, *item.TaxID)
			continue
		}
		if item.ProductID == nil {
			continue
		}
		meta, ok := products[*item.ProductID]
		if !ok {
			return 0, 0, 0, fmt.Errorf("product not found")
		}
		if meta.TaxID != nil {
			taxIDs = append(taxIDs, *meta.TaxID)
		}
	}
	taxPct, err := fetchTaxPercentages(s.db, companyID, taxIDs)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("failed to calculate tax: %w", err)
	}

	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount
		subtotal += lineTotal

		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ProductID != nil {
			meta, ok := products[*item.ProductID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}

		if effectiveTaxID != nil {
			pct, ok := taxPct[*effectiveTaxID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			totalTax += lineTotal * (pct / 100)
		}
	}

	totalAmount := subtotal + totalTax - req.DiscountAmount
	return subtotal, totalTax, totalAmount, nil
}

func (s *SalesService) GetSales(companyID, locationID int, filters map[string]string) ([]models.Sale, error) {
	query := `
		SELECT s.sale_id, s.sale_number, s.location_id, s.customer_id, s.sale_date, s.sale_time,
			   s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
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
			&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
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
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
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
		&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
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

	if bd, berr := s.computeSaleTaxBreakdown(companyID, sale.Items); berr == nil {
		sale.TaxBreakdown = bd
	} else {
		log.Printf("warning: failed to compute tax breakdown for sale_id=%d: %v", saleID, berr)
	}

	return &sale, nil
}

func (s *SalesService) computeSaleTaxBreakdown(companyID int, items []models.SaleDetail) ([]models.TaxBreakdownLine, error) {
	type compMeta struct {
		name  string
		pct   float64
		order int
	}
	type taxMeta struct {
		name       string
		totalPct   float64
		components []compMeta
	}

	taxIDSet := map[int]struct{}{}
	for _, it := range items {
		if it.TaxID == nil {
			continue
		}
		if it.TaxAmount <= 0 {
			continue
		}
		taxIDSet[*it.TaxID] = struct{}{}
	}
	if len(taxIDSet) == 0 {
		return nil, nil
	}

	taxIDs := make([]int, 0, len(taxIDSet))
	for id := range taxIDSet {
		taxIDs = append(taxIDs, id)
	}
	sort.Ints(taxIDs)

	rows, err := s.db.Query(`
		SELECT t.tax_id, t.name, t.percentage,
		       tc.component_id, tc.name, tc.percentage, tc.sort_order
		FROM taxes t
		LEFT JOIN tax_components tc ON tc.tax_id = t.tax_id
		WHERE t.company_id = $1 AND t.tax_id = ANY($2)
		ORDER BY t.tax_id, tc.sort_order, tc.component_id
	`, companyID, pq.Array(taxIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to load tax metadata: %w", err)
	}
	defer rows.Close()

	meta := map[int]*taxMeta{}
	for rows.Next() {
		var taxID int
		var taxName string
		var taxPct float64
		var compID sql.NullInt64
		var compName sql.NullString
		var compPct sql.NullFloat64
		var compOrder sql.NullInt64
		if err := rows.Scan(&taxID, &taxName, &taxPct, &compID, &compName, &compPct, &compOrder); err != nil {
			return nil, fmt.Errorf("failed to scan tax metadata: %w", err)
		}
		m, ok := meta[taxID]
		if !ok {
			m = &taxMeta{name: taxName, totalPct: taxPct}
			meta[taxID] = m
		}
		if compName.Valid && compPct.Valid {
			m.components = append(m.components, compMeta{
				name:  compName.String,
				pct:   compPct.Float64,
				order: int(compOrder.Int64),
			})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read tax metadata: %w", err)
	}

	type aggKey struct {
		taxID int
		name  string
		pct   float64
	}
	type aggVal struct {
		line  models.TaxBreakdownLine
		order int
	}
	acc := map[aggKey]*aggVal{}

	for _, it := range items {
		if it.TaxID == nil || it.TaxAmount <= 0 {
			continue
		}
		tm := meta[*it.TaxID]
		if tm == nil {
			continue
		}

		if len(tm.components) > 0 && tm.totalPct > 0 {
			for _, c := range tm.components {
				amt := it.TaxAmount * (c.pct / tm.totalPct)
				k := aggKey{taxID: *it.TaxID, name: c.name, pct: c.pct}
				v := acc[k]
				if v == nil {
					v = &aggVal{
						line: models.TaxBreakdownLine{
							TaxID:         *it.TaxID,
							TaxName:       tm.name,
							ComponentName: c.name,
							Percentage:    c.pct,
							Amount:        0,
						},
						order: c.order,
					}
					acc[k] = v
				}
				v.line.Amount += amt
			}
		} else {
			k := aggKey{taxID: *it.TaxID, name: tm.name, pct: tm.totalPct}
			v := acc[k]
			if v == nil {
				v = &aggVal{
					line: models.TaxBreakdownLine{
						TaxID:         *it.TaxID,
						TaxName:       tm.name,
						ComponentName: tm.name,
						Percentage:    tm.totalPct,
						Amount:        0,
					},
					order: 0,
				}
				acc[k] = v
			}
			v.line.Amount += it.TaxAmount
		}
	}

	out := make([]models.TaxBreakdownLine, 0, len(acc))
	type sortable struct {
		taxName string
		taxID   int
		order   int
		name    string
		line    models.TaxBreakdownLine
	}
	tmp := make([]sortable, 0, len(acc))
	for _, v := range acc {
		tmp = append(tmp, sortable{
			taxName: v.line.TaxName,
			taxID:   v.line.TaxID,
			order:   v.order,
			name:    v.line.ComponentName,
			line:    v.line,
		})
	}
	sort.Slice(tmp, func(i, j int) bool {
		if tmp[i].taxName != tmp[j].taxName {
			return tmp[i].taxName < tmp[j].taxName
		}
		if tmp[i].taxID != tmp[j].taxID {
			return tmp[i].taxID < tmp[j].taxID
		}
		if tmp[i].order != tmp[j].order {
			return tmp[i].order < tmp[j].order
		}
		return tmp[i].name < tmp[j].name
	})
	for _, it := range tmp {
		out = append(out, it.line)
	}
	return out, nil
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

type CreateSaleOptions struct {
	IsTraining bool
}

func (s *SalesService) CreateSale(companyID, locationID, userID int, req *models.CreateSaleRequest, idempotencyKey *string) (*models.Sale, error) {
	return s.CreateSaleWithOptions(companyID, locationID, userID, req, idempotencyKey, CreateSaleOptions{})
}

func (s *SalesService) CreateSaleWithOptions(
	companyID, locationID, userID int,
	req *models.CreateSaleRequest,
	idempotencyKey *string,
	opts CreateSaleOptions,
) (*models.Sale, error) {
	// Validate customer belongs to company if provided
	if req.CustomerID != nil {
		err := s.validateCustomerInCompany(*req.CustomerID, companyID)
		if err != nil {
			return nil, err
		}
	}

	// Check for applicable promotions (skip in training mode; training should not consume promotion logic by default).
	var totalDiscount float64
	var appliedPromotions []int
	if !opts.IsTraining && req.CustomerID != nil {
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
	trackingSvc := newInventoryTrackingService(s.db)

	// Use client-provided sale number when present (offline-first). Otherwise,
	// allocate via numbering sequences.
	saleNumber := strings.TrimSpace(ptrString(req.SaleNumber))
	if saleNumber != "" {
		if len(saleNumber) > 100 {
			return nil, fmt.Errorf("sale number too long")
		}
	} else {
		ns := NewNumberingSequenceService()
		sequenceName := "sale"
		if opts.IsTraining {
			sequenceName = "sale_training"
		}
		saleNumber, err = ns.NextNumber(tx, sequenceName, companyID, &locationID)
		if err != nil {
			return nil, fmt.Errorf("failed to generate sale number: %w", err)
		}
	}

	// Create sale
	var saleID int
	err = tx.QueryRow(`
               INSERT INTO sales (sale_number, location_id, customer_id, sale_date, sale_time,
                                                  subtotal, tax_amount, discount_amount, total_amount, paid_amount,
                                                  payment_method_id, status, pos_status, is_quick_sale, is_training, notes, created_by, updated_by, idempotency_key)
               VALUES ($1, $2, $3, CURRENT_DATE, CURRENT_TIME, $4, $5, $6, $7, $8, $9, 'COMPLETED', 'COMPLETED', FALSE, $10, $11, $12, $12, $13)
               RETURNING sale_id
       `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount,
		totalAmount, req.PaidAmount, req.PaymentMethodID, opts.IsTraining, req.Notes, userID, nullIfEmpty(idemKey)).Scan(&saleID)

	if err != nil {
		if idemKey != "" && isUniqueViolation(err) {
			existing, lookupErr := s.getSaleByIdempotencyKey(idemKey, companyID, locationID)
			if lookupErr != nil {
				return nil, lookupErr
			}
			if existing != nil {
				return existing, nil
			}
		}
		return nil, fmt.Errorf("failed to create sale: %w", err)
	}

	// Create sale items and update stock
	productIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
	}
	productMetaByID, err := fetchProductMeta(tx, companyID, productIDs)
	if err != nil {
		return nil, err
	}

	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ProductID != nil {
			meta, ok := productMetaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}
		if effectiveTaxID != nil {
			taxIDs = append(taxIDs, *effectiveTaxID)
		}
	}
	taxPctByID, err := fetchTaxPercentages(tx, companyID, taxIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate tax: %w", err)
	}

	for _, item := range req.Items {
		// Calculate line total and tax
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount

		var taxAmount float64
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ProductID != nil {
			meta, ok := productMetaByID[*item.ProductID]
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

		// Validate serial numbers for serialized products
		if item.ProductID != nil {
			meta, ok := productMetaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			stockQuantity := saleQuantityToStock(meta, item.Quantity)
			if meta.IsSerialized {
				if stockQuantity != float64(int(stockQuantity)) {
					return nil, fmt.Errorf("quantity must be a whole number for serialized products")
				}
				if len(item.SerialNumbers) != int(stockQuantity) {
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
		lineSnapshot := saleLineSnapshot{}
		if item.ProductID != nil {
			meta, ok := productMetaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			lineSnapshot = newSaleLineSnapshot(meta, item.Quantity)
		}

		var saleDetailID int
		err = tx.QueryRow(`
			INSERT INTO sale_details (sale_id, product_id, barcode_id, product_name, quantity, unit_price,
									 discount_percentage, discount_amount, tax_id, tax_amount,
									 line_total, serial_numbers, notes, cost_price,
									 stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
			RETURNING sale_detail_id
		`, saleID, item.ProductID, item.BarcodeID, item.ProductName, item.Quantity, item.UnitPrice,
			item.DiscountPercent, discountAmount, effectiveTaxID, taxAmount, lineTotal,
			pq.Array(item.SerialNumbers), item.Notes, lineSnapshot.CostPricePerUnit,
			lineSnapshot.StockUnitID, lineSnapshot.SellingUnitID, lineSnapshot.SellingUOMMode, lineSnapshot.SellingToStock, lineSnapshot.StockQuantity).Scan(&saleDetailID)

		if err != nil {
			return nil, fmt.Errorf("failed to create sale item: %w", err)
		}

		// Update stock if product_id is provided (skip in training mode).
		if !opts.IsTraining && item.ProductID != nil {
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
				return nil, fmt.Errorf("failed to update sale item cost snapshot: %w", err)
			}
		}
	}

	// Record applied promotions (if any)
	if !opts.IsTraining {
		for _, promotionID := range appliedPromotions {
			_, err = tx.Exec(`
				INSERT INTO sale_promotions (sale_id, promotion_id, discount_amount)
				VALUES ($1, $2, $3)
			`, saleID, promotionID, totalDiscount/float64(len(appliedPromotions))) // Distribute discount evenly

			if err != nil {
				// Log error but don't fail the sale
				log.Printf("sales_service: failed to record promotion %d for sale %d: %v", promotionID, saleID, err)
			}
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	if !opts.IsTraining {
		// Record ledger entry
		if err := (&LedgerService{db: s.db}).RecordSale(companyID, saleID, userID); err != nil {
			log.Printf("sales_service: failed to post sale %d to ledger: %v", saleID, err)
		}

		// Award loyalty points if customer is provided (async operation)
		if req.CustomerID != nil {
			go func() {
				loyaltyService := NewLoyaltyService()
				err := loyaltyService.AwardPoints(companyID, *req.CustomerID, totalAmount, saleID)
				if err != nil {
					// Log error but don't fail the sale
					log.Printf("sales_service: failed to award loyalty points for sale %d: %v", saleID, err)
				}
			}()
		}
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

func ptrString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
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
		SELECT sd.sale_detail_id, sd.sale_id, sd.product_id, sd.barcode_id, sd.product_name, sd.quantity,
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
			&item.SaleDetailID, &item.SaleID, &item.ProductID, &item.BarcodeID, &item.ProductName,
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
                       s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
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
			&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
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
			   q.converted_sale_id, q.converted_at, q.converted_by,
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
			&q.ConvertedSaleID, &q.ConvertedAt, &q.ConvertedBy,
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
			   q.converted_sale_id, q.converted_at, q.converted_by,
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
		&quote.ConvertedSaleID, &quote.ConvertedAt, &quote.ConvertedBy,
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

	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice
		discountAmount := lineTotal * (item.DiscountPercent / 100)
		lineTotal -= discountAmount

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

		var taxAmount float64
		if effectiveTaxID != nil {
			pct, ok := taxPctByID[*effectiveTaxID]
			if !ok {
				return nil, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			taxAmount = lineTotal * (pct / 100)
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
	// Quotes are immutable after conversion.
	var convertedSaleID sql.NullInt64
	if err := s.db.QueryRow(`
		SELECT q.converted_sale_id
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&convertedSaleID); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("quote not found")
		}
		return fmt.Errorf("failed to check quote conversion: %w", err)
	}
	if convertedSaleID.Valid {
		return fmt.Errorf("quote already converted")
	}

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

		productIDs := make([]int, 0, len(req.Items))
		for _, item := range req.Items {
			if item.ProductID != nil {
				productIDs = append(productIDs, *item.ProductID)
			}
		}
		metaByID, err := fetchProductMeta(tx, companyID, productIDs)
		if err != nil {
			return err
		}
		taxIDs := make([]int, 0, len(req.Items))
		for _, item := range req.Items {
			var tid *int
			if item.TaxID != nil {
				tid = item.TaxID
			} else if item.ProductID != nil {
				meta, ok := metaByID[*item.ProductID]
				if !ok {
					return fmt.Errorf("product not found")
				}
				tid = meta.TaxID
			}
			if tid != nil {
				taxIDs = append(taxIDs, *tid)
			}
		}
		taxPctByID, err := fetchTaxPercentages(tx, companyID, taxIDs)
		if err != nil {
			return fmt.Errorf("failed to calculate tax: %w", err)
		}

		for _, item := range req.Items {
			lineTotal := item.Quantity * item.UnitPrice
			discountAmt := lineTotal * (item.DiscountPercent / 100)
			lineTotal -= discountAmt

			var effectiveTaxID *int
			if item.TaxID != nil {
				effectiveTaxID = item.TaxID
			} else if item.ProductID != nil {
				meta, ok := metaByID[*item.ProductID]
				if !ok {
					return fmt.Errorf("product not found")
				}
				effectiveTaxID = meta.TaxID
			}

			var taxAmount float64
			if effectiveTaxID != nil {
				pct, ok := taxPctByID[*effectiveTaxID]
				if !ok {
					return fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
				}
				taxAmount = lineTotal * (pct / 100)
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
	// Prevent deleting quotes that were already converted to sales.
	var convertedSaleID sql.NullInt64
	if err := s.db.QueryRow(`
		SELECT q.converted_sale_id
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&convertedSaleID); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("quote not found")
		}
		return fmt.Errorf("failed to check quote conversion: %w", err)
	}
	if convertedSaleID.Valid {
		return fmt.Errorf("quote already converted")
	}

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
	log.Printf("sales_service: share requested for quote %d", quoteID)
	return nil
}

func (s *SalesService) GetQuotePrintData(quoteID, companyID int) (*models.QuotePrintDataResponse, error) {
	quote, err := s.GetQuoteByID(quoteID, companyID)
	if err != nil {
		return nil, err
	}

	companySvc := NewCompanyService()
	company, err := companySvc.GetCompanyByID(companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get company: %w", err)
	}

	return &models.QuotePrintDataResponse{
		Quote:   *quote,
		Company: *company,
	}, nil
}

func (s *SalesService) ConvertQuoteToSale(quoteID, companyID, userID int) (*models.Sale, error) {
	var (
		locationID     int
		quoteNumber    string
		customerID     *int
		discountAmount float64
		status         string
		notes          sql.NullString
		convertedSale  sql.NullInt64
	)

	err := s.db.QueryRow(`
		SELECT q.location_id, q.quote_number, q.customer_id, q.discount_amount, q.status, q.notes, q.converted_sale_id
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&locationID, &quoteNumber, &customerID, &discountAmount, &status, &notes, &convertedSale)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("quote not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get quote: %w", err)
	}

	if convertedSale.Valid {
		return s.GetSaleByID(int(convertedSale.Int64), companyID)
	}

	if status != "ACCEPTED" {
		return nil, fmt.Errorf("quote must be ACCEPTED before conversion")
	}

	items, err := s.getQuoteItems(quoteID, companyID)
	if err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, fmt.Errorf("quote has no items")
	}

	saleItems := make([]models.CreateSaleDetailRequest, 0, len(items))
	for _, it := range items {
		saleItems = append(saleItems, models.CreateSaleDetailRequest{
			ProductID:       it.ProductID,
			ProductName:     it.ProductName,
			Quantity:        it.Quantity,
			UnitPrice:       it.UnitPrice,
			DiscountPercent: it.DiscountPercent,
			TaxID:           it.TaxID,
			SerialNumbers:   it.SerialNumbers,
			Notes:           it.Notes,
		})
	}

	combinedNotes := strings.TrimSpace(notes.String)
	origin := strings.TrimSpace(fmt.Sprintf("Converted from Quote %s", strings.TrimSpace(quoteNumber)))
	if combinedNotes == "" {
		combinedNotes = origin
	} else {
		combinedNotes = combinedNotes + "\n" + origin
	}
	finalNotes := combinedNotes

	req := &models.CreateSaleRequest{
		CustomerID:     customerID,
		Items:          saleItems,
		PaidAmount:     0,
		DiscountAmount: discountAmount,
		Notes:          &finalNotes,
	}

	idemKey := fmt.Sprintf("quote:%d", quoteID)
	sale, err := s.CreateSale(companyID, locationID, userID, req, &idemKey)
	if err != nil {
		return nil, err
	}

	// Mark quote as converted and make it immutable.
	_, err = s.db.Exec(`
		UPDATE quotes q
		SET status = 'CONVERTED',
		    converted_sale_id = $1,
		    converted_at = CURRENT_TIMESTAMP,
		    converted_by = $2,
		    updated_by = $2,
		    updated_at = CURRENT_TIMESTAMP
		FROM locations l
		WHERE q.quote_id = $3 AND q.location_id = l.location_id AND l.company_id = $4 AND q.is_deleted = FALSE
	`, sale.SaleID, userID, quoteID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to mark quote converted: %w", err)
	}

	return sale, nil
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
