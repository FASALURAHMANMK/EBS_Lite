package models

// SalesSummary represents sales totals grouped by a period
// Used by GET /reports/sales-summary endpoint
// Period format depends on group_by parameter (day, month, year)
type SalesSummary struct {
	Period       string  `json:"period"`
	TotalSales   float64 `json:"total_sales"`
	Transactions int     `json:"transactions"`
	Outstanding  float64 `json:"outstanding"`
}

// StockSummary represents stock levels and values per product/location
// Used by GET /reports/stock-summary endpoint
type StockSummary struct {
	ProductID  int     `json:"product_id"`
	LocationID int     `json:"location_id"`
	Quantity   float64 `json:"quantity"`
	StockValue float64 `json:"stock_value"`
}

// TopProduct represents top selling product information
// Used by GET /reports/top-products endpoint
type TopProduct struct {
	ProductID    *int    `json:"product_id,omitempty"`
	ProductName  string  `json:"product_name"`
	QuantitySold float64 `json:"quantity_sold"`
	Revenue      float64 `json:"revenue"`
}

// CustomerBalance represents outstanding balance for a customer
// Used by GET /reports/customer-balances endpoint
type CustomerBalance struct {
	CustomerID int     `json:"customer_id"`
	Name       string  `json:"name"`
	TotalDue   float64 `json:"total_due"`
}

// ExpensesSummary represents summarized expenses grouped by category and/or period
// Used by GET /reports/expenses-summary endpoint
type ExpensesSummary struct {
	Category    string  `json:"category"`
	TotalAmount float64 `json:"total_amount"`
	Period      *string `json:"period,omitempty"`
}
