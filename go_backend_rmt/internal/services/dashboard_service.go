package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// DashboardService provides dashboard metrics and quick action counts

type DashboardService struct {
	db *sql.DB
}

// NewDashboardService creates a new DashboardService
func NewDashboardService() *DashboardService {
	return &DashboardService{db: database.GetDB()}
}

// GetMetrics aggregates various metrics for dashboard
func (s *DashboardService) GetMetrics(companyID int, locationID *int) (*models.DashboardMetrics, error) {
	metrics := &models.DashboardMetrics{}

	// helper for location scoping
	locClause := func(alias string) string {
		if locationID == nil {
			return ""
		}
		return fmt.Sprintf(" AND %s.location_id = $2", alias)
	}
	args := []interface{}{companyID}
	if locationID != nil {
		args = append(args, *locationID)
	}

	// Credit outstanding from sales (total - paid) for active (not deleted) sales
	{
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(s.total_amount - s.paid_amount),0)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q, args...).Scan(&metrics.CreditOutstanding); err != nil {
			return nil, fmt.Errorf("failed to get credit outstanding: %w", err)
		}
	}

	// Inventory value follows the company's configured costing method.
	{
		method, err := loadCompanyCostingMethod(s.db, companyID)
		if err != nil {
			return nil, fmt.Errorf("failed to get inventory costing method: %w", err)
		}

		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(sv.quantity * COALESCE(sv.average_cost,0)),0)
            FROM stock_variants sv
            JOIN locations l ON sv.location_id = l.location_id
            WHERE l.company_id = $1%s`, locClause("sv"))
		if method == costingMethodFIFO {
			q = fmt.Sprintf(`
                WITH variant_stock AS (
                    SELECT
                        sv.location_id,
                        sv.barcode_id,
                        COALESCE(sv.quantity, 0)::float8 AS quantity,
                        COALESCE(sv.average_cost, 0)::float8 AS average_cost
                    FROM stock_variants sv
                    JOIN locations l ON sv.location_id = l.location_id
                    WHERE l.company_id = $1%s
                ),
                lot_stock AS (
                    SELECT
                        sl.location_id,
                        sl.barcode_id,
                        COALESCE(SUM(sl.remaining_quantity), 0)::float8 AS lot_quantity,
                        COALESCE(SUM(sl.remaining_quantity * sl.cost_price), 0)::float8 AS lot_value
                    FROM stock_lots sl
                    JOIN locations l ON sl.location_id = l.location_id
                    WHERE l.company_id = $1%s
                    GROUP BY sl.location_id, sl.barcode_id
                ),
                variant_valuation AS (
                    SELECT
                        (
                            COALESCE(ls.lot_value, 0) +
                            ((vs.quantity - COALESCE(ls.lot_quantity, 0)) * vs.average_cost)
                        )::float8 AS stock_value
                    FROM variant_stock vs
                    LEFT JOIN lot_stock ls
                        ON ls.location_id = vs.location_id
                       AND ls.barcode_id = vs.barcode_id
                )
                SELECT COALESCE(SUM(stock_value), 0)::float8
                FROM variant_valuation`, locClause("sv"), locClause("sl"))
		}
		if err := s.db.QueryRow(q, args...).Scan(&metrics.InventoryValue); err != nil {
			return nil, fmt.Errorf("failed to get inventory value: %w", err)
		}
	}

	// Today's sales (use CURRENT_DATE to avoid server/client tz mismatch)
	{
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(s.total_amount),0)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q, args...).Scan(&metrics.TodaySales); err != nil {
			return nil, fmt.Errorf("failed to get today's sales: %w", err)
		}
	}

	// Today's purchases
	{
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(p.total_amount),0)
            FROM purchases p
            JOIN locations l ON p.location_id = l.location_id
            WHERE l.company_id = $1%s AND p.purchase_date = CURRENT_DATE AND p.is_deleted = FALSE`, locClause("p"))
		if err := s.db.QueryRow(q, args...).Scan(&metrics.TodayPurchases); err != nil {
			return nil, fmt.Errorf("failed to get today's purchases: %w", err)
		}
	}

	// Cash In: today's sale_payments + today's collections
	var salesPaid, collectionsAmount float64
	{
		// sum of sale payments for sales at scoped location(s) today
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(sp.base_amount),0)
            FROM sale_payments sp
            JOIN sales s ON sp.sale_id = s.sale_id
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q, args...).Scan(&salesPaid); err != nil {
			return nil, fmt.Errorf("failed to get sales payments: %w", err)
		}
	}
	{
		// collections recorded today
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(c.amount),0)
            FROM collections c
            JOIN customers cu ON c.customer_id = cu.customer_id
            WHERE cu.company_id = $1%s AND c.collection_date = CURRENT_DATE`, func() string {
			if locationID != nil {
				return " AND c.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q, args...).Scan(&collectionsAmount); err != nil {
			return nil, fmt.Errorf("failed to get collections: %w", err)
		}
	}
	metrics.CashIn = salesPaid + collectionsAmount

	// Cash Out: today's supplier payments + today's expenses
	var supplierPayments, expenses float64
	{
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(pay.amount),0)
            FROM payments pay
            JOIN locations l ON pay.location_id = l.location_id
            WHERE l.company_id = $1%s AND pay.payment_date = CURRENT_DATE AND pay.is_deleted = FALSE`, func() string {
			if locationID != nil {
				return " AND pay.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q, args...).Scan(&supplierPayments); err != nil {
			return nil, fmt.Errorf("failed to get supplier payments: %w", err)
		}
	}
	{
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(e.amount),0)
            FROM expenses e
            JOIN locations l ON e.location_id = l.location_id
            WHERE l.company_id = $1%s AND e.expense_date = CURRENT_DATE AND e.is_deleted = FALSE`, func() string {
			if locationID != nil {
				return " AND e.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q, args...).Scan(&expenses); err != nil {
			return nil, fmt.Errorf("failed to get expenses: %w", err)
		}
	}
	metrics.CashOut = supplierPayments + expenses
	metrics.DailyCashSummary = metrics.CashIn - metrics.CashOut

	// Totals (all-time aggregates) for convenience in UI when today's values are zero
	{
		// Total sales
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(s.total_amount),0)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q, args...).Scan(&metrics.TotalSales); err != nil {
			return nil, fmt.Errorf("failed to get total sales: %w", err)
		}
	}
	{
		// Total purchases
		q := fmt.Sprintf(`
            SELECT COALESCE(SUM(p.total_amount),0)
            FROM purchases p
            JOIN locations l ON p.location_id = l.location_id
            WHERE l.company_id = $1%s AND p.is_deleted = FALSE`, locClause("p"))
		if err := s.db.QueryRow(q, args...).Scan(&metrics.TotalPurchases); err != nil {
			return nil, fmt.Errorf("failed to get total purchases: %w", err)
		}
	}
	{
		// Total cash in
		var totalSalesPaid, totalCollections float64
		q1 := fmt.Sprintf(`
            SELECT COALESCE(SUM(sp.base_amount),0)
            FROM sale_payments sp
            JOIN sales s ON sp.sale_id = s.sale_id
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q1, args...).Scan(&totalSalesPaid); err != nil {
			return nil, fmt.Errorf("failed to get total sales payments: %w", err)
		}
		q2 := fmt.Sprintf(`
            SELECT COALESCE(SUM(c.amount),0)
            FROM collections c
            JOIN customers cu ON c.customer_id = cu.customer_id
            WHERE cu.company_id = $1%s`, func() string {
			if locationID != nil {
				return " AND c.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q2, args...).Scan(&totalCollections); err != nil {
			return nil, fmt.Errorf("failed to get total collections: %w", err)
		}
		metrics.CashInTotal = totalSalesPaid + totalCollections
	}
	{
		// Total cash out
		var totalSupplierPayments, totalExpenses float64
		q1 := fmt.Sprintf(`
            SELECT COALESCE(SUM(pay.amount),0)
            FROM payments pay
            JOIN locations l ON pay.location_id = l.location_id
            WHERE l.company_id = $1%s AND pay.is_deleted = FALSE`, func() string {
			if locationID != nil {
				return " AND pay.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q1, args...).Scan(&totalSupplierPayments); err != nil {
			return nil, fmt.Errorf("failed to get total supplier payments: %w", err)
		}
		q2 := fmt.Sprintf(`
            SELECT COALESCE(SUM(e.amount),0)
            FROM expenses e
            JOIN locations l ON e.location_id = l.location_id
            WHERE l.company_id = $1%s AND e.is_deleted = FALSE`, func() string {
			if locationID != nil {
				return " AND e.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q2, args...).Scan(&totalExpenses); err != nil {
			return nil, fmt.Errorf("failed to get total expenses: %w", err)
		}
		metrics.CashOutTotal = totalSupplierPayments + totalExpenses
	}

	return metrics, nil
}

func (s *DashboardService) GetOverview(companyID int, locationID *int) (*models.DashboardOverview, error) {
	metrics, err := s.GetMetrics(companyID, locationID)
	if err != nil {
		return nil, err
	}

	quickActions, err := s.GetQuickActionCounts(companyID, locationID)
	if err != nil {
		return nil, err
	}

	recentTransactions, err := s.GetRecentCashFlowTransactions(companyID, locationID, 10)
	if err != nil {
		return nil, err
	}

	lowStockItems, err := s.GetLowStockItems(companyID, locationID, 8)
	if err != nil {
		return nil, err
	}

	return &models.DashboardOverview{
		Metrics:            metrics,
		QuickActions:       quickActions,
		RecentTransactions: recentTransactions,
		LowStockItems:      lowStockItems,
		RefreshedAt:        time.Now().UTC(),
	}, nil
}

// GetQuickActionCounts returns counts for quick actions on dashboard
func (s *DashboardService) GetQuickActionCounts(companyID int, locationID *int) (*models.QuickActionCounts, error) {
	counts := &models.QuickActionCounts{}

	// helper for location scoping
	locClause := func(alias string) string {
		if locationID == nil {
			return ""
		}
		return fmt.Sprintf(" AND %s.location_id = $2", alias)
	}
	args := []interface{}{companyID}
	if locationID != nil {
		args = append(args, *locationID)
	}

	// Sales today
	{
		q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, locClause("s"))
		if err := s.db.QueryRow(q, args...).Scan(&counts.SalesToday); err != nil {
			return nil, fmt.Errorf("failed to get sales count: %w", err)
		}
	}

	// Purchases today
	{
		q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM purchases p
            JOIN locations l ON p.location_id = l.location_id
            WHERE l.company_id = $1%s AND p.purchase_date = CURRENT_DATE AND p.is_deleted = FALSE`, locClause("p"))
		if err := s.db.QueryRow(q, args...).Scan(&counts.PurchasesToday); err != nil {
			return nil, fmt.Errorf("failed to get purchases count: %w", err)
		}
	}

	// Collections today
	{
		q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM collections c
            JOIN customers cu ON c.customer_id = cu.customer_id
            WHERE cu.company_id = $1%s AND c.collection_date = CURRENT_DATE`, func() string {
			if locationID != nil {
				return " AND c.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q, args...).Scan(&counts.CollectionsToday); err != nil {
			return nil, fmt.Errorf("failed to get collections count: %w", err)
		}
	}

	// Payments today (vouchers) — filter by company via creator user; vouchers have no location
	{
		q := `
            SELECT COUNT(*)
            FROM vouchers v
            JOIN users u ON v.created_by = u.user_id
            WHERE u.company_id = $1 AND v.date = CURRENT_DATE AND v.type = 'PAYMENT' AND v.is_deleted = FALSE`
		if err := s.db.QueryRow(q, companyID).Scan(&counts.PaymentsToday); err != nil {
			return nil, fmt.Errorf("failed to get payments count: %w", err)
		}
	}

	// Expenses today
	{
		q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM expenses e
            JOIN locations l ON e.location_id = l.location_id
            WHERE l.company_id = $1%s AND e.expense_date = CURRENT_DATE AND e.is_deleted = FALSE`, func() string {
			if locationID != nil {
				return " AND e.location_id = $2"
			}
			return ""
		}())
		if err := s.db.QueryRow(q, args...).Scan(&counts.ExpensesToday); err != nil {
			return nil, fmt.Errorf("failed to get expenses count: %w", err)
		}
	}

	// Receipts today (vouchers) — filter by company via creator user
	{
		q := `
            SELECT COUNT(*)
            FROM vouchers v
            JOIN users u ON v.created_by = u.user_id
            WHERE u.company_id = $1 AND v.date = CURRENT_DATE AND v.type = 'RECEIPT' AND v.is_deleted = FALSE`
		if err := s.db.QueryRow(q, companyID).Scan(&counts.ReceiptsToday); err != nil {
			return nil, fmt.Errorf("failed to get receipts count: %w", err)
		}
	}

	// Journals today (vouchers) — filter by company via creator user
	{
		q := `
            SELECT COUNT(*)
            FROM vouchers v
            JOIN users u ON v.created_by = u.user_id
            WHERE u.company_id = $1 AND v.date = CURRENT_DATE AND v.type = 'JOURNAL' AND v.is_deleted = FALSE`
		if err := s.db.QueryRow(q, companyID).Scan(&counts.JournalsToday); err != nil {
			return nil, fmt.Errorf("failed to get journals count: %w", err)
		}
	}

	// Low stock items
	{
		q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM stock st
            JOIN locations l ON st.location_id = l.location_id
            JOIN products p ON st.product_id = p.product_id
            WHERE l.company_id = $1%s
              AND l.is_active = TRUE
              AND p.is_deleted = FALSE
              AND p.is_active = TRUE
              AND COALESCE(p.reorder_level,0) > 0
              AND COALESCE(st.quantity,0) <= COALESCE(p.reorder_level,0)`, locClause("st"))
		if err := s.db.QueryRow(q, args...).Scan(&counts.LowStockItems); err != nil {
			return nil, fmt.Errorf("failed to get low stock count: %w", err)
		}
	}

	return counts, nil
}

func (s *DashboardService) GetRecentCashFlowTransactions(companyID int, locationID *int, limit int) ([]models.DashboardCashFlowTransaction, error) {
	if limit <= 0 {
		limit = 10
	}
	if limit > 25 {
		limit = 25
	}

	locClause := func(alias string) string {
		if locationID == nil {
			return ""
		}
		return fmt.Sprintf(" AND %s.location_id = $2", alias)
	}
	collectionLocClause := ""
	args := []interface{}{companyID}
	if locationID != nil {
		args = append(args, *locationID)
		collectionLocClause = " AND col.location_id = $2"
	}

	query := fmt.Sprintf(`
        SELECT id, transaction_type, entity_name, reference_number, amount, flow_direction, status, occurred_at
        FROM (
            SELECT CONCAT('sale-', s.sale_id)::text AS id,
                   'SALE' AS transaction_type,
                   COALESCE(NULLIF(TRIM(c.name), ''), 'Walk-in Customer') AS entity_name,
                   s.sale_number AS reference_number,
                   COALESCE(s.total_amount, 0)::float8 AS amount,
                   'IN' AS flow_direction,
                   COALESCE(NULLIF(TRIM(s.status), ''), 'COMPLETED') AS status,
                   (s.sale_date::timestamp + COALESCE(s.sale_time, TIME '00:00')) AS occurred_at
            FROM sales s
            LEFT JOIN customers c ON s.customer_id = c.customer_id
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s
              AND s.is_deleted = FALSE

            UNION ALL

            SELECT CONCAT('sale-return-', sr.return_id)::text AS id,
                   'SALE_RETURN' AS transaction_type,
                   COALESCE(NULLIF(TRIM(c.name), ''), 'Walk-in Customer') AS entity_name,
                   sr.return_number AS reference_number,
                   COALESCE(sr.total_amount, 0)::float8 AS amount,
                   'OUT' AS flow_direction,
                   COALESCE(NULLIF(TRIM(sr.status), ''), 'COMPLETED') AS status,
                   COALESCE(sr.updated_at, sr.created_at, sr.return_date::timestamp) AS occurred_at
            FROM sale_returns sr
            LEFT JOIN customers c ON sr.customer_id = c.customer_id
            JOIN locations l ON sr.location_id = l.location_id
            WHERE l.company_id = $1%s
              AND sr.is_deleted = FALSE

            UNION ALL

            SELECT CONCAT('collection-', col.collection_id)::text AS id,
                   'COLLECTION' AS transaction_type,
                   COALESCE(NULLIF(TRIM(cu.name), ''), 'Customer') AS entity_name,
                   col.collection_number AS reference_number,
                   COALESCE(col.amount, 0)::float8 AS amount,
                   'IN' AS flow_direction,
                   'COLLECTED' AS status,
                   COALESCE(col.updated_at, col.created_at, col.collection_date::timestamp) AS occurred_at
            FROM collections col
            JOIN customers cu ON col.customer_id = cu.customer_id
            WHERE cu.company_id = $1%s

            UNION ALL

            SELECT CONCAT('purchase-', p.purchase_id)::text AS id,
                   'PURCHASE' AS transaction_type,
                   COALESCE(NULLIF(TRIM(sup.name), ''), 'Supplier') AS entity_name,
                   p.purchase_number AS reference_number,
                   COALESCE(p.total_amount, 0)::float8 AS amount,
                   'OUT' AS flow_direction,
                   COALESCE(NULLIF(TRIM(p.status), ''), 'COMPLETED') AS status,
                   COALESCE(p.updated_at, p.created_at, p.purchase_date::timestamp) AS occurred_at
            FROM purchases p
            JOIN suppliers sup ON p.supplier_id = sup.supplier_id
            JOIN locations l ON p.location_id = l.location_id
            WHERE l.company_id = $1%s
              AND p.is_deleted = FALSE

            UNION ALL

            SELECT CONCAT('purchase-return-', pr.return_id)::text AS id,
                   'PURCHASE_RETURN' AS transaction_type,
                   COALESCE(NULLIF(TRIM(sup.name), ''), 'Supplier') AS entity_name,
                   pr.return_number AS reference_number,
                   COALESCE(pr.total_amount, 0)::float8 AS amount,
                   'IN' AS flow_direction,
                   COALESCE(NULLIF(TRIM(pr.status), ''), 'COMPLETED') AS status,
                   COALESCE(pr.updated_at, pr.created_at, pr.return_date::timestamp) AS occurred_at
            FROM purchase_returns pr
            JOIN suppliers sup ON pr.supplier_id = sup.supplier_id
            JOIN locations l ON pr.location_id = l.location_id
            WHERE l.company_id = $1%s
              AND pr.is_deleted = FALSE

            UNION ALL

            SELECT CONCAT('expense-', e.expense_id)::text AS id,
                   'EXPENSE' AS transaction_type,
                   COALESCE(NULLIF(TRIM(e.vendor_name), ''), NULLIF(TRIM(ec.name), ''), 'Expense') AS entity_name,
                   e.expense_number AS reference_number,
                   COALESCE(e.amount, 0)::float8 AS amount,
                   'OUT' AS flow_direction,
                   'POSTED' AS status,
                   COALESCE(e.updated_at, e.created_at, e.expense_date::timestamp) AS occurred_at
            FROM expenses e
            JOIN expense_categories ec ON e.category_id = ec.category_id
            JOIN locations l ON e.location_id = l.location_id
            WHERE l.company_id = $1%s
              AND e.is_deleted = FALSE
        ) dashboard_tx
        ORDER BY occurred_at DESC, id DESC
        LIMIT %d`,
		locClause("s"),
		locClause("sr"),
		collectionLocClause,
		locClause("p"),
		locClause("pr"),
		locClause("e"),
		limit,
	)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query recent cash flow transactions: %w", err)
	}
	defer rows.Close()

	var transactions []models.DashboardCashFlowTransaction
	for rows.Next() {
		var item models.DashboardCashFlowTransaction
		if err := rows.Scan(
			&item.ID,
			&item.TransactionType,
			&item.EntityName,
			&item.ReferenceNumber,
			&item.Amount,
			&item.FlowDirection,
			&item.Status,
			&item.OccurredAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan recent cash flow transaction: %w", err)
		}
		transactions = append(transactions, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate recent cash flow transactions: %w", err)
	}

	return transactions, nil
}

func (s *DashboardService) GetLowStockItems(companyID int, locationID *int, limit int) ([]models.DashboardLowStockItem, error) {
	if limit <= 0 {
		limit = 8
	}
	if limit > 20 {
		limit = 20
	}

	locClause := func(alias string) string {
		if locationID == nil {
			return ""
		}
		return fmt.Sprintf(" AND %s.location_id = $2", alias)
	}

	args := []interface{}{companyID}
	if locationID != nil {
		args = append(args, *locationID)
	}

	query := fmt.Sprintf(`
        SELECT st.product_id,
               COALESCE(p.name, '') AS product_name,
               COALESCE(l.name, '') AS location_name,
               COALESCE(st.quantity, 0)::float8 AS current_stock,
               COALESCE(p.reorder_level, 0) AS reorder_level,
               CASE
                   WHEN COALESCE(st.quantity, 0) <= GREATEST(COALESCE(p.reorder_level, 0) / 2.0, 1)
                       THEN 'CRITICAL'
                   ELSE 'LOW'
               END AS severity
        FROM stock st
        JOIN locations l ON st.location_id = l.location_id
        JOIN products p ON st.product_id = p.product_id
        WHERE l.company_id = $1%s
          AND l.is_active = TRUE
          AND p.is_deleted = FALSE
          AND p.is_active = TRUE
          AND COALESCE(p.reorder_level, 0) > 0
          AND COALESCE(st.quantity, 0) <= COALESCE(p.reorder_level, 0)
        ORDER BY CASE
                     WHEN COALESCE(st.quantity, 0) <= GREATEST(COALESCE(p.reorder_level, 0) / 2.0, 1)
                         THEN 0
                     ELSE 1
                 END,
                 COALESCE(st.quantity, 0) ASC,
                 p.name ASC
        LIMIT %d`, locClause("st"), limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query low stock items: %w", err)
	}
	defer rows.Close()

	var items []models.DashboardLowStockItem
	for rows.Next() {
		var item models.DashboardLowStockItem
		if err := rows.Scan(
			&item.ProductID,
			&item.ProductName,
			&item.LocationName,
			&item.CurrentStock,
			&item.ReorderLevel,
			&item.Severity,
		); err != nil {
			return nil, fmt.Errorf("failed to scan low stock item: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate low stock items: %w", err)
	}

	return items, nil
}
