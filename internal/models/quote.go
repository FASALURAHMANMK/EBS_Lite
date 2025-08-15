package models

import "time"

type Quote struct {
	QuoteID        int         `json:"quote_id" db:"quote_id"`
	QuoteNumber    string      `json:"quote_number" db:"quote_number"`
	LocationID     int         `json:"location_id" db:"location_id"`
	CustomerID     *int        `json:"customer_id,omitempty" db:"customer_id"`
	QuoteDate      time.Time   `json:"quote_date" db:"quote_date"`
	ValidUntil     *time.Time  `json:"valid_until,omitempty" db:"valid_until"`
	Subtotal       float64     `json:"subtotal" db:"subtotal"`
	TaxAmount      float64     `json:"tax_amount" db:"tax_amount"`
	DiscountAmount float64     `json:"discount_amount" db:"discount_amount"`
	TotalAmount    float64     `json:"total_amount" db:"total_amount"`
	Status         string      `json:"status" db:"status"`
	Notes          *string     `json:"notes,omitempty" db:"notes"`
	CreatedBy      int         `json:"created_by" db:"created_by"`
	UpdatedBy      *int        `json:"updated_by,omitempty" db:"updated_by"`
	Items          []QuoteItem `json:"items,omitempty"`
	Customer       *Customer   `json:"customer,omitempty"`
	SyncModel
}

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

type QuoteItem struct {
	QuoteItemID     int      `json:"quote_item_id" db:"quote_item_id"`
	QuoteID         int      `json:"quote_id" db:"quote_id"`
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

type CreateQuoteRequest struct {
	CustomerID     *int                     `json:"customer_id,omitempty"`
	Items          []CreateQuoteItemRequest `json:"items" validate:"required,min=1"`
	DiscountAmount float64                  `json:"discount_amount"`
	ValidUntil     time.Time                `json:"valid_until"`
	Notes          *string                  `json:"notes,omitempty"`
}

type CreateQuoteItemRequest struct {
	ProductID       *int     `json:"product_id,omitempty"`
	ProductName     *string  `json:"product_name,omitempty"`
	Quantity        float64  `json:"quantity" validate:"required,gt=0"`
	UnitPrice       float64  `json:"unit_price" validate:"required,gt=0"`
	DiscountPercent float64  `json:"discount_percentage"`
	TaxID           *int     `json:"tax_id,omitempty"`
	SerialNumbers   []string `json:"serial_numbers,omitempty"`
	Notes           *string  `json:"notes,omitempty"`
}

type UpdateQuoteRequest struct {
	Status     *string    `json:"status,omitempty"`
	Notes      *string    `json:"notes,omitempty"`
	ValidUntil *time.Time `json:"valid_until,omitempty"`
}

type ShareQuoteRequest struct {
	Email string `json:"email" validate:"required,email"`
}
