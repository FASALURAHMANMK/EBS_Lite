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
               COUNT(*) AS transactions
        FROM sales s
        JOIN locations l ON s.location_id = l.location_id
        WHERE l.company_id = $1 AND s.is_deleted = FALSE
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
		if err := rows.Scan(&summary.Period, &summary.TotalSales, &summary.Transactions); err != nil {
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
        WHERE l.company_id = $1 AND s.is_deleted = FALSE
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

	query += " GROUP BY sd.product_id, product_name ORDER BY revenue DESC LIMIT $" + fmt.Sprint(idx)
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
        LEFT JOIN sales s ON c.customer_id = s.customer_id AND s.is_deleted = FALSE
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

// The following report methods are placeholders for future implementation.
// They currently return a not implemented error and will be expanded to
// query the appropriate tables and support data export in future iterations.

// GetItemMovement returns stock movement details for products
func (s *ReportsService) GetItemMovement(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetValuationReport returns inventory valuation information
func (s *ReportsService) GetValuationReport(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetPurchaseVsReturns compares purchases against returns
func (s *ReportsService) GetPurchaseVsReturns(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetSupplierReport aggregates supplier performance metrics
func (s *ReportsService) GetSupplierReport(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetDailyCashReport summarizes daily cash activity
func (s *ReportsService) GetDailyCashReport(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetIncomeExpenseReport returns income vs expense details
func (s *ReportsService) GetIncomeExpenseReport(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetGeneralLedger returns general ledger entries
func (s *ReportsService) GetGeneralLedger(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetTrialBalance returns the trial balance
func (s *ReportsService) GetTrialBalance(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetProfitLoss returns profit and loss information
func (s *ReportsService) GetProfitLoss(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetBalanceSheet returns balance sheet data
func (s *ReportsService) GetBalanceSheet(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetOutstandingReport returns outstanding invoices or payments
func (s *ReportsService) GetOutstandingReport(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}

// GetTopPerformers returns top performing employees or products
func (s *ReportsService) GetTopPerformers(companyID int) ([]map[string]interface{}, error) {
	return nil, fmt.Errorf("not implemented")
}
