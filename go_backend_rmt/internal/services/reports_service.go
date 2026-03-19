package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// ReportsService provides report related operations
// It aggregates data across modules for analytics
// Each method matches a reports endpoint

type ReportsService struct {
	db *sql.DB
}

// NewReportsService creates a new ReportsService
func NewReportsService() *ReportsService {
	return &ReportsService{db: database.GetDB()}
}

// GetSalesSummary returns total sales grouped by period
func (s *ReportsService) GetSalesSummary(companyID int, fromDate, toDate, groupBy string) ([]models.SalesSummary, error) {
	var dateFormat string
	switch groupBy {
	case "day":
		dateFormat = "YYYY-MM-DD"
	case "month":
		dateFormat = "YYYY-MM"
	case "year":
		dateFormat = "YYYY"
	default:
		return nil, fmt.Errorf("invalid group_by")
	}

	query := fmt.Sprintf(`
       SELECT TO_CHAR(s.sale_date, '%s') AS period,
              SUM(s.total_amount) AS total_sales,
              COUNT(*) AS transactions,
              SUM(s.total_amount - s.paid_amount) AS outstanding
       FROM sales s
       JOIN locations l ON s.location_id = l.location_id
       WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
   `, dateFormat)

	args := []interface{}{companyID}
	idx := 2
	if fromDate != "" {
		query += fmt.Sprintf(" AND s.sale_date >= $%d", idx)
		args = append(args, fromDate)
		idx++
	}
	if toDate != "" {
		query += fmt.Sprintf(" AND s.sale_date <= $%d", idx)
		args = append(args, toDate)
		idx++
	}

	query += " GROUP BY period ORDER BY period"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get sales summary: %w", err)
	}
	defer rows.Close()

	var summaries []models.SalesSummary
	for rows.Next() {
		var summary models.SalesSummary
		if err := rows.Scan(&summary.Period, &summary.TotalSales, &summary.Transactions, &summary.Outstanding); err != nil {
			return nil, fmt.Errorf("failed to scan sales summary: %w", err)
		}
		summaries = append(summaries, summary)
	}
	return summaries, nil
}

// GetStockSummary returns stock levels and values
func (s *ReportsService) GetStockSummary(companyID int, locationID, productID *int) ([]models.StockSummary, error) {
	query := `
        SELECT st.product_id, st.location_id, st.quantity,
               st.quantity * COALESCE(p.cost_price,0) AS stock_value
        FROM stock st
        JOIN locations l ON st.location_id = l.location_id
        JOIN products p ON st.product_id = p.product_id
        WHERE l.company_id = $1
    `

	args := []interface{}{companyID}
	idx := 2
	if locationID != nil {
		query += fmt.Sprintf(" AND st.location_id = $%d", idx)
		args = append(args, *locationID)
		idx++
	}
	if productID != nil {
		query += fmt.Sprintf(" AND st.product_id = $%d", idx)
		args = append(args, *productID)
		idx++
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get stock summary: %w", err)
	}
	defer rows.Close()

	var summaries []models.StockSummary
	for rows.Next() {
		var summary models.StockSummary
		if err := rows.Scan(&summary.ProductID, &summary.LocationID, &summary.Quantity, &summary.StockValue); err != nil {
			return nil, fmt.Errorf("failed to scan stock summary: %w", err)
		}
		summaries = append(summaries, summary)
	}
	return summaries, nil
}

// GetTopProducts returns top selling products
func (s *ReportsService) GetTopProducts(companyID int, fromDate, toDate string, limit int) ([]models.TopProduct, error) {
	query := `
        SELECT sd.product_id, COALESCE(p.name, sd.product_name) AS product_name,
               SUM(sd.quantity) AS quantity_sold, SUM(sd.line_total) AS revenue
        FROM sale_details sd
        JOIN sales s ON sd.sale_id = s.sale_id
        JOIN locations l ON s.location_id = l.location_id
        LEFT JOIN products p ON sd.product_id = p.product_id
        WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
    `

	args := []interface{}{companyID}
	idx := 2
	if fromDate != "" {
		query += fmt.Sprintf(" AND s.sale_date >= $%d", idx)
		args = append(args, fromDate)
		idx++
	}
	if toDate != "" {
		query += fmt.Sprintf(" AND s.sale_date <= $%d", idx)
		args = append(args, toDate)
		idx++
	}

	query += " GROUP BY sd.product_id, COALESCE(p.name, sd.product_name) ORDER BY revenue DESC LIMIT $" + fmt.Sprint(idx)
	args = append(args, limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get top products: %w", err)
	}
	defer rows.Close()

	var products []models.TopProduct
	for rows.Next() {
		var p models.TopProduct
		var productID sql.NullInt64
		if err := rows.Scan(&productID, &p.ProductName, &p.QuantitySold, &p.Revenue); err != nil {
			return nil, fmt.Errorf("failed to scan top product: %w", err)
		}
		if productID.Valid {
			id := int(productID.Int64)
			p.ProductID = &id
		}
		products = append(products, p)
	}
	return products, nil
}

// GetCustomerBalances returns outstanding balances per customer
func (s *ReportsService) GetCustomerBalances(companyID int) ([]models.CustomerBalance, error) {
	query := `
        SELECT c.customer_id, c.name,
               COALESCE(SUM(s.total_amount - s.paid_amount),0) AS total_due
        FROM customers c
        LEFT JOIN sales s ON c.customer_id = s.customer_id AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
        WHERE c.company_id = $1 AND c.is_deleted = FALSE
        GROUP BY c.customer_id, c.name
        HAVING COALESCE(SUM(s.total_amount - s.paid_amount),0) > 0
        ORDER BY c.name
    `

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get customer balances: %w", err)
	}
	defer rows.Close()

	var balances []models.CustomerBalance
	for rows.Next() {
		var b models.CustomerBalance
		if err := rows.Scan(&b.CustomerID, &b.Name, &b.TotalDue); err != nil {
			return nil, fmt.Errorf("failed to scan customer balance: %w", err)
		}
		balances = append(balances, b)
	}
	return balances, nil
}

// GetExpensesSummary returns summarized expenses grouped by category and/or period
func (s *ReportsService) GetExpensesSummary(companyID int, groupBy string) ([]models.ExpensesSummary, error) {
	query := `SELECT ec.name AS category, SUM(e.amount) AS total_amount`
	var periodExpr string
	switch groupBy {
	case "day":
		periodExpr = "TO_CHAR(e.expense_date, 'YYYY-MM-DD')"
	case "month":
		periodExpr = "TO_CHAR(e.expense_date, 'YYYY-MM')"
	}
	if periodExpr != "" {
		query += ", " + periodExpr + " AS period"
	}
	query += `
        FROM expenses e
        JOIN locations l ON e.location_id = l.location_id
        JOIN expense_categories ec ON e.category_id = ec.category_id
        WHERE l.company_id = $1 AND e.is_deleted = FALSE
        GROUP BY ec.name`
	if periodExpr != "" {
		query += ", period"
	}
	query += " ORDER BY ec.name"

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses summary: %w", err)
	}
	defer rows.Close()

	var summaries []models.ExpensesSummary
	for rows.Next() {
		var ssum models.ExpensesSummary
		var period sql.NullString
		if periodExpr != "" {
			if err := rows.Scan(&ssum.Category, &ssum.TotalAmount, &period); err != nil {
				return nil, fmt.Errorf("failed to scan expenses summary: %w", err)
			}
			if period.Valid {
				p := period.String
				ssum.Period = &p
			}
		} else {
			if err := rows.Scan(&ssum.Category, &ssum.TotalAmount); err != nil {
				return nil, fmt.Errorf("failed to scan expenses summary: %w", err)
			}
		}
		summaries = append(summaries, ssum)
	}
	return summaries, nil
}

// GetTaxReport aggregates taxable sales and tax amounts by tax
func (s *ReportsService) GetTaxReport(companyID int, fromDate, toDate string) ([]models.TaxReport, error) {
	query := `
        SELECT COALESCE(t.name, 'No Tax') AS tax_name,
               COALESCE(t.percentage, 0) AS tax_rate,
               SUM(sd.line_total) AS taxable_amount,
               SUM(sd.tax_amount) AS tax_amount
        FROM sale_details sd
        JOIN sales s ON sd.sale_id = s.sale_id
        JOIN locations l ON s.location_id = l.location_id
        LEFT JOIN taxes t ON sd.tax_id = t.tax_id
        WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE`

	args := []interface{}{companyID}
	idx := 2
	if fromDate != "" {
		query += fmt.Sprintf(" AND s.sale_date >= $%d", idx)
		args = append(args, fromDate)
		idx++
	}
	if toDate != "" {
		query += fmt.Sprintf(" AND s.sale_date <= $%d", idx)
		args = append(args, toDate)
		idx++
	}

	query += " GROUP BY tax_name, tax_rate ORDER BY tax_name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get tax report: %w", err)
	}
	defer rows.Close()

	var reports []models.TaxReport
	for rows.Next() {
		var tr models.TaxReport
		if err := rows.Scan(&tr.TaxName, &tr.TaxRate, &tr.TaxableAmount, &tr.TaxAmount); err != nil {
			return nil, fmt.Errorf("failed to scan tax report: %w", err)
		}
		reports = append(reports, tr)
	}
	return reports, nil
}

// The following report methods use simplified aggregations intended for MVP reporting.

// GetItemMovement returns stock movement details for products
func (s *ReportsService) GetItemMovement(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		SELECT p.product_id,
		       p.name AS product_name,
		       COALESCE(pu.purchased_qty,0)::float8 AS purchased_qty,
		       COALESCE(pr.purchase_return_qty,0)::float8 AS purchase_return_qty,
		       COALESCE(sa.sold_qty,0)::float8 AS sold_qty,
		       COALESCE(sr.sale_return_qty,0)::float8 AS sale_return_qty,
		       COALESCE(adj.adjustment_qty,0)::float8 AS adjustment_qty,
		       (
		         COALESCE(pu.purchased_qty,0)
		         - COALESCE(pr.purchase_return_qty,0)
		         - COALESCE(sa.sold_qty,0)
		         + COALESCE(sr.sale_return_qty,0)
		         + COALESCE(adj.adjustment_qty,0)
		       )::float8 AS net_movement
		FROM products p
		LEFT JOIN (
			SELECT pd.product_id, COALESCE(SUM(pd.quantity),0)::float8 AS purchased_qty
			FROM purchase_details pd
			JOIN purchases pur ON pur.purchase_id = pd.purchase_id AND pur.is_deleted = FALSE
			JOIN locations l ON l.location_id = pur.location_id
			WHERE l.company_id = $1
			  AND ($2::int IS NULL OR pur.location_id = $2)
			  AND ($3::date IS NULL OR pur.purchase_date >= $3)
			  AND ($4::date IS NULL OR pur.purchase_date <= $4)
			GROUP BY pd.product_id
		) pu ON pu.product_id = p.product_id
		LEFT JOIN (
			SELECT prd.product_id, COALESCE(SUM(prd.quantity),0)::float8 AS purchase_return_qty
			FROM purchase_return_details prd
			JOIN purchase_returns pr ON pr.return_id = prd.return_id AND pr.is_deleted = FALSE
			JOIN locations l ON l.location_id = pr.location_id
			WHERE l.company_id = $1
			  AND ($2::int IS NULL OR pr.location_id = $2)
			  AND ($3::date IS NULL OR pr.return_date >= $3)
			  AND ($4::date IS NULL OR pr.return_date <= $4)
			GROUP BY prd.product_id
		) pr ON pr.product_id = p.product_id
		LEFT JOIN (
			SELECT sd.product_id, COALESCE(SUM(sd.quantity),0)::float8 AS sold_qty
			FROM sale_details sd
			JOIN sales s ON s.sale_id = sd.sale_id AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
			JOIN locations l ON l.location_id = s.location_id
			WHERE l.company_id = $1
			  AND ($2::int IS NULL OR s.location_id = $2)
			  AND ($3::date IS NULL OR s.sale_date >= $3)
			  AND ($4::date IS NULL OR s.sale_date <= $4)
			GROUP BY sd.product_id
		) sa ON sa.product_id = p.product_id
		LEFT JOIN (
			SELECT srd.product_id, COALESCE(SUM(srd.quantity),0)::float8 AS sale_return_qty
			FROM sale_return_details srd
			JOIN sale_returns sr ON sr.return_id = srd.return_id AND sr.is_deleted = FALSE
			JOIN locations l ON l.location_id = sr.location_id
			WHERE l.company_id = $1
			  AND ($2::int IS NULL OR sr.location_id = $2)
			  AND ($3::date IS NULL OR sr.return_date >= $3)
			  AND ($4::date IS NULL OR sr.return_date <= $4)
			GROUP BY srd.product_id
		) sr ON sr.product_id = p.product_id
		LEFT JOIN (
			SELECT sa.product_id, COALESCE(SUM(sa.adjustment),0)::float8 AS adjustment_qty
			FROM stock_adjustments sa
			JOIN locations l ON l.location_id = sa.location_id
			WHERE l.company_id = $1
			  AND ($2::int IS NULL OR sa.location_id = $2)
			  AND ($3::date IS NULL OR sa.created_at::date >= $3)
			  AND ($4::date IS NULL OR sa.created_at::date <= $4)
			GROUP BY sa.product_id
		) adj ON adj.product_id = p.product_id
		WHERE p.company_id = $1 AND p.is_deleted = FALSE
		  AND (
		    COALESCE(pu.purchased_qty,0) <> 0 OR COALESCE(pr.purchase_return_qty,0) <> 0 OR
		    COALESCE(sa.sold_qty,0) <> 0 OR COALESCE(sr.sale_return_qty,0) <> 0 OR
		    COALESCE(adj.adjustment_qty,0) <> 0
		  )
		ORDER BY net_movement DESC, product_name
	`

	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}

	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

// GetValuationReport returns inventory valuation information
func (s *ReportsService) GetValuationReport(companyID int, locationID *int) ([]map[string]interface{}, error) {
	query := `
		SELECT p.product_id,
		       p.name AS product_name,
		       COALESCE(SUM(st.quantity),0)::float8 AS quantity,
		       COALESCE(SUM(st.quantity * COALESCE(p.cost_price,0)),0)::float8 AS stock_value
		FROM products p
		LEFT JOIN stock st ON st.product_id = p.product_id
		LEFT JOIN locations l ON l.location_id = st.location_id
		WHERE p.company_id = $1 AND p.is_deleted = FALSE
		  AND ($2::int IS NULL OR st.location_id = $2)
		GROUP BY p.product_id, p.name
		ORDER BY stock_value DESC, product_name
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	return queryToMaps(s.db, query, companyID, locArg)
}

// GetPurchaseVsReturns compares purchases against returns
func (s *ReportsService) GetPurchaseVsReturns(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		WITH purchases AS (
			SELECT
				COALESCE(SUM(p.total_amount),0)::float8 AS purchases_total,
				COALESCE(SUM(p.total_amount - p.paid_amount),0)::float8 AS purchases_outstanding
			FROM purchases p
			JOIN locations l ON l.location_id = p.location_id
			WHERE l.company_id = $1 AND p.is_deleted = FALSE
			  AND ($2::int IS NULL OR p.location_id = $2)
			  AND ($3::date IS NULL OR p.purchase_date >= $3)
			  AND ($4::date IS NULL OR p.purchase_date <= $4)
		),
		returns AS (
			SELECT
				COALESCE(SUM(pr.total_amount),0)::float8 AS returns_total
			FROM purchase_returns pr
			JOIN locations l ON l.location_id = pr.location_id
			WHERE l.company_id = $1 AND pr.is_deleted = FALSE
			  AND ($2::int IS NULL OR pr.location_id = $2)
			  AND ($3::date IS NULL OR pr.return_date >= $3)
			  AND ($4::date IS NULL OR pr.return_date <= $4)
		)
		SELECT
			purchases.purchases_total,
			returns.returns_total,
			(purchases.purchases_total - returns.returns_total)::float8 AS net_purchases,
			purchases.purchases_outstanding
		FROM purchases, returns
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

// GetSupplierReport aggregates supplier performance metrics
func (s *ReportsService) GetSupplierReport(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		WITH purchases_by_supplier AS (
			SELECT p.supplier_id,
			       COALESCE(SUM(p.total_amount),0)::float8 AS purchases_total,
			       COALESCE(SUM(p.paid_amount),0)::float8 AS purchases_paid,
			       COALESCE(SUM(p.total_amount - p.paid_amount),0)::float8 AS purchases_outstanding
			FROM purchases p
			JOIN locations l ON l.location_id = p.location_id
			WHERE l.company_id = $1 AND p.is_deleted = FALSE
			  AND ($2::int IS NULL OR p.location_id = $2)
			  AND ($3::date IS NULL OR p.purchase_date >= $3)
			  AND ($4::date IS NULL OR p.purchase_date <= $4)
			GROUP BY p.supplier_id
		),
		returns_by_supplier AS (
			SELECT pr.supplier_id,
			       COALESCE(SUM(pr.total_amount),0)::float8 AS returns_total
			FROM purchase_returns pr
			JOIN locations l ON l.location_id = pr.location_id
			WHERE l.company_id = $1 AND pr.is_deleted = FALSE
			  AND ($2::int IS NULL OR pr.location_id = $2)
			  AND ($3::date IS NULL OR pr.return_date >= $3)
			  AND ($4::date IS NULL OR pr.return_date <= $4)
			GROUP BY pr.supplier_id
		)
		SELECT s.supplier_id,
		       s.name AS supplier_name,
		       COALESCE(p.purchases_total,0)::float8 AS purchases_total,
		       COALESCE(p.purchases_paid,0)::float8 AS purchases_paid,
		       COALESCE(p.purchases_outstanding,0)::float8 AS purchases_outstanding,
		       COALESCE(r.returns_total,0)::float8 AS returns_total
		FROM suppliers s
		LEFT JOIN purchases_by_supplier p ON p.supplier_id = s.supplier_id
		LEFT JOIN returns_by_supplier r ON r.supplier_id = s.supplier_id
		WHERE s.company_id = $1
		ORDER BY purchases_total DESC, supplier_name
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

// GetDailyCashReport summarizes daily cash activity
func (s *ReportsService) GetDailyCashReport(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		SELECT cr.date,
		       cr.location_id,
		       cr.opening_balance::float8 AS opening_balance,
		       cr.cash_in::float8 AS cash_in,
		       cr.cash_out::float8 AS cash_out,
		       cr.expected_balance::float8 AS expected_balance,
		       cr.closing_balance::float8 AS closing_balance,
		       cr.variance::float8 AS variance,
		       cr.status
		FROM cash_register cr
		JOIN locations l ON l.location_id = cr.location_id
		WHERE l.company_id = $1
		  AND ($2::int IS NULL OR cr.location_id = $2)
		  AND ($3::date IS NULL OR cr.date >= $3)
		  AND ($4::date IS NULL OR cr.date <= $4)
		ORDER BY cr.date DESC, cr.location_id
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

// GetIncomeExpenseReport returns income vs expense details
func (s *ReportsService) GetIncomeExpenseReport(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		WITH sales_by_day AS (
			SELECT s.sale_date AS day, COALESCE(SUM(s.total_amount),0)::float8 AS sales_total
			FROM sales s
			JOIN locations l ON l.location_id = s.location_id
			WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
			  AND ($2::int IS NULL OR s.location_id = $2)
			  AND ($3::date IS NULL OR s.sale_date >= $3)
			  AND ($4::date IS NULL OR s.sale_date <= $4)
			GROUP BY s.sale_date
		),
		expenses_by_day AS (
			SELECT e.expense_date AS day, COALESCE(SUM(e.amount),0)::float8 AS expenses_total
			FROM expenses e
			JOIN locations l ON l.location_id = e.location_id
			WHERE l.company_id = $1 AND e.is_deleted = FALSE
			  AND ($2::int IS NULL OR e.location_id = $2)
			  AND ($3::date IS NULL OR e.expense_date >= $3)
			  AND ($4::date IS NULL OR e.expense_date <= $4)
			GROUP BY e.expense_date
		)
		SELECT COALESCE(s.day, e.day) AS day,
		       COALESCE(s.sales_total, 0)::float8 AS sales_total,
		       COALESCE(e.expenses_total, 0)::float8 AS expenses_total,
		       (COALESCE(s.sales_total, 0) - COALESCE(e.expenses_total, 0))::float8 AS net_income
		FROM sales_by_day s
		FULL OUTER JOIN expenses_by_day e ON e.day = s.day
		ORDER BY day DESC
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

// GetGeneralLedger returns general ledger entries
func (s *ReportsService) GetGeneralLedger(companyID int, fromDate, toDate string, limit int) ([]map[string]interface{}, error) {
	if limit <= 0 || limit > 5000 {
		limit = 500
	}
	query := `
		SELECT le.entry_id,
		       le.date,
		       le.account_id,
		       coa.account_code,
		       coa.name AS account_name,
		       COALESCE(le.debit,0)::float8 AS debit,
		       COALESCE(le.credit,0)::float8 AS credit,
		       le.description,
		       le.reference,
		       le.voucher_id,
		       le.transaction_type,
		       le.transaction_id
		FROM ledger_entries le
		JOIN chart_of_accounts coa ON le.account_id = coa.account_id
		WHERE le.company_id = $1
		  AND ($2::date IS NULL OR le.date >= $2)
		  AND ($3::date IS NULL OR le.date <= $3)
		ORDER BY le.date DESC, le.entry_id DESC
		LIMIT $4
	`
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, fromArg, toArg, limit)
}

// GetTrialBalance returns the trial balance
func (s *ReportsService) GetTrialBalance(companyID int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		SELECT coa.account_id,
		       coa.account_code,
		       coa.name AS account_name,
		       coa.type AS account_type,
		       COALESCE(SUM(le.debit),0)::float8 AS total_debit,
		       COALESCE(SUM(le.credit),0)::float8 AS total_credit,
		       (COALESCE(SUM(le.debit),0) - COALESCE(SUM(le.credit),0))::float8 AS balance
		FROM chart_of_accounts coa
		LEFT JOIN ledger_entries le
		       ON le.company_id = $1 AND le.account_id = coa.account_id
		      AND ($2::date IS NULL OR le.date >= $2)
		      AND ($3::date IS NULL OR le.date <= $3)
		WHERE coa.company_id = $1
		GROUP BY coa.account_id, coa.account_code, coa.name, coa.type
		ORDER BY coa.account_code, coa.name
	`
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, fromArg, toArg)
}

// GetProfitLoss returns profit and loss information
func (s *ReportsService) GetProfitLoss(companyID int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		WITH pl AS (
			SELECT coa.type AS section,
			       coa.account_code,
			       coa.name AS account_name,
			       CASE
			         WHEN coa.type = 'REVENUE' THEN COALESCE(SUM(le.credit - le.debit),0)
			         WHEN coa.type = 'EXPENSE' THEN COALESCE(SUM(le.debit - le.credit),0)
			         ELSE 0
			       END::float8 AS amount
			FROM chart_of_accounts coa
			LEFT JOIN ledger_entries le
			       ON le.company_id = $1 AND le.account_id = coa.account_id
			      AND ($2::date IS NULL OR le.date >= $2)
			      AND ($3::date IS NULL OR le.date <= $3)
			WHERE coa.company_id = $1 AND coa.type IN ('REVENUE','EXPENSE')
			GROUP BY coa.type, coa.account_code, coa.name
		),
		totals AS (
			SELECT
				COALESCE(SUM(CASE WHEN section = 'REVENUE' THEN amount ELSE 0 END),0)::float8 AS total_revenue,
				COALESCE(SUM(CASE WHEN section = 'EXPENSE' THEN amount ELSE 0 END),0)::float8 AS total_expense
			FROM pl
		)
		SELECT section, account_code, account_name, amount
		FROM pl
		UNION ALL
		SELECT 'TOTAL_REVENUE'::text, NULL::text, NULL::text, totals.total_revenue FROM totals
		UNION ALL
		SELECT 'TOTAL_EXPENSE'::text, NULL::text, NULL::text, totals.total_expense FROM totals
		UNION ALL
		SELECT 'NET_PROFIT'::text, NULL::text, NULL::text, (totals.total_revenue - totals.total_expense)::float8 FROM totals
		ORDER BY section, account_code NULLS LAST
	`
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, fromArg, toArg)
}

// GetBalanceSheet returns balance sheet data
func (s *ReportsService) GetBalanceSheet(companyID int, asOfDate string) ([]map[string]interface{}, error) {
	query := `
		WITH bs AS (
			SELECT coa.type AS section,
			       coa.account_code,
			       coa.name AS account_name,
			       CASE
			         WHEN coa.type = 'ASSET' THEN COALESCE(SUM(le.debit - le.credit),0)
			         WHEN coa.type IN ('LIABILITY','EQUITY') THEN COALESCE(SUM(le.credit - le.debit),0)
			         ELSE 0
			       END::float8 AS amount
			FROM chart_of_accounts coa
			LEFT JOIN ledger_entries le
			       ON le.company_id = $1 AND le.account_id = coa.account_id
			      AND ($2::date IS NULL OR le.date <= $2)
			WHERE coa.company_id = $1 AND coa.type IN ('ASSET','LIABILITY','EQUITY')
			GROUP BY coa.type, coa.account_code, coa.name
		),
		totals AS (
			SELECT
				COALESCE(SUM(CASE WHEN section = 'ASSET' THEN amount ELSE 0 END),0)::float8 AS total_assets,
				COALESCE(SUM(CASE WHEN section = 'LIABILITY' THEN amount ELSE 0 END),0)::float8 AS total_liabilities,
				COALESCE(SUM(CASE WHEN section = 'EQUITY' THEN amount ELSE 0 END),0)::float8 AS total_equity
			FROM bs
		)
		SELECT section, account_code, account_name, amount FROM bs
		UNION ALL
		SELECT 'TOTAL_ASSETS'::text, NULL::text, NULL::text, totals.total_assets FROM totals
		UNION ALL
		SELECT 'TOTAL_LIABILITIES'::text, NULL::text, NULL::text, totals.total_liabilities FROM totals
		UNION ALL
		SELECT 'TOTAL_EQUITY'::text, NULL::text, NULL::text, totals.total_equity FROM totals
		UNION ALL
		SELECT 'ASSETS_MINUS_LIABILITIES_EQUITY'::text, NULL::text, NULL::text, (totals.total_assets - (totals.total_liabilities + totals.total_equity))::float8 FROM totals
		ORDER BY section, account_code NULLS LAST
	`
	var asOfArg interface{}
	if asOfDate != "" {
		asOfArg = asOfDate
	}
	return queryToMaps(s.db, query, companyID, asOfArg)
}

// GetOutstandingReport returns outstanding invoices or payments
func (s *ReportsService) GetOutstandingReport(companyID int, locationID *int) ([]map[string]interface{}, error) {
	query := `
		WITH sales_outstanding AS (
			SELECT COALESCE(SUM(s.total_amount - s.paid_amount),0)::float8 AS amount
			FROM sales s
			JOIN locations l ON l.location_id = s.location_id
			WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
			  AND ($2::int IS NULL OR s.location_id = $2)
		),
		purchase_outstanding AS (
			SELECT COALESCE(SUM(p.total_amount - p.paid_amount),0)::float8 AS amount
			FROM purchases p
			JOIN locations l ON l.location_id = p.location_id
			WHERE l.company_id = $1 AND p.is_deleted = FALSE
			  AND ($2::int IS NULL OR p.location_id = $2)
		)
		SELECT 'sales'::text AS type, sales_outstanding.amount
		FROM sales_outstanding
		UNION ALL
		SELECT 'purchases'::text AS type, purchase_outstanding.amount
		FROM purchase_outstanding
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	return queryToMaps(s.db, query, companyID, locArg)
}

// GetTopPerformers returns top performing employees or products
func (s *ReportsService) GetTopPerformers(companyID int, fromDate, toDate string, limit int) ([]map[string]interface{}, error) {
	if limit <= 0 || limit > 100 {
		limit = 10
	}
	query := `
		SELECT u.user_id,
		       COALESCE(NULLIF(TRIM(u.first_name || ' ' || u.last_name), ''), u.username) AS name,
		       COUNT(*)::int AS transactions,
		       COALESCE(SUM(s.total_amount),0)::float8 AS total_sales
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		JOIN users u ON u.user_id = s.created_by
		WHERE l.company_id = $1 AND s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
		  AND ($2::date IS NULL OR s.sale_date >= $2)
		  AND ($3::date IS NULL OR s.sale_date <= $3)
		GROUP BY u.user_id, name
		ORDER BY total_sales DESC
		LIMIT $4
	`
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, fromArg, toArg, limit)
}

func (s *ReportsService) GetAssetRegisterReport(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		SELECT
			ae.asset_tag,
			ae.item_name,
			COALESCE(ac.name, 'Uncategorized') AS category_name,
			COALESCE(sup.name, '') AS supplier_name,
			ae.location_id,
			ae.acquisition_date,
			ae.in_service_date,
			ae.status,
			ae.source_mode,
			ae.quantity::float8 AS quantity,
			ae.unit_cost::float8 AS unit_cost,
			ae.total_value::float8 AS total_value
		FROM asset_register_entries ae
		LEFT JOIN asset_categories ac ON ac.category_id = ae.category_id
		LEFT JOIN suppliers sup ON sup.supplier_id = ae.supplier_id
		WHERE ae.company_id = $1
		  AND ($2::int IS NULL OR ae.location_id = $2)
		  AND ($3::timestamp IS NULL OR ae.acquisition_date >= $3)
		  AND ($4::timestamp IS NULL OR ae.acquisition_date <= $4)
		ORDER BY ae.acquisition_date DESC, ae.asset_entry_id DESC
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

func (s *ReportsService) GetAssetValueSummary(companyID int, locationID *int) ([]map[string]interface{}, error) {
	query := `
		SELECT
			COALESCE(ac.name, 'Uncategorized') AS category_name,
			ae.status,
			COUNT(*)::int AS item_count,
			COALESCE(SUM(ae.total_value), 0)::float8 AS total_value
		FROM asset_register_entries ae
		LEFT JOIN asset_categories ac ON ac.category_id = ae.category_id
		WHERE ae.company_id = $1
		  AND ($2::int IS NULL OR ae.location_id = $2)
		GROUP BY COALESCE(ac.name, 'Uncategorized'), ae.status
		ORDER BY total_value DESC, category_name
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	return queryToMaps(s.db, query, companyID, locArg)
}

func (s *ReportsService) GetConsumableConsumptionReport(companyID int, locationID *int, fromDate, toDate string) ([]map[string]interface{}, error) {
	query := `
		SELECT
			ce.entry_number,
			ce.item_name,
			COALESCE(cc.name, 'Uncategorized') AS category_name,
			COALESCE(sup.name, '') AS supplier_name,
			ce.location_id,
			ce.consumed_at,
			ce.source_mode,
			ce.quantity::float8 AS quantity,
			ce.unit_cost::float8 AS unit_cost,
			ce.total_cost::float8 AS total_cost
		FROM consumable_entries ce
		LEFT JOIN consumable_categories cc ON cc.category_id = ce.category_id
		LEFT JOIN suppliers sup ON sup.supplier_id = ce.supplier_id
		WHERE ce.company_id = $1
		  AND ($2::int IS NULL OR ce.location_id = $2)
		  AND ($3::timestamp IS NULL OR ce.consumed_at >= $3)
		  AND ($4::timestamp IS NULL OR ce.consumed_at <= $4)
		ORDER BY ce.consumed_at DESC, ce.consumption_id DESC
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	var fromArg interface{}
	if fromDate != "" {
		fromArg = fromDate
	}
	var toArg interface{}
	if toDate != "" {
		toArg = toDate
	}
	return queryToMaps(s.db, query, companyID, locArg, fromArg, toArg)
}

func (s *ReportsService) GetConsumableBalanceReport(companyID int, locationID *int) ([]map[string]interface{}, error) {
	query := `
		SELECT
			p.product_id,
			p.name AS product_name,
			COALESCE(st.location_id, $2::int) AS location_id,
			COALESCE(SUM(st.quantity), 0)::float8 AS quantity,
			COALESCE(SUM(st.quantity * COALESCE(p.cost_price, 0)), 0)::float8 AS stock_value
		FROM products p
		LEFT JOIN stock st ON st.product_id = p.product_id
		WHERE p.company_id = $1
		  AND p.is_deleted = FALSE
		  AND COALESCE(p.item_type, 'PRODUCT') = 'CONSUMABLE'
		  AND ($2::int IS NULL OR st.location_id = $2)
		GROUP BY p.product_id, p.name, COALESCE(st.location_id, $2::int)
		ORDER BY stock_value DESC, product_name
	`
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	}
	return queryToMaps(s.db, query, companyID, locArg)
}

func queryToMaps(db *sql.DB, query string, args ...interface{}) ([]map[string]interface{}, error) {
	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}

	out := []map[string]interface{}{}
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		valPtrs := make([]interface{}, len(cols))
		for i := range vals {
			valPtrs[i] = &vals[i]
		}
		if err := rows.Scan(valPtrs...); err != nil {
			return nil, err
		}

		row := map[string]interface{}{}
		for i, col := range cols {
			switch v := vals[i].(type) {
			case []byte:
				row[col] = string(v)
			default:
				row[col] = v
			}
		}
		out = append(out, row)
	}
	return out, nil
}
