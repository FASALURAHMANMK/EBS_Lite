package models

// DashboardMetrics represents summarized metrics for dashboard
// includes credit outstanding, inventory value, today's totals and cash summary

type DashboardMetrics struct {
    CreditOutstanding float64 `json:"credit_outstanding"`
    InventoryValue    float64 `json:"inventory_value"`
    TodaySales        float64 `json:"today_sales"`
    TodayPurchases    float64 `json:"today_purchases"`
    CashIn            float64 `json:"cash_in"`
    CashOut           float64 `json:"cash_out"`
    // Optional total aggregates for clients that want non-daily views
    TotalSales        float64 `json:"total_sales,omitempty"`
    TotalPurchases    float64 `json:"total_purchases,omitempty"`
    CashInTotal       float64 `json:"cash_in_total,omitempty"`
    CashOutTotal      float64 `json:"cash_out_total,omitempty"`
}

// QuickActionCounts represents counts for quick dashboard actions

type QuickActionCounts struct {
    SalesToday       int `json:"sales_today"`
    PurchasesToday   int `json:"purchases_today"`
    CollectionsToday int `json:"collections_today"`
    ExpensesToday    int `json:"expenses_today"`
    PaymentsToday    int `json:"payments_today"`
    ReceiptsToday    int `json:"receipts_today"`
    JournalsToday    int `json:"journals_today"`
    LowStockItems    int `json:"low_stock_items"`
}
