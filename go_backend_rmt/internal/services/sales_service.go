package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math"
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

type refundSourceContext struct {
	SaleID     int
	SaleNumber string
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
		SELECT product_id, unit_id, purchase_unit_id, selling_unit_id, tax_id,
		       CASE WHEN COALESCE(is_serialized, FALSE) OR COALESCE(tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized,
		       COALESCE(cost_price, 0)::float8,
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
	taxSettings, err := loadCompanyTaxSettings(s.db, companyID)
	if err != nil {
		return 0, 0, 0, err
	}

	productIDs := make([]int, 0, len(req.Items))
	comboProductIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
		if item.ComboProductID != nil {
			comboProductIDs = append(comboProductIDs, *item.ComboProductID)
		}
	}
	products, err := fetchProductMeta(s.db, companyID, productIDs)
	if err != nil {
		return 0, 0, 0, err
	}
	comboProducts, err := fetchComboProductMeta(s.db, companyID, comboProductIDs, nil)
	if err != nil {
		return 0, 0, 0, err
	}

	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.TaxID != nil {
			taxIDs = append(taxIDs, *item.TaxID)
			continue
		}
		if item.ComboProductID != nil {
			meta, ok := comboProducts[*item.ComboProductID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("combo product not found")
			}
			if meta.TaxID != nil {
				taxIDs = append(taxIDs, *meta.TaxID)
			}
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
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ComboProductID != nil {
			meta, ok := comboProducts[*item.ComboProductID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("combo product not found")
			}
			effectiveTaxID = meta.TaxID
		} else if item.ProductID != nil {
			meta, ok := products[*item.ProductID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}

		taxPercent := 0.0
		if effectiveTaxID != nil {
			pct, ok := taxPct[*effectiveTaxID]
			if !ok {
				return 0, 0, 0, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			taxPercent = pct
		}
		line := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, taxPercent, taxSettings.PriceMode)
		subtotal += line.NetAmount
		totalTax += line.TaxAmount
	}

	totalAmount := subtotal + totalTax - req.DiscountAmount
	return subtotal, totalTax, totalAmount, nil
}

func (s *SalesService) GetSales(companyID, locationID int, filters map[string]string) ([]models.Sale, error) {
	query := `
		SELECT s.sale_id, s.sale_number, s.location_id, s.source_channel, s.transaction_type, s.refund_source_sale_id, rs.sale_number AS refund_source_sale_number,
			   s.customer_id, s.sale_date, s.sale_time,
			   s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
			   s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
			   c.name as customer_name, pm.name as payment_method_name
		FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		LEFT JOIN sales rs ON rs.sale_id = s.refund_source_sale_id
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
	if transactionType := filters["transaction_type"]; transactionType != "" {
		argCount++
		query += fmt.Sprintf(" AND s.transaction_type = $%d", argCount)
		args = append(args, strings.ToUpper(strings.TrimSpace(transactionType)))
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
		var sourceChannel, refundSourceSaleNumber sql.NullString
		var refundSourceSaleID sql.NullInt64

		err := rows.Scan(
			&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sourceChannel, &sale.TransactionType, &refundSourceSaleID, &refundSourceSaleNumber, &sale.CustomerID,
			&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
			&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
			&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
			&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
			&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale: %w", err)
		}
		if sourceChannel.Valid {
			sale.SourceChannel = &sourceChannel.String
		}
		if refundSourceSaleID.Valid {
			v := int(refundSourceSaleID.Int64)
			sale.RefundSourceID = &v
		}
		if refundSourceSaleNumber.Valid {
			sale.RefundSourceRef = &refundSourceSaleNumber.String
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
		SELECT s.sale_id, s.sale_number, s.location_id, s.source_channel, s.transaction_type, s.refund_source_sale_id, rs.sale_number AS refund_source_sale_number,
			   s.customer_id, s.sale_date, s.sale_time,
			   s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
			   s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
			   s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
			   c.name as customer_name, pm.name as payment_method_name, l.name as location_name,
			   COALESCE(NULLIF(TRIM(CONCAT(COALESCE(cu.first_name, ''), ' ', COALESCE(cu.last_name, ''))), ''), cu.username, cu.email, '') AS created_by_name,
			   COALESCE(NULLIF(TRIM(CONCAT(COALESCE(uu.first_name, ''), ' ', COALESCE(uu.last_name, ''))), ''), uu.username, uu.email, '') AS updated_by_name
		FROM sales s
		LEFT JOIN sales rs ON rs.sale_id = s.refund_source_sale_id
		LEFT JOIN customers c ON s.customer_id = c.customer_id
		LEFT JOIN payment_methods pm ON s.payment_method_id = pm.method_id
		JOIN locations l ON s.location_id = l.location_id
		LEFT JOIN users cu ON s.created_by = cu.user_id
		LEFT JOIN users uu ON s.updated_by = uu.user_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`

	var sale models.Sale
	var customerName, paymentMethodName sql.NullString
	var locationName, createdByName, updatedByName sql.NullString
	var sourceChannel, refundSourceSaleNumber sql.NullString
	var refundSourceSaleID sql.NullInt64

	err := s.db.QueryRow(query, saleID, companyID).Scan(
		&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sourceChannel, &sale.TransactionType, &refundSourceSaleID, &refundSourceSaleNumber, &sale.CustomerID,
		&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
		&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
		&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
		&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
		&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
		&locationName, &createdByName, &updatedByName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get sale: %w", err)
	}
	if sourceChannel.Valid {
		sale.SourceChannel = &sourceChannel.String
	}
	if refundSourceSaleID.Valid {
		v := int(refundSourceSaleID.Int64)
		sale.RefundSourceID = &v
	}
	if refundSourceSaleNumber.Valid {
		sale.RefundSourceRef = &refundSourceSaleNumber.String
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
	if locationName.Valid {
		sale.LocationName = &locationName.String
	}
	if createdByName.Valid {
		sale.CreatedByName = &createdByName.String
	}
	if updatedByName.Valid {
		sale.UpdatedByName = &updatedByName.String
	}

	// Get sale items
	items, err := s.getSaleItems(saleID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale items: %w", err)
	}
	sale.Items = items

	if sale.RefundSourceID == nil {
		returnedQty, err := (&ReturnsService{db: s.db}).GetReturnedQuantitiesBySaleDetail(companyID, saleID)
		if err == nil {
			totalQty := 0.0
			returnedTotalQty := 0.0
			for _, item := range sale.Items {
				if item.Quantity <= 0 {
					continue
				}
				totalQty += item.Quantity
				if qty := returnedQty[item.SaleDetailID]; qty > 0 {
					if qty > item.Quantity {
						qty = item.Quantity
					}
					returnedTotalQty += qty
				}
			}
			if totalQty > 0 && returnedTotalQty > 0 {
				state := "PARTIAL"
				if returnedTotalQty >= totalQty-0.0001 {
					state = "FULL"
				}
				sale.RefundState = &state
			}
		}
	}

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
	IsTraining                 bool
	CashInAmount               float64
	LoyaltyRedeemPoints        float64
	CouponCode                 string
	AutoFillRaffleCustomerData *bool
	SourceChannel              string
	TransactionType            string
}

func normalizeTransactionType(raw string) string {
	switch strings.ToUpper(strings.TrimSpace(raw)) {
	case "":
		return ""
	case "RETAIL":
		return "RETAIL"
	case "B2B":
		return "B2B"
	default:
		return ""
	}
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

	if totalAmount >= 0 {
		if req.PaidAmount < 0 {
			return nil, fmt.Errorf("paid amount cannot be negative")
		}
		if req.PaidAmount > totalAmount {
			return nil, fmt.Errorf("paid amount cannot exceed total amount")
		}
	} else {
		if req.PaidAmount > 0 {
			return nil, fmt.Errorf("refund paid amount must be stored as a negative amount")
		}
		if req.PaidAmount < totalAmount {
			return nil, fmt.Errorf("refund paid amount cannot exceed refund total")
		}
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
			if !opts.IsTraining {
				_ = NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "sale", existing.SaleID)
			}
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

	hasRefundLines := false
	for _, item := range req.Items {
		if item.Quantity < 0 {
			hasRefundLines = true
			break
		}
	}
	if hasRefundLines {
		if err := requireSalesActionPassword(tx, companyID, userID, req.OverridePassword); err != nil {
			return nil, err
		}
	}
	refundSource, err := s.resolveRefundSourceContextTx(tx, companyID, req.Items)
	if err != nil {
		return nil, err
	}
	saleNotes := req.Notes
	var refundSourceSaleID *int
	if refundSource != nil {
		refundSourceSaleID = &refundSource.SaleID
		saleNotes = mergeSaleRefundContextNotes(req.Notes, refundSource.SaleNumber)
	}

	// Use client-provided sale number when present (offline-first). Otherwise,
	// allocate via numbering sequences.
	saleNumber := strings.TrimSpace(ptrString(req.SaleNumber))
	sourceChannel := strings.ToUpper(strings.TrimSpace(opts.SourceChannel))
	if sourceChannel == "" {
		sourceChannel = "INVOICE"
	}
	transactionType := normalizeTransactionType(opts.TransactionType)
	if req.TransactionType != nil {
		transactionType = normalizeTransactionType(*req.TransactionType)
		if transactionType == "" {
			return nil, fmt.Errorf("invalid transaction_type")
		}
	}
	if transactionType == "" {
		transactionType = "RETAIL"
	}
	if transactionType == "B2B" && req.CustomerID == nil {
		return nil, fmt.Errorf("b2b transactions require customer_id")
	}
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
                                                  payment_method_id, status, pos_status, is_quick_sale, is_training, notes, source_channel, transaction_type, refund_source_sale_id, created_by, updated_by, idempotency_key)
               VALUES ($1, $2, $3, CURRENT_DATE, CURRENT_TIME, $4, $5, $6, $7, $8, $9, 'COMPLETED', 'COMPLETED', FALSE, $10, $11, $12, $13, $14, $15, $15, $16)
               RETURNING sale_id
       `, saleNumber, locationID, req.CustomerID, subtotal, totalTax, req.DiscountAmount,
		totalAmount, req.PaidAmount, req.PaymentMethodID, opts.IsTraining, saleNotes, sourceChannel, transactionType, refundSourceSaleID, userID, nullIfEmpty(idemKey)).Scan(&saleID)

	if err != nil {
		if idemKey != "" && isUniqueViolation(err) {
			existing, lookupErr := s.getSaleByIdempotencyKey(idemKey, companyID, locationID)
			if lookupErr != nil {
				return nil, lookupErr
			}
			if existing != nil {
				if !opts.IsTraining {
					_ = NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "sale", existing.SaleID)
				}
				return existing, nil
			}
		}
		return nil, fmt.Errorf("failed to create sale: %w", err)
	}

	// Create sale items and update stock
	preparedLines, err := prepareSaleDetailsTx(tx, companyID, locationID, req.Items)
	if err != nil {
		return nil, err
	}
	actualCosts := make([]issuedSaleLineCost, 0, len(preparedLines))

	for _, line := range preparedLines {
		var saleDetailID int
		err = tx.QueryRow(`
			INSERT INTO sale_details (sale_id, product_id, combo_product_id, barcode_id, product_name, quantity, unit_price,
									 discount_percentage, discount_amount, tax_id, tax_amount,
									 line_total, source_sale_detail_id, serial_numbers, notes, cost_price,
									 stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
			RETURNING sale_detail_id
		`, saleID, line.ProductID, line.ComboProductID, line.BarcodeID, line.ProductName, line.Quantity, line.UnitPrice,
			line.DiscountPercent, line.DiscountAmount, line.TaxID, line.TaxAmount, line.LineTotal, line.SourceSaleDetailID,
			pq.Array(line.SerialNumbers), line.Notes, line.Snapshot.CostPricePerUnit,
			line.Snapshot.StockUnitID, line.Snapshot.SellingUnitID, line.Snapshot.SellingUOMMode, line.Snapshot.SellingToStock, line.Snapshot.StockQuantity).Scan(&saleDetailID)
		if err != nil {
			return nil, fmt.Errorf("failed to create sale item: %w", err)
		}

		if opts.IsTraining || line.ProductID == nil {
			actualCosts = append(actualCosts, issuedSaleLineCost{
				BarcodeID:        line.BarcodeID,
				CostPricePerUnit: line.Snapshot.CostPricePerUnit,
				TotalCost:        line.Snapshot.CostPricePerUnit * line.Quantity,
			})
			continue
		}

		if line.Quantity > 0 {
			selection := inventorySelection{
				ProductID:        *line.ProductID,
				BarcodeID:        line.BarcodeID,
				ComboProductID:   line.ComboProductID,
				Quantity:         line.Snapshot.StockQuantity,
				SerialNumbers:    line.SerialNumbers,
				BatchAllocations: line.BatchAllocations,
				Notes:            line.Notes,
				OverridePassword: req.OverridePassword,
			}

			issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "SALE", "sale_detail", &saleDetailID, nil, selection)
			if err != nil {
				return nil, fmt.Errorf("failed to update stock: %w", err)
			}
			actualCost := actualSaleLineCost(line, issue)
			actualCosts = append(actualCosts, actualCost)
			if _, err := tx.Exec(`
				UPDATE sale_details
				SET barcode_id = COALESCE($1, barcode_id),
				    cost_price = $2,
				    serial_numbers = $3
				WHERE sale_detail_id = $4
			`, issue.BarcodeID, actualCost.CostPricePerUnit, pq.Array(selection.SerialNumbers), saleDetailID); err != nil {
				return nil, fmt.Errorf("failed to update sale item cost snapshot: %w", err)
			}
			continue
		}

		if line.SourceSaleDetailID == nil {
			return nil, fmt.Errorf("refund line is missing source sale detail")
		}
		sourceLine, err := s.loadRefundableSaleLineByDetailTx(tx, companyID, *line.SourceSaleDetailID)
		if err != nil {
			return nil, err
		}
		refundQuantity := -line.Quantity
		if refundQuantity > sourceLine.AvailableQuantity+0.0001 {
			return nil, fmt.Errorf("refund quantity for line %d exceeds available quantity", *line.SourceSaleDetailID)
		}
		if len(sourceLine.SerialNumbers) > 0 &&
			math.Abs(refundQuantity-sourceLine.AvailableQuantity) > 0.0001 {
			return nil, fmt.Errorf("serialized refund lines must return the full remaining quantity")
		}
		serialNumbers := line.SerialNumbers
		if len(serialNumbers) == 0 {
			serialNumbers = sourceLine.SerialNumbers
		}
		if _, err := trackingSvc.ReceiveStockTx(tx, companyID, locationID, userID, "SALE_RETURN", "sale_detail", &saleDetailID, nil, inventorySelection{
			ProductID:      *line.ProductID,
			BarcodeID:      line.BarcodeID,
			ComboProductID: line.ComboProductID,
			Quantity:       -line.Snapshot.StockQuantity,
			SerialNumbers:  serialNumbers,
			UnitCost:       line.Snapshot.CostPricePerUnit,
			Notes:          line.Notes,
		}); err != nil {
			return nil, fmt.Errorf("failed to receive refund stock: %w", err)
		}
		actualCosts = append(actualCosts, issuedSaleLineCost{})
		if _, err := tx.Exec(`
			UPDATE sale_details
			SET serial_numbers = $1
			WHERE sale_detail_id = $2
		`, pq.Array(serialNumbers), saleDetailID); err != nil {
			return nil, fmt.Errorf("failed to update refund sale item tracking snapshot: %w", err)
		}
	}

	if !opts.IsTraining {
		profitDetails := buildProfitGuardDetails(preparedLines, actualCosts, req.DiscountAmount)
		if err := s.enforceNegativeProfitPolicyTx(tx, companyID, req.OverridePassword, profitDetails); err != nil {
			return nil, err
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

	if !opts.IsTraining {
		finance := NewFinanceIntegrityServiceWithDB(s.db)
		if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
			CompanyID:     companyID,
			LocationID:    &locationID,
			EventType:     financeEventLedgerSale,
			AggregateType: "sale",
			AggregateID:   saleID,
			Payload:       models.JSONB{},
			CreatedBy:     &userID,
		}); err != nil {
			return nil, fmt.Errorf("failed to enqueue sale ledger posting: %w", err)
		}

		cashInAmount, err := s.resolveCashInAmountTx(tx, companyID, req, opts)
		if err != nil {
			return nil, err
		}
		if cashInAmount != 0 {
			direction := "IN"
			eventType := "SALE"
			amount := cashInAmount
			if amount < 0 {
				direction = "OUT"
				eventType = "SALE_REFUND"
				amount = -amount
			}
			note := fmt.Sprintf("sale_id=%d sale_number=%s", saleID, saleNumber)
			if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
				CompanyID:     companyID,
				LocationID:    &locationID,
				EventType:     financeEventCashSale,
				AggregateType: "sale",
				AggregateID:   saleID,
				Payload: models.JSONB{
					"amount":      amount,
					"direction":   direction,
					"event_type":  eventType,
					"reason_code": fmt.Sprintf("sale:%d", saleID),
					"notes":       note,
				},
				CreatedBy: &userID,
			}); err != nil {
				return nil, fmt.Errorf("failed to enqueue sale cash register event: %w", err)
			}
		}

		if req.CustomerID != nil {
			if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
				CompanyID:     companyID,
				LocationID:    &locationID,
				EventType:     financeEventLoyaltyAward,
				AggregateType: "sale",
				AggregateID:   saleID,
				Payload: models.JSONB{
					"customer_id": *req.CustomerID,
					"sale_amount": totalAmount,
				},
				CreatedBy: &userID,
			}); err != nil {
				return nil, fmt.Errorf("failed to enqueue loyalty award: %w", err)
			}
		}

		if req.CustomerID != nil && opts.LoyaltyRedeemPoints > 0 {
			if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
				CompanyID:     companyID,
				LocationID:    &locationID,
				EventType:     financeEventLoyaltyRedeem,
				AggregateType: "sale",
				AggregateID:   saleID,
				Payload: models.JSONB{
					"customer_id":      *req.CustomerID,
					"requested_points": opts.LoyaltyRedeemPoints,
				},
				CreatedBy: &userID,
			}); err != nil {
				return nil, fmt.Errorf("failed to enqueue loyalty redemption: %w", err)
			}
		}

		if req.CustomerID != nil && strings.TrimSpace(opts.CouponCode) != "" {
			couponCode := strings.TrimSpace(opts.CouponCode)
			if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
				CompanyID:     companyID,
				LocationID:    &locationID,
				EventType:     financeEventCouponRedeem,
				AggregateType: "sale",
				AggregateID:   saleID,
				Payload: models.JSONB{
					"code":        couponCode,
					"customer_id": *req.CustomerID,
				},
				CreatedBy: &userID,
			}); err != nil {
				return nil, fmt.Errorf("failed to enqueue coupon redemption: %w", err)
			}
		}

		if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
			CompanyID:     companyID,
			LocationID:    &locationID,
			EventType:     financeEventRaffleIssue,
			AggregateType: "sale",
			AggregateID:   saleID,
			Payload: models.JSONB{
				"customer_id":             req.CustomerID,
				"auto_fill_customer_data": opts.AutoFillRaffleCustomerData,
			},
			CreatedBy: &userID,
		}); err != nil {
			return nil, fmt.Errorf("failed to enqueue raffle issuance: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	if !opts.IsTraining {
		if err := NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "sale", saleID); err != nil {
			log.Printf("sales_service: failed to process finance outbox for sale %d: %v", saleID, err)
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

func (s *SalesService) resolveRefundSourceContextTx(tx *sql.Tx, companyID int, items []models.CreateSaleDetailRequest) (*refundSourceContext, error) {
	detailIDs := make([]int, 0, len(items))
	seen := make(map[int]struct{}, len(items))
	for _, item := range items {
		if item.Quantity >= 0 {
			continue
		}
		if item.SourceSaleDetailID == nil || *item.SourceSaleDetailID <= 0 {
			return nil, fmt.Errorf("refund line is missing source sale detail")
		}
		if _, ok := seen[*item.SourceSaleDetailID]; ok {
			continue
		}
		seen[*item.SourceSaleDetailID] = struct{}{}
		detailIDs = append(detailIDs, *item.SourceSaleDetailID)
	}
	if len(detailIDs) == 0 {
		return nil, nil
	}

	rows, err := tx.Query(`
		SELECT sd.sale_detail_id, sd.sale_id, s.sale_number
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE sd.sale_detail_id = ANY($1)
		  AND l.company_id = $2
		  AND s.is_deleted = FALSE
	`, pq.Array(detailIDs), companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve refund source sale: %w", err)
	}
	defer rows.Close()

	found := make(map[int]struct{}, len(detailIDs))
	var source *refundSourceContext
	for rows.Next() {
		var saleDetailID int
		var saleID int
		var saleNumber string
		if err := rows.Scan(&saleDetailID, &saleID, &saleNumber); err != nil {
			return nil, fmt.Errorf("failed to scan refund source sale: %w", err)
		}
		found[saleDetailID] = struct{}{}
		if source == nil {
			source = &refundSourceContext{
				SaleID:     saleID,
				SaleNumber: strings.TrimSpace(saleNumber),
			}
			continue
		}
		if source.SaleID != saleID {
			return nil, fmt.Errorf("refund lines must belong to the same source invoice")
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate refund source sale rows: %w", err)
	}
	if len(found) != len(detailIDs) {
		return nil, fmt.Errorf("source sale detail not found")
	}
	return source, nil
}

func mergeSaleRefundContextNotes(notes *string, sourceSaleNumber string) *string {
	sourceSaleNumber = strings.TrimSpace(sourceSaleNumber)
	base := strings.TrimSpace(ptrString(notes))
	if sourceSaleNumber == "" {
		return nullIfEmpty(base)
	}

	refLine := fmt.Sprintf("Includes refund from invoice %s.", sourceSaleNumber)
	if base == "" {
		return &refLine
	}

	lowerBase := strings.ToLower(base)
	lowerSaleNumber := strings.ToLower(sourceSaleNumber)
	if strings.Contains(lowerBase, lowerSaleNumber) && strings.Contains(lowerBase, "refund") {
		return &base
	}

	combined := strings.TrimSpace(base + "\n" + refLine)
	return &combined
}

func (s *SalesService) resolveCashInAmountTx(tx *sql.Tx, companyID int, req *models.CreateSaleRequest, opts CreateSaleOptions) (float64, error) {
	if opts.CashInAmount != 0 {
		return opts.CashInAmount, nil
	}
	if req == nil || req.PaymentMethodID == nil || req.PaidAmount == 0 {
		return 0, nil
	}
	var paymentType string
	if err := tx.QueryRow(`
		SELECT type
		FROM payment_methods
		WHERE method_id = $1
		  AND is_active = TRUE
		  AND (company_id = $2 OR company_id IS NULL)
	`, *req.PaymentMethodID, companyID).Scan(&paymentType); err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, fmt.Errorf("failed to resolve payment method for sale cash posting: %w", err)
	}
	if strings.EqualFold(strings.TrimSpace(paymentType), "CASH") {
		return req.PaidAmount, nil
	}
	return 0, nil
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

	if err := requireSalesActionPassword(tx, companyID, userID, req.OverridePassword); err != nil {
		return err
	}

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

type refundableSaleLine struct {
	SaleDetailID      int
	ProductID         *int
	ComboProductID    *int
	BarcodeID         *int
	ProductName       *string
	Quantity          float64
	UnitPrice         float64
	DiscountPercent   float64
	DiscountAmount    float64
	TaxID             *int
	TaxAmount         float64
	LineTotal         float64
	CostPrice         float64
	StockUnitID       *int
	SellingUnitID     *int
	SellingUOMMode    string
	SellingToStock    float64
	StockQuantity     float64
	SerialNumbers     []string
	AlreadyReturned   float64
	AvailableQuantity float64
}

func (s *SalesService) CreateRefundInvoice(companyID, sourceSaleID, userID int, req *models.CreateRefundInvoiceRequest) (*models.Sale, error) {
	if req == nil || len(req.Items) == 0 {
		return nil, fmt.Errorf("at least one refund item is required")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start refund transaction: %w", err)
	}
	defer tx.Rollback()

	if err := requireSalesActionPassword(tx, companyID, userID, req.OverridePassword); err != nil {
		return nil, err
	}

	var locationID int
	var customerID sql.NullInt64
	var paymentMethodID sql.NullInt64
	var sourceSaleNumber string
	var status string
	var sourceChannel sql.NullString
	var transactionType string
	var sourcePaidAmount float64
	var sourceSubtotal float64
	var sourceTax float64
	var sourceDiscount float64
	var isTraining bool

	err = tx.QueryRow(`
		SELECT
			s.location_id,
			s.customer_id,
			s.payment_method_id,
			s.sale_number,
			s.status,
			s.source_channel,
			s.transaction_type,
			s.paid_amount,
			s.subtotal,
			s.tax_amount,
			s.discount_amount,
			COALESCE(s.is_training, FALSE)
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		WHERE s.sale_id = $1
		  AND l.company_id = $2
		  AND s.is_deleted = FALSE
		FOR UPDATE
	`, sourceSaleID, companyID).Scan(
		&locationID,
		&customerID,
		&paymentMethodID,
		&sourceSaleNumber,
		&status,
		&sourceChannel,
		&transactionType,
		&sourcePaidAmount,
		&sourceSubtotal,
		&sourceTax,
		&sourceDiscount,
		&isTraining,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load source sale: %w", err)
	}
	if status != "COMPLETED" {
		return nil, fmt.Errorf("only completed sales can be refunded")
	}

	channel := strings.ToUpper(strings.TrimSpace(sourceChannel.String))
	switch channel {
	case "POS_REFUND":
		return nil, fmt.Errorf("refund invoices cannot be refunded again")
	}

	refundLines := make([]refundableSaleLine, 0, len(req.Items))
	refundSubtotal := 0.0
	refundTax := 0.0
	refundableGrossAbs := 0.0
	seenDetails := make(map[int]struct{}, len(req.Items))

	for _, item := range req.Items {
		if _, exists := seenDetails[item.SaleDetailID]; exists {
			return nil, fmt.Errorf("duplicate sale detail %d in refund request", item.SaleDetailID)
		}
		seenDetails[item.SaleDetailID] = struct{}{}

		line, err := s.loadRefundableSaleLineTx(tx, companyID, sourceSaleID, item.SaleDetailID)
		if err != nil {
			return nil, err
		}
		if item.Quantity > line.AvailableQuantity+0.0001 {
			return nil, fmt.Errorf("refund quantity for line %d exceeds available quantity", item.SaleDetailID)
		}
		if item.Quantity <= 0 {
			return nil, fmt.Errorf("refund quantity must be greater than zero")
		}
		if line.Quantity <= 0 {
			return nil, fmt.Errorf("invalid source sale quantity for line %d", item.SaleDetailID)
		}

		ratio := item.Quantity / line.Quantity
		refundLine := line
		refundLine.Quantity = -item.Quantity
		refundLine.DiscountAmount = -(line.DiscountAmount * ratio)
		refundLine.TaxAmount = -(line.TaxAmount * ratio)
		refundLine.LineTotal = -(line.LineTotal * ratio)
		refundLine.StockQuantity = -(line.StockQuantity * ratio)

		if len(line.SerialNumbers) > 0 {
			if item.Quantity != line.AvailableQuantity || item.Quantity != line.Quantity {
				return nil, fmt.Errorf("serialized refund lines must return the full remaining quantity")
			}
			refundLine.SerialNumbers = append([]string(nil), line.SerialNumbers...)
		}

		refundSubtotal += refundLine.LineTotal
		refundTax += refundLine.TaxAmount
		refundableGrossAbs += (-refundLine.LineTotal) + (-refundLine.TaxAmount)
		refundLines = append(refundLines, *refundLine)
	}

	sourceGross := sourceSubtotal + sourceTax
	refundHeaderDiscount := 0.0
	if sourceDiscount > 0 && sourceGross > 0 && refundableGrossAbs > 0 {
		refundHeaderDiscount = -(sourceDiscount * (refundableGrossAbs / sourceGross))
	}
	refundTotal := refundSubtotal + refundTax - refundHeaderDiscount
	if refundTotal >= 0 {
		return nil, fmt.Errorf("refund total must be negative")
	}

	refundPaidAbs := sourcePaidAmount
	refundTotalAbs := -refundTotal
	if refundPaidAbs > refundTotalAbs {
		refundPaidAbs = refundTotalAbs
	}
	if refundPaidAbs < 0 {
		refundPaidAbs = 0
	}
	refundPaidAmount := -refundPaidAbs

	ns := NewNumberingSequenceService()
	refundSaleNumber, err := ns.NextNumber(tx, "sale", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refund invoice number: %w", err)
	}

	var refundSaleID int
	err = tx.QueryRow(`
		INSERT INTO sales (
			sale_number, location_id, customer_id, sale_date, sale_time,
			subtotal, tax_amount, discount_amount, total_amount, paid_amount,
			payment_method_id, status, pos_status, is_quick_sale, is_training, notes,
			source_channel, transaction_type, refund_source_sale_id, created_by, updated_by
		)
		VALUES (
			$1, $2, $3, CURRENT_DATE, CURRENT_TIME,
			$4, $5, $6, $7, $8,
			$9, 'COMPLETED', 'COMPLETED', FALSE, $10, $11,
			'POS_REFUND', $12, $13, $14, $14
		)
		RETURNING sale_id
	`, refundSaleNumber, locationID, nullIntToPtr(customerID), refundSubtotal, refundTax, refundHeaderDiscount, refundTotal, refundPaidAmount,
		nullIntToPtr(paymentMethodID), isTraining, req.Reason, transactionType, sourceSaleID, userID).Scan(&refundSaleID)
	if err != nil {
		return nil, fmt.Errorf("failed to create refund invoice: %w", err)
	}

	trackingSvc := newInventoryTrackingService(s.db)
	for _, line := range refundLines {
		var refundDetailID int
		err = tx.QueryRow(`
			INSERT INTO sale_details (
				sale_id, product_id, combo_product_id, barcode_id, product_name, quantity, unit_price,
				discount_percentage, discount_amount, tax_id, tax_amount, line_total, source_sale_detail_id,
				serial_numbers, notes, cost_price, stock_unit_id, selling_unit_id, selling_uom_mode,
				selling_to_stock_factor, stock_quantity
			)
			VALUES (
				$1, $2, $3, $4, $5, $6, $7,
				$8, $9, $10, $11, $12, $13,
				$14, $15, $16, $17, $18, $19,
				$20, $21
			)
			RETURNING sale_detail_id
		`, refundSaleID, line.ProductID, line.ComboProductID, line.BarcodeID, line.ProductName, line.Quantity, line.UnitPrice,
			line.DiscountPercent, line.DiscountAmount, line.TaxID, line.TaxAmount, line.LineTotal, line.SaleDetailID,
			pq.Array(line.SerialNumbers), req.Reason, line.CostPrice, line.StockUnitID, line.SellingUnitID, line.SellingUOMMode,
			line.SellingToStock, line.StockQuantity).Scan(&refundDetailID)
		if err != nil {
			return nil, fmt.Errorf("failed to create refund invoice line: %w", err)
		}

		if !isTraining && line.ProductID != nil {
			receivedStockQty := -line.StockQuantity
			if receivedStockQty < 0 {
				receivedStockQty = 0
			}
			if _, err := trackingSvc.ReceiveStockTx(tx, companyID, locationID, userID, "SALE_RETURN", "sale_detail", &refundDetailID, nil, inventorySelection{
				ProductID:      *line.ProductID,
				BarcodeID:      line.BarcodeID,
				ComboProductID: line.ComboProductID,
				Quantity:       receivedStockQty,
				SerialNumbers:  line.SerialNumbers,
				UnitCost:       line.CostPrice,
				Notes:          req.Reason,
			}); err != nil {
				return nil, fmt.Errorf("failed to receive refunded stock: %w", err)
			}
		}
	}

	if refundPaidAbs > 0 {
		if _, err := tx.Exec(`
			UPDATE sales
			SET paid_amount = paid_amount - $1,
			    updated_at = CURRENT_TIMESTAMP,
			    updated_by = $2
			WHERE sale_id = $3
		`, refundPaidAbs, userID, sourceSaleID); err != nil {
			return nil, fmt.Errorf("failed to update source sale paid amount: %w", err)
		}
	}

	recordID := refundSaleID
	actorID := userID
	changes := models.JSONB{
		"refund_source_sale_id": sourceSaleID,
		"refund_source_sale_no": sourceSaleNumber,
		"reason":                strings.TrimSpace(ptrString(req.Reason)),
	}
	if err := LogAudit(tx, "CREATE", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
		return nil, fmt.Errorf("failed to log refund invoice audit: %w", err)
	}

	if !isTraining {
		finance := NewFinanceIntegrityServiceWithDB(s.db)
		if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
			CompanyID:     companyID,
			LocationID:    &locationID,
			EventType:     financeEventLedgerSale,
			AggregateType: "sale",
			AggregateID:   refundSaleID,
			Payload:       models.JSONB{},
			CreatedBy:     &userID,
		}); err != nil {
			return nil, fmt.Errorf("failed to enqueue refund ledger posting: %w", err)
		}

		if refundPaidAbs > 0 && paymentMethodID.Valid {
			var paymentType string
			if err := tx.QueryRow(`
				SELECT type
				FROM payment_methods
				WHERE method_id = $1
				  AND is_active = TRUE
				  AND (company_id = $2 OR company_id IS NULL)
			`, int(paymentMethodID.Int64), companyID).Scan(&paymentType); err == nil && strings.EqualFold(strings.TrimSpace(paymentType), "CASH") {
				note := fmt.Sprintf("refund_sale_id=%d refund_sale_number=%s source_sale_id=%d source_sale_number=%s", refundSaleID, refundSaleNumber, sourceSaleID, sourceSaleNumber)
				if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
					CompanyID:     companyID,
					LocationID:    &locationID,
					EventType:     financeEventCashSale,
					AggregateType: "sale",
					AggregateID:   refundSaleID,
					Payload: models.JSONB{
						"amount":      refundPaidAbs,
						"direction":   "OUT",
						"event_type":  "SALE_REFUND",
						"reason_code": fmt.Sprintf("sale:%d:refund", refundSaleID),
						"notes":       note,
					},
					CreatedBy: &userID,
				}); err != nil {
					return nil, fmt.Errorf("failed to enqueue refund cash event: %w", err)
				}
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit refund invoice: %w", err)
	}

	if !isTraining {
		if err := NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "sale", refundSaleID); err != nil {
			log.Printf("sales_service: failed to process finance outbox for refund sale %d: %v", refundSaleID, err)
		}
	}

	return s.GetSaleByID(refundSaleID, companyID)
}

func (s *SalesService) loadRefundableSaleLineTx(tx *sql.Tx, companyID, sourceSaleID, saleDetailID int) (*refundableSaleLine, error) {
	var line refundableSaleLine
	var saleReturnQty float64
	var refundInvoiceQty float64
	var serialNumbers pq.StringArray

	err := tx.QueryRow(`
		SELECT
			sd.sale_detail_id,
			sd.product_id,
			sd.combo_product_id,
			sd.barcode_id,
			sd.product_name,
			sd.quantity::float8,
			sd.unit_price::float8,
			COALESCE(sd.discount_percentage, 0)::float8,
			COALESCE(sd.discount_amount, 0)::float8,
			sd.tax_id,
			COALESCE(sd.tax_amount, 0)::float8,
			sd.line_total::float8,
			COALESCE(sd.cost_price, 0)::float8,
			sd.stock_unit_id,
			sd.selling_unit_id,
			COALESCE(sd.selling_uom_mode, 'LOOSE'),
			COALESCE(sd.selling_to_stock_factor, 1.0)::float8,
			COALESCE(NULLIF(sd.stock_quantity, 0), sd.quantity * COALESCE(sd.selling_to_stock_factor, 1.0))::float8,
			sd.serial_numbers,
			COALESCE((
				SELECT SUM(srd.quantity)::float8
				FROM sale_return_details srd
				JOIN sale_returns sr ON sr.return_id = srd.return_id
				WHERE sr.sale_id = $1
				  AND sr.status = 'COMPLETED'
				  AND srd.sale_detail_id = sd.sale_detail_id
			), 0)::float8 AS sale_returned_qty,
			COALESCE((
				SELECT SUM(ABS(rsd.quantity))::float8
				FROM sale_details rsd
				JOIN sales rs ON rs.sale_id = rsd.sale_id
				WHERE rs.refund_source_sale_id = $1
				  AND rs.status = 'COMPLETED'
				  AND rs.is_deleted = FALSE
				  AND rsd.source_sale_detail_id = sd.sale_detail_id
			), 0)::float8 AS refund_invoice_qty
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE sd.sale_detail_id = $2
		  AND sd.sale_id = $1
		  AND l.company_id = $3
		  AND s.is_deleted = FALSE
		FOR UPDATE OF sd
	`, sourceSaleID, saleDetailID, companyID).Scan(
		&line.SaleDetailID,
		&line.ProductID,
		&line.ComboProductID,
		&line.BarcodeID,
		&line.ProductName,
		&line.Quantity,
		&line.UnitPrice,
		&line.DiscountPercent,
		&line.DiscountAmount,
		&line.TaxID,
		&line.TaxAmount,
		&line.LineTotal,
		&line.CostPrice,
		&line.StockUnitID,
		&line.SellingUnitID,
		&line.SellingUOMMode,
		&line.SellingToStock,
		&line.StockQuantity,
		&serialNumbers,
		&saleReturnQty,
		&refundInvoiceQty,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale detail not found in source sale")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load refundable sale detail: %w", err)
	}
	if len(serialNumbers) > 0 {
		line.SerialNumbers = []string(serialNumbers)
	}
	line.AlreadyReturned = saleReturnQty + refundInvoiceQty
	line.AvailableQuantity = line.Quantity - line.AlreadyReturned
	if line.AvailableQuantity < 0 {
		line.AvailableQuantity = 0
	}
	return &line, nil
}

func (s *SalesService) loadRefundableSaleLineByDetailTx(tx *sql.Tx, companyID, saleDetailID int) (*refundableSaleLine, error) {
	var sourceSaleID int
	err := tx.QueryRow(`
		SELECT sd.sale_id
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE sd.sale_detail_id = $1
		  AND l.company_id = $2
		  AND s.is_deleted = FALSE
	`, saleDetailID, companyID).Scan(&sourceSaleID)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("source sale detail not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to resolve source sale detail: %w", err)
	}
	return s.loadRefundableSaleLineTx(tx, companyID, sourceSaleID, saleDetailID)
}

func nullIntToPtr(value sql.NullInt64) *int {
	if !value.Valid {
		return nil
	}
	v := int(value.Int64)
	return &v
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
		SELECT sd.sale_detail_id, sd.sale_id, sd.product_id, sd.combo_product_id, sd.barcode_id, sd.product_name,
			   COALESCE(pb.barcode, cp.barcode), pb.variant_name,
			   CASE
			     WHEN sd.product_id IS NULL AND sd.combo_product_id IS NOT NULL THEN 'VARIANT'
			     WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH'
			     ELSE 'VARIANT'
			   END AS tracking_type,
			   CASE
			     WHEN sd.product_id IS NULL AND sd.combo_product_id IS NOT NULL THEN FALSE
			     WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE
			     ELSE FALSE
			   END AS is_serialized,
			   CASE WHEN sd.product_id IS NULL AND sd.combo_product_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_virtual_combo,
			   sd.quantity,
			   sd.unit_price, sd.discount_percentage, sd.discount_amount, sd.tax_id,
			   sd.tax_amount, sd.line_total, sd.source_sale_detail_id, sd.serial_numbers, sd.combo_component_tracking, sd.notes,
			   COALESCE(p.name, cp.name) as product_name_from_table
		FROM sale_details sd
		JOIN sales s ON sd.sale_id = s.sale_id
		JOIN locations l ON s.location_id = l.location_id
		LEFT JOIN products p ON sd.product_id = p.product_id
		LEFT JOIN combo_products cp ON sd.combo_product_id = cp.combo_product_id
		LEFT JOIN product_barcodes pb ON pb.barcode_id = sd.barcode_id
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
		var comboTrackingRaw []byte
		var productNameFromTable sql.NullString

		err := rows.Scan(
			&item.SaleDetailID, &item.SaleID, &item.ProductID, &item.ComboProductID, &item.BarcodeID, &item.ProductName,
			&item.Barcode, &item.VariantName, &item.TrackingType, &item.IsSerialized, &item.IsVirtualCombo,
			&item.Quantity, &item.UnitPrice, &item.DiscountPercent, &item.DiscountAmount,
			&item.TaxID, &item.TaxAmount, &item.LineTotal, &item.SourceSaleDetailID, &serialNumbers, &comboTrackingRaw, &item.Notes,
			&productNameFromTable,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale item: %w", err)
		}

		// Handle serial numbers (TEXT[])
		if len(serialNumbers) > 0 {
			item.SerialNumbers = []string(serialNumbers)
		}
		if len(comboTrackingRaw) > 0 {
			if err := json.Unmarshal(comboTrackingRaw, &item.ComboComponentTracking); err != nil {
				return nil, fmt.Errorf("failed to decode combo tracking: %w", err)
			}
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
                SELECT s.sale_id, s.sale_number, s.location_id, s.source_channel, s.transaction_type, s.refund_source_sale_id, rs.sale_number AS refund_source_sale_number,
                       s.customer_id, s.sale_date, s.sale_time,
                       s.subtotal, s.tax_amount, s.discount_amount, s.total_amount, s.paid_amount,
                       s.payment_method_id, s.status, s.pos_status, s.is_quick_sale, COALESCE(s.is_training, FALSE) AS is_training, s.notes,
                       s.created_by, s.updated_by, s.sync_status, s.created_at, s.updated_at,
                       c.name as customer_name, pm.name as payment_method_name
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                LEFT JOIN sales rs ON rs.sale_id = s.refund_source_sale_id
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
	if transactionType := filters["transaction_type"]; transactionType != "" {
		argCount++
		query += fmt.Sprintf(" AND s.transaction_type = $%d", argCount)
		args = append(args, strings.ToUpper(strings.TrimSpace(transactionType)))
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
		var sourceChannel, refundSourceSaleNumber sql.NullString
		var refundSourceSaleID sql.NullInt64

		err := rows.Scan(
			&sale.SaleID, &sale.SaleNumber, &sale.LocationID, &sourceChannel, &sale.TransactionType, &refundSourceSaleID, &refundSourceSaleNumber, &sale.CustomerID,
			&sale.SaleDate, &sale.SaleTime, &sale.Subtotal, &sale.TaxAmount,
			&sale.DiscountAmount, &sale.TotalAmount, &sale.PaidAmount,
			&sale.PaymentMethodID, &sale.Status, &sale.POSStatus, &sale.IsQuickSale,
			&sale.IsTraining, &sale.Notes, &sale.CreatedBy, &sale.UpdatedBy, &sale.SyncStatus,
			&sale.CreatedAt, &sale.UpdatedAt, &customerName, &paymentMethodName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale: %w", err)
		}
		if sourceChannel.Valid {
			sale.SourceChannel = &sourceChannel.String
		}
		if refundSourceSaleID.Valid {
			v := int(refundSourceSaleID.Int64)
			sale.RefundSourceID = &v
		}
		if refundSourceSaleNumber.Valid {
			sale.RefundSourceRef = &refundSourceSaleNumber.String
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
		SELECT q.quote_id, q.quote_number, q.location_id, q.customer_id, q.transaction_type, q.quote_date, q.valid_until,
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
		if transactionType := filters["transaction_type"]; transactionType != "" {
			argCount++
			query += fmt.Sprintf(" AND q.transaction_type = $%d", argCount)
			args = append(args, strings.ToUpper(strings.TrimSpace(transactionType)))
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
			&q.QuoteID, &q.QuoteNumber, &q.LocationID, &q.CustomerID, &q.TransactionType, &q.QuoteDate, &q.ValidUntil,
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
		SELECT q.quote_id, q.quote_number, q.location_id, q.customer_id, q.transaction_type, q.quote_date, q.valid_until,
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
		&quote.QuoteID, &quote.QuoteNumber, &quote.LocationID, &quote.CustomerID, &quote.TransactionType, &quote.QuoteDate, &quote.ValidUntil,
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
	transactionType := normalizeTransactionType(ptrString(req.TransactionType))
	if transactionType == "" {
		transactionType = "B2B"
	}
	if transactionType == "B2B" && req.CustomerID == nil {
		return nil, fmt.Errorf("b2b quotes require customer_id")
	}
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
	comboProductIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
		if item.ComboProductID != nil {
			comboProductIDs = append(comboProductIDs, *item.ComboProductID)
		}
	}
	metaByID, err := fetchProductMeta(tx, companyID, productIDs)
	if err != nil {
		return nil, err
	}
	comboMetaByID, err := fetchComboProductMeta(tx, companyID, comboProductIDs, &locationID)
	if err != nil {
		return nil, err
	}
	taxIDs := make([]int, 0, len(req.Items))
	for _, item := range req.Items {
		var tid *int
		if item.TaxID != nil {
			tid = item.TaxID
		} else if item.ComboProductID != nil {
			meta, ok := comboMetaByID[*item.ComboProductID]
			if !ok {
				return nil, fmt.Errorf("combo product not found")
			}
			tid = meta.TaxID
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
	taxSettings, err := loadCompanyTaxSettings(tx, companyID)
	if err != nil {
		return nil, err
	}

	for _, item := range req.Items {
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ComboProductID != nil {
			meta, ok := comboMetaByID[*item.ComboProductID]
			if !ok {
				return nil, fmt.Errorf("combo product not found")
			}
			effectiveTaxID = meta.TaxID
		} else if item.ProductID != nil {
			meta, ok := metaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}

		taxPercent := 0.0
		if effectiveTaxID != nil {
			pct, ok := taxPctByID[*effectiveTaxID]
			if !ok {
				return nil, fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
			}
			taxPercent = pct
		}
		lineAmounts := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, taxPercent, taxSettings.PriceMode)

		subtotal += lineAmounts.NetAmount
		totalTax += lineAmounts.TaxAmount
		calcs = append(calcs, itemCalc{
			item:         item,
			discountAmt:  lineAmounts.DiscountAmount,
			taxAmt:       lineAmounts.TaxAmount,
			lineTotal:    lineAmounts.NetAmount,
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
		INSERT INTO quotes (quote_number, location_id, customer_id, transaction_type, quote_date, valid_until,
							subtotal, tax_amount, discount_amount, total_amount, status, notes, created_by, updated_by)
		VALUES ($1, $2, $3, $4, CURRENT_DATE, $5, $6, $7, $8, $9, 'DRAFT', $10, $11, $11)
		RETURNING quote_id
	`, quoteNumber, locationID, req.CustomerID, transactionType, validUntilPtr, subtotal, totalTax, req.DiscountAmount, totalAmount, req.Notes, userID).Scan(&quoteID)
	if err != nil {
		return nil, fmt.Errorf("failed to insert quote: %w", err)
	}

	for _, calc := range calcs {
		lineProductName := calc.item.ProductName
		if calc.item.ComboProductID != nil {
			meta := comboMetaByID[*calc.item.ComboProductID]
			lineProductName = &meta.Name
		}
		_, err = tx.Exec(`
			INSERT INTO quote_items (quote_id, product_id, combo_product_id, product_name, quantity, unit_price,
									discount_percentage, discount_amount, tax_id, tax_amount,
									line_total, serial_numbers, notes)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
		`, quoteID, calc.item.ProductID, calc.item.ComboProductID, lineProductName, calc.item.Quantity, calc.item.UnitPrice,
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
	var existingCustomerID sql.NullInt64
	err = tx.QueryRow(`
		SELECT q.discount_amount, q.customer_id
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&existingDiscount, &existingCustomerID)
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
	effectiveCustomerID := existingCustomerID

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
		comboProductIDs := make([]int, 0, len(req.Items))
		for _, item := range req.Items {
			if item.ProductID != nil {
				productIDs = append(productIDs, *item.ProductID)
			}
			if item.ComboProductID != nil {
				comboProductIDs = append(comboProductIDs, *item.ComboProductID)
			}
		}
		metaByID, err := fetchProductMeta(tx, companyID, productIDs)
		if err != nil {
			return err
		}
		comboMetaByID, err := fetchComboProductMeta(tx, companyID, comboProductIDs, nil)
		if err != nil {
			return err
		}
		taxIDs := make([]int, 0, len(req.Items))
		for _, item := range req.Items {
			var tid *int
			if item.TaxID != nil {
				tid = item.TaxID
			} else if item.ComboProductID != nil {
				meta, ok := comboMetaByID[*item.ComboProductID]
				if !ok {
					return fmt.Errorf("combo product not found")
				}
				tid = meta.TaxID
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
		taxSettings, err := loadCompanyTaxSettings(tx, companyID)
		if err != nil {
			return err
		}

		for _, item := range req.Items {
			var effectiveTaxID *int
			if item.TaxID != nil {
				effectiveTaxID = item.TaxID
			} else if item.ComboProductID != nil {
				meta, ok := comboMetaByID[*item.ComboProductID]
				if !ok {
					return fmt.Errorf("combo product not found")
				}
				effectiveTaxID = meta.TaxID
			} else if item.ProductID != nil {
				meta, ok := metaByID[*item.ProductID]
				if !ok {
					return fmt.Errorf("product not found")
				}
				effectiveTaxID = meta.TaxID
			}

			taxPercent := 0.0
			if effectiveTaxID != nil {
				pct, ok := taxPctByID[*effectiveTaxID]
				if !ok {
					return fmt.Errorf("failed to calculate tax: %w", fmt.Errorf("failed to get tax percentage: %w", sql.ErrNoRows))
				}
				taxPercent = pct
			}
			lineAmounts := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, taxPercent, taxSettings.PriceMode)

			subtotal += lineAmounts.NetAmount
			totalTax += lineAmounts.TaxAmount

			lineProductName := item.ProductName
			if item.ComboProductID != nil {
				meta := comboMetaByID[*item.ComboProductID]
				lineProductName = &meta.Name
			}
			_, err = tx.Exec(`
				INSERT INTO quote_items (quote_id, product_id, combo_product_id, product_name, quantity, unit_price,
										discount_percentage, discount_amount, tax_id, tax_amount,
										line_total, serial_numbers, notes)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
			`, quoteID, item.ProductID, item.ComboProductID, lineProductName, item.Quantity, item.UnitPrice,
				item.DiscountPercent, lineAmounts.DiscountAmount, effectiveTaxID, lineAmounts.TaxAmount,
				lineAmounts.NetAmount, pq.Array(item.SerialNumbers), item.Notes)
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
	if req.CustomerID != nil || (req.CustomerID == nil && req.TransactionType != nil) {
		if req.CustomerID != nil {
			effectiveCustomerID = sql.NullInt64{Int64: int64(*req.CustomerID), Valid: *req.CustomerID > 0}
		} else if req.TransactionType != nil && normalizeTransactionType(*req.TransactionType) == "RETAIL" {
			effectiveCustomerID = sql.NullInt64{}
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("customer_id = $%d", argCount))
		if effectiveCustomerID.Valid {
			args = append(args, int(effectiveCustomerID.Int64))
		} else {
			args = append(args, nil)
		}
	}
	if req.TransactionType != nil {
		transactionType := normalizeTransactionType(*req.TransactionType)
		if transactionType == "" {
			return fmt.Errorf("invalid transaction_type")
		}
		if transactionType == "B2B" && !effectiveCustomerID.Valid {
			return fmt.Errorf("b2b quotes require customer_id")
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("transaction_type = $%d", argCount))
		args = append(args, transactionType)
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

func (s *SalesService) ConvertQuoteToSale(quoteID, companyID, userID int, overridePassword *string) (*models.Sale, error) {
	var (
		locationID      int
		quoteNumber     string
		customerID      *int
		transactionType string
		discountAmount  float64
		status          string
		notes           sql.NullString
		convertedSale   sql.NullInt64
	)

	err := s.db.QueryRow(`
		SELECT q.location_id, q.quote_number, q.customer_id, q.transaction_type, q.discount_amount, q.status, q.notes, q.converted_sale_id
		FROM quotes q
		JOIN locations l ON q.location_id = l.location_id
		WHERE q.quote_id = $1 AND l.company_id = $2 AND q.is_deleted = FALSE
	`, quoteID, companyID).Scan(&locationID, &quoteNumber, &customerID, &transactionType, &discountAmount, &status, &notes, &convertedSale)
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
			ComboProductID:  it.ComboProductID,
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
		CustomerID:       customerID,
		Items:            saleItems,
		PaidAmount:       0,
		DiscountAmount:   discountAmount,
		Notes:            &finalNotes,
		OverridePassword: overridePassword,
	}

	idemKey := fmt.Sprintf("quote:%d", quoteID)
	sale, err := s.CreateSaleWithOptions(companyID, locationID, userID, req, &idemKey, CreateSaleOptions{
		SourceChannel:   "QUOTE",
		TransactionType: transactionType,
	})
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
		SELECT qi.quote_item_id, qi.quote_id, qi.product_id, qi.combo_product_id, qi.product_name, qi.quantity,
			   qi.unit_price, qi.discount_percentage, qi.discount_amount, qi.tax_id, qi.tax_amount,
			   qi.line_total, qi.serial_numbers, qi.notes, COALESCE(cp.name, p.name) as product_name_from_table
		FROM quote_items qi
		JOIN quotes q ON qi.quote_id = q.quote_id
		JOIN locations l ON q.location_id = l.location_id
		LEFT JOIN products p ON qi.product_id = p.product_id
		LEFT JOIN combo_products cp ON qi.combo_product_id = cp.combo_product_id
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
			&item.QuoteItemID, &item.QuoteID, &item.ProductID, &item.ComboProductID, &item.ProductName, &item.Quantity,
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
