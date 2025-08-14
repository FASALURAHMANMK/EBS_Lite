package models

import (
	"time"
)

type Sale struct {
	SaleID          int            `json:"sale_id" db:"sale_id"`
	SaleNumber      string         `json:"sale_number" db:"sale_number"`
	LocationID      int            `json:"location_id" db:"location_id"`
	CustomerID      *int           `json:"customer_id,omitempty" db:"customer_id"`
	SaleDate        time.Time      `json:"sale_date" db:"sale_date"`
	SaleTime        *time.Time     `json:"sale_time,omitempty" db:"sale_time"`
	Subtotal        float64        `json:"subtotal" db:"subtotal"`
	TaxAmount       float64        `json:"tax_amount" db:"tax_amount"`
	DiscountAmount  float64        `json:"discount_amount" db:"discount_amount"`
	TotalAmount     float64        `json:"total_amount" db:"total_amount"`
	PaidAmount      float64        `json:"paid_amount" db:"paid_amount"`
	PaymentMethodID *int           `json:"payment_method_id,omitempty" db:"payment_method_id"`
	Status          string         `json:"status" db:"status"`
	POSStatus       string         `json:"pos_status" db:"pos_status"`
	IsQuickSale     bool           `json:"is_quick_sale" db:"is_quick_sale"`
	Notes           *string        `json:"notes,omitempty" db:"notes"`
	CreatedBy       int            `json:"created_by" db:"created_by"`
	UpdatedBy       *int           `json:"updated_by,omitempty" db:"updated_by"`
	Items           []SaleDetail   `json:"items,omitempty"`
	Customer        *Customer      `json:"customer,omitempty"`
	PaymentMethod   *PaymentMethod `json:"payment_method,omitempty"`
	SyncModel
}

type SaleDetail struct {
	SaleDetailID    int      `json:"sale_detail_id" db:"sale_detail_id"`
	SaleID          int      `json:"sale_id" db:"sale_id"`
	ProductID       *int     `json:"product_id,omitempty" db:"product_id"`
	ProductName     *string  `json:"product_name,omitempty" db:"product_name"`
	Quantity        float64  `json:"quantity" db:"quantity"`
	UnitPrice       float64  `json:"unit_price" db:"unit_price"`
	DiscountPercent float64  `json:"discount_percentage" db:"discount_percentage"`
	DiscountAmount  float64  `json:"discount_amount" db:"discount_amount"`
	TaxID           *int     `json:"tax_id,omitempty" db:"tax_id"`
	TaxAmount       float64  `json:"tax_amount" db:"tax_amount"`
	LineTotal       float64  `json:"line_total" db:"line_total"`
	SerialNumbers   []string `json:"serial_numbers,omitempty" db:"serial_numbers"`
	Notes           *string  `json:"notes,omitempty" db:"notes"`
	Product         *Product `json:"product,omitempty"`
}

type SaleReturn struct {
	ReturnID     int                `json:"return_id" db:"return_id"`
	ReturnNumber string             `json:"return_number" db:"return_number"`
	SaleID       int                `json:"sale_id" db:"sale_id"`
	LocationID   int                `json:"location_id" db:"location_id"`
	CustomerID   *int               `json:"customer_id,omitempty" db:"customer_id"`
	ReturnDate   time.Time          `json:"return_date" db:"return_date"`
	TotalAmount  float64            `json:"total_amount" db:"total_amount"`
	Reason       *string            `json:"reason,omitempty" db:"reason"`
	Status       string             `json:"status" db:"status"`
	CreatedBy    int                `json:"created_by" db:"created_by"`
	Items        []SaleReturnDetail `json:"items,omitempty"`
	SyncModel
}

type SaleReturnDetail struct {
	ReturnDetailID int     `json:"return_detail_id" db:"return_detail_id"`
	ReturnID       int     `json:"return_id" db:"return_id"`
	SaleDetailID   *int    `json:"sale_detail_id,omitempty" db:"sale_detail_id"`
	ProductID      *int    `json:"product_id,omitempty" db:"product_id"`
	Quantity       float64 `json:"quantity" db:"quantity"`
	UnitPrice      float64 `json:"unit_price" db:"unit_price"`
	LineTotal      float64 `json:"line_total" db:"line_total"`
}

type PaymentMethod struct {
	MethodID            int    `json:"method_id" db:"method_id"`
	CompanyID           *int   `json:"company_id,omitempty" db:"company_id"`
	Name                string `json:"name" db:"name"`
	Type                string `json:"type" db:"type"`
	ExternalIntegration *JSONB `json:"external_integration,omitempty" db:"external_integration"`
	IsActive            bool   `json:"is_active" db:"is_active"`
}

// Request/Response Models
type CreateSaleRequest struct {
	CustomerID      *int                      `json:"customer_id,omitempty"`
	Items           []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
	PaymentMethodID *int                      `json:"payment_method_id,omitempty"`
	DiscountAmount  float64                   `json:"discount_amount"`
	Notes           *string                   `json:"notes,omitempty"`
}

type CreateSaleDetailRequest struct {
	ProductID       *int     `json:"product_id,omitempty"`
	ProductName     *string  `json:"product_name,omitempty"` // For quick sales
	Quantity        float64  `json:"quantity" validate:"required,gt=0"`
	UnitPrice       float64  `json:"unit_price" validate:"required,gt=0"`
	DiscountPercent float64  `json:"discount_percentage"`
	TaxID           *int     `json:"tax_id,omitempty"`
	SerialNumbers   []string `json:"serial_numbers,omitempty"`
	Notes           *string  `json:"notes,omitempty"`
}

type UpdateSaleRequest struct {
	PaymentMethodID *int    `json:"payment_method_id,omitempty"`
	Notes           *string `json:"notes,omitempty"`
	Status          *string `json:"status,omitempty"`
}

type CreateSaleReturnRequest struct {
	SaleID int                           `json:"sale_id" validate:"required"`
	Items  []CreateSaleReturnItemRequest `json:"items" validate:"required,min=1"`
	Reason *string                       `json:"reason,omitempty"`
}

type CreateSaleReturnItemRequest struct {
	ProductID int     `json:"product_id" validate:"required"`
	Quantity  float64 `json:"quantity" validate:"required,gt=0"`
	UnitPrice float64 `json:"unit_price" validate:"required,gt=0"`
}

type QuickSaleRequest struct {
	Items []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
}

type POSCheckoutRequest struct {
	CustomerID      *int                      `json:"customer_id,omitempty"`
	Items           []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
	PaymentMethodID *int                      `json:"payment_method_id,omitempty"`
	DiscountAmount  float64                   `json:"discount_amount"`
}

type POSPrintRequest struct {
	InvoiceID int `json:"invoice_id" validate:"required"`
}

type POSProductResponse struct {
	ProductID    int     `json:"product_id"`
	Name         string  `json:"name"`
	Price        float64 `json:"price"`
	Stock        float64 `json:"stock"`
	Barcode      *string `json:"barcode,omitempty"`
	CategoryName *string `json:"category_name,omitempty"`
}

type POSCustomerResponse struct {
	CustomerID int     `json:"customer_id"`
	Name       string  `json:"name"`
	Phone      *string `json:"phone,omitempty"`
	Email      *string `json:"email,omitempty"`
}

type SalesSummaryResponse struct {
	TotalSales        float64 `json:"total_sales"`
	TotalTransactions int     `json:"total_transactions"`
	AverageTicket     float64 `json:"average_ticket"`
	TopProducts       []struct {
		ProductID   int     `json:"product_id"`
		ProductName string  `json:"product_name"`
		Quantity    float64 `json:"quantity"`
		Revenue     float64 `json:"revenue"`
	} `json:"top_products"`
}

// Quote represents a sales quote that can be shared with customers before
// converting to an actual sale. It includes status tracking and basic sharing
// metadata.
type Quote struct {
	QuoteID     int           `json:"quote_id" db:"quote_id"`
	QuoteNumber string        `json:"quote_number" db:"quote_number"`
	LocationID  int           `json:"location_id" db:"location_id"`
	CustomerID  *int          `json:"customer_id,omitempty" db:"customer_id"`
	QuoteDate   time.Time     `json:"quote_date" db:"quote_date"`
	TotalAmount float64       `json:"total_amount" db:"total_amount"`
	Status      string        `json:"status" db:"status"`
	ShareToken  *string       `json:"share_token,omitempty" db:"share_token"`
	SharedWith  *string       `json:"shared_with,omitempty" db:"shared_with"`
	CreatedBy   int           `json:"created_by" db:"created_by"`
	UpdatedBy   *int          `json:"updated_by,omitempty" db:"updated_by"`
	Items       []QuoteDetail `json:"items,omitempty"`
	Customer    *Customer     `json:"customer,omitempty"`
	SyncModel
}

// QuoteDetail represents a line item within a quote.
type QuoteDetail struct {
	QuoteDetailID   int     `json:"quote_detail_id" db:"quote_detail_id"`
	QuoteID         int     `json:"quote_id" db:"quote_id"`
	ProductID       *int    `json:"product_id,omitempty" db:"product_id"`
	ProductName     *string `json:"product_name,omitempty" db:"product_name"`
	Quantity        float64 `json:"quantity" db:"quantity"`
	UnitPrice       float64 `json:"unit_price" db:"unit_price"`
	DiscountPercent float64 `json:"discount_percentage" db:"discount_percentage"`
	TaxID           *int    `json:"tax_id,omitempty" db:"tax_id"`
	TaxAmount       float64 `json:"tax_amount" db:"tax_amount"`
	LineTotal       float64 `json:"line_total" db:"line_total"`
}

// CreateQuoteRequest is used when creating a new quote.
type CreateQuoteRequest struct {
	CustomerID *int                      `json:"customer_id,omitempty"`
	Items      []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
	Notes      *string                   `json:"notes,omitempty"`
}

// UpdateQuoteRequest is used for updating existing quotes.
type UpdateQuoteRequest struct {
	Status *string `json:"status,omitempty"`
	Notes  *string `json:"notes,omitempty"`
}

// ShareQuoteRequest carries information needed to share a quote with a
// customer. The email is stored for reference when generating share links.
type ShareQuoteRequest struct {
	Email string `json:"email" validate:"required,email"`
}
