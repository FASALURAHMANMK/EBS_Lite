package services

import (
    "database/sql"
    "fmt"

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
    locFilter := ""
    args := []interface{}{companyID}
    if locationID != nil {
        locFilter = " AND %s.location_id = $2"
        args = append(args, *locationID)
    }

    // Credit outstanding from sales (total - paid) for active (not deleted) sales
    {
        q := fmt.Sprintf(`
            SELECT COALESCE(SUM(s.total_amount - s.paid_amount),0)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
        if err := s.db.QueryRow(q, args...).Scan(&metrics.CreditOutstanding); err != nil {
            return nil, fmt.Errorf("failed to get credit outstanding: %w", err)
        }
    }

    // Inventory value = sum(stock.qty * product.cost_price)
    {
        q := fmt.Sprintf(`
            SELECT COALESCE(SUM(st.quantity * COALESCE(p.cost_price,0)),0)
            FROM stock st
            JOIN locations l ON st.location_id = l.location_id
            JOIN products p ON st.product_id = p.product_id
            WHERE l.company_id = $1%s`, fmt.Sprintf(locFilter, "st"))
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
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
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
            WHERE l.company_id = $1%s AND p.purchase_date = CURRENT_DATE AND p.is_deleted = FALSE`, fmt.Sprintf(locFilter, "p"))
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
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
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

    // Totals (all-time aggregates) for convenience in UI when today's values are zero
    {
        // Total sales
        q := fmt.Sprintf(`
            SELECT COALESCE(SUM(s.total_amount),0)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
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
            WHERE l.company_id = $1%s AND p.is_deleted = FALSE`, fmt.Sprintf(locFilter, "p"))
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
            WHERE l.company_id = $1%s AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
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

// GetQuickActionCounts returns counts for quick actions on dashboard
func (s *DashboardService) GetQuickActionCounts(companyID int, locationID *int) (*models.QuickActionCounts, error) {
    counts := &models.QuickActionCounts{}

    // helper for location scoping
    locFilter := ""
    args := []interface{}{companyID}
    if locationID != nil {
        locFilter = " AND %s.location_id = $2"
        args = append(args, *locationID)
    }

    // Sales today
    {
        q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM sales s
            JOIN locations l ON s.location_id = l.location_id
            WHERE l.company_id = $1%s AND s.sale_date = CURRENT_DATE AND s.is_deleted = FALSE`, fmt.Sprintf(locFilter, "s"))
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
            WHERE l.company_id = $1%s AND p.purchase_date = CURRENT_DATE AND p.is_deleted = FALSE`, fmt.Sprintf(locFilter, "p"))
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

    // Payments today (vouchers) — keep for parity where used in UI
    {
        q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM vouchers v
            JOIN locations l ON v.location_id = l.location_id
            WHERE l.company_id = $1%s AND v.date = CURRENT_DATE AND v.type = 'PAYMENT' AND v.is_deleted = FALSE`, func() string {
                if locationID != nil {
                    return " AND v.location_id = $2"
                }
                return ""
            }())
        if err := s.db.QueryRow(q, args...).Scan(&counts.PaymentsToday); err != nil {
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

    // Receipts today
    {
        q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM vouchers v
            JOIN locations l ON v.location_id = l.location_id
            WHERE l.company_id = $1%s AND v.date = CURRENT_DATE AND v.type = 'RECEIPT' AND v.is_deleted = FALSE`, func() string {
                if locationID != nil {
                    return " AND v.location_id = $2"
                }
                return ""
            }())
        if err := s.db.QueryRow(q, args...).Scan(&counts.ReceiptsToday); err != nil {
            return nil, fmt.Errorf("failed to get receipts count: %w", err)
        }
    }

    // Journals today
    {
        q := fmt.Sprintf(`
            SELECT COUNT(*)
            FROM vouchers v
            JOIN locations l ON v.location_id = l.location_id
            WHERE l.company_id = $1%s AND v.date = CURRENT_DATE AND v.type = 'JOURNAL' AND v.is_deleted = FALSE`, func() string {
                if locationID != nil {
                    return " AND v.location_id = $2"
                }
                return ""
            }())
        if err := s.db.QueryRow(q, args...).Scan(&counts.JournalsToday); err != nil {
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
            WHERE l.company_id = $1%s AND st.quantity <= p.reorder_level`, fmt.Sprintf(locFilter, "st"))
        if err := s.db.QueryRow(q, args...).Scan(&counts.LowStockItems); err != nil {
            return nil, fmt.Errorf("failed to get low stock count: %w", err)
        }
    }

    return counts, nil
}
