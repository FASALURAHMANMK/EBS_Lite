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
func (s *DashboardService) GetMetrics(companyID, locationID int) (*models.DashboardMetrics, error) {
	metrics := &models.DashboardMetrics{}

	// Credit outstanding from sales
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(s.total_amount - s.paid_amount),0)
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                WHERE l.company_id = $1 AND s.location_id = $2 AND s.is_deleted = FALSE`,
		companyID, locationID).Scan(&metrics.CreditOutstanding); err != nil {
		return nil, fmt.Errorf("failed to get credit outstanding: %w", err)
	}

	// Inventory value
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(st.quantity * COALESCE(p.cost_price,0)),0)
                FROM stock st
                JOIN locations l ON st.location_id = l.location_id
                JOIN products p ON st.product_id = p.product_id
                WHERE l.company_id = $1 AND st.location_id = $2`,
		companyID, locationID).Scan(&metrics.InventoryValue); err != nil {
		return nil, fmt.Errorf("failed to get inventory value: %w", err)
	}

	today := time.Now().Format("2006-01-02")

	// Today's sales
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(s.total_amount),0)
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                WHERE l.company_id = $1 AND s.location_id = $2 AND s.sale_date = $3 AND s.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&metrics.TodaySales); err != nil {
		return nil, fmt.Errorf("failed to get today's sales: %w", err)
	}

	// Today's purchases
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(p.total_amount),0)
                FROM purchases p
                JOIN locations l ON p.location_id = l.location_id
                WHERE l.company_id = $1 AND p.location_id = $2 AND p.purchase_date = $3 AND p.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&metrics.TodayPurchases); err != nil {
		return nil, fmt.Errorf("failed to get today's purchases: %w", err)
	}

	var salesPaid, collectionsAmount float64

	// Cash in from sales
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(s.paid_amount),0)
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                WHERE l.company_id = $1 AND s.location_id = $2 AND s.sale_date = $3 AND s.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&salesPaid); err != nil {
		return nil, fmt.Errorf("failed to get sales payments: %w", err)
	}

	// Cash in from collections
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(c.amount),0)
                FROM collections c
                JOIN customers cu ON c.customer_id = cu.customer_id
                WHERE cu.company_id = $1 AND c.location_id = $2 AND c.collection_date = $3`,
		companyID, locationID, today).Scan(&collectionsAmount); err != nil {
		return nil, fmt.Errorf("failed to get collections: %w", err)
	}

	metrics.CashIn = salesPaid + collectionsAmount

	// Cash out from purchases
	if err := s.db.QueryRow(`
                SELECT COALESCE(SUM(p.paid_amount),0)
                FROM purchases p
                JOIN locations l ON p.location_id = l.location_id
                WHERE l.company_id = $1 AND p.location_id = $2 AND p.purchase_date = $3 AND p.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&metrics.CashOut); err != nil {
		return nil, fmt.Errorf("failed to get cash out: %w", err)
	}

	return metrics, nil
}

// GetQuickActionCounts returns counts for quick actions on dashboard
func (s *DashboardService) GetQuickActionCounts(companyID, locationID int) (*models.QuickActionCounts, error) {
    counts := &models.QuickActionCounts{}
    today := time.Now().Format("2006-01-02")

	// Sales today
	if err := s.db.QueryRow(`
                SELECT COUNT(*)
                FROM sales s
                JOIN locations l ON s.location_id = l.location_id
                WHERE l.company_id = $1 AND s.location_id = $2 AND s.sale_date = $3 AND s.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&counts.SalesToday); err != nil {
		return nil, fmt.Errorf("failed to get sales count: %w", err)
	}

	// Purchases today
	if err := s.db.QueryRow(`
                SELECT COUNT(*)
                FROM purchases p
                JOIN locations l ON p.location_id = l.location_id
                WHERE l.company_id = $1 AND p.location_id = $2 AND p.purchase_date = $3 AND p.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&counts.PurchasesToday); err != nil {
		return nil, fmt.Errorf("failed to get purchases count: %w", err)
	}

	// Collections today
	if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM collections c
               JOIN customers cu ON c.customer_id = cu.customer_id
               WHERE cu.company_id = $1 AND c.location_id = $2 AND c.collection_date = $3`,
		companyID, locationID, today).Scan(&counts.CollectionsToday); err != nil {
		return nil, fmt.Errorf("failed to get collections count: %w", err)
	}

    // Payments today
    if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM vouchers v
               JOIN locations l ON v.location_id = l.location_id
               WHERE l.company_id = $1 AND v.location_id = $2 AND v.date = $3 AND v.type = 'PAYMENT' AND v.is_deleted = FALSE`,
        companyID, locationID, today).Scan(&counts.PaymentsToday); err != nil {
        return nil, fmt.Errorf("failed to get payments count: %w", err)
    }

    // Expenses today
    if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM expenses e
               JOIN locations l ON e.location_id = l.location_id
               WHERE l.company_id = $1 AND e.location_id = $2 AND e.expense_date = $3 AND e.is_deleted = FALSE`,
        companyID, locationID, today).Scan(&counts.ExpensesToday); err != nil {
        return nil, fmt.Errorf("failed to get expenses count: %w", err)
    }

	// Receipts today
	if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM vouchers v
               JOIN locations l ON v.location_id = l.location_id
               WHERE l.company_id = $1 AND v.location_id = $2 AND v.date = $3 AND v.type = 'RECEIPT' AND v.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&counts.ReceiptsToday); err != nil {
		return nil, fmt.Errorf("failed to get receipts count: %w", err)
	}

	// Journals today
	if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM vouchers v
               JOIN locations l ON v.location_id = l.location_id
               WHERE l.company_id = $1 AND v.location_id = $2 AND v.date = $3 AND v.type = 'JOURNAL' AND v.is_deleted = FALSE`,
		companyID, locationID, today).Scan(&counts.JournalsToday); err != nil {
		return nil, fmt.Errorf("failed to get journals count: %w", err)
	}

	// Low stock items
	if err := s.db.QueryRow(`
               SELECT COUNT(*)
               FROM stock st
               JOIN locations l ON st.location_id = l.location_id
               JOIN products p ON st.product_id = p.product_id
               WHERE l.company_id = $1 AND st.location_id = $2 AND st.quantity <= p.reorder_level`,
		companyID, locationID).Scan(&counts.LowStockItems); err != nil {
		return nil, fmt.Errorf("failed to get low stock count: %w", err)
	}

	return counts, nil
}
