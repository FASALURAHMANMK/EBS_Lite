package models

import "time"

type Quote struct {
	QuoteID         int         `json:"quote_id" db:"quote_id"`
	QuoteNumber     string      `json:"quote_number" db:"quote_number"`
	LocationID      int         `json:"location_id" db:"location_id"`
	CustomerID      *int        `json:"customer_id,omitempty" db:"customer_id"`
	TransactionType string      `json:"transaction_type" db:"transaction_type"`
	QuoteDate       time.Time   `json:"quote_date" db:"quote_date"`
	ValidUntil      *time.Time  `json:"valid_until,omitempty" db:"valid_until"`
	Subtotal        float64     `json:"subtotal" db:"subtotal"`
	TaxAmount       float64     `json:"tax_amount" db:"tax_amount"`
	DiscountAmount  float64     `json:"discount_amount" db:"discount_amount"`
	TotalAmount     float64     `json:"total_amount" db:"total_amount"`
	Status          string      `json:"status" db:"status"`
	Notes           *string     `json:"notes,omitempty" db:"notes"`
	ConvertedSaleID *int        `json:"converted_sale_id,omitempty" db:"converted_sale_id"`
	ConvertedAt     *time.Time  `json:"converted_at,omitempty" db:"converted_at"`
	ConvertedBy     *int        `json:"converted_by,omitempty" db:"converted_by"`
	CreatedBy       int         `json:"created_by" db:"created_by"`
	UpdatedBy       *int        `json:"updated_by,omitempty" db:"updated_by"`
	Items           []QuoteItem `json:"items,omitempty"`
	Customer        *Customer   `json:"customer,omitempty"`
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
	ComboProductID  *int     `json:"combo_product_id,omitempty" db:"combo_product_id"`
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
	CustomerID      *int                     `json:"customer_id,omitempty"`
	TransactionType *string                  `json:"transaction_type,omitempty"`
	Items           []CreateQuoteItemRequest `json:"items" validate:"required,min=1"`
	DiscountAmount  float64                  `json:"discount_amount"`
	ValidUntil      FlexibleTime             `json:"valid_until"`
	Notes           *string                  `json:"notes,omitempty"`
}

type CreateQuoteItemRequest struct {
	ProductID       *int     `json:"product_id,omitempty"`
	ComboProductID  *int     `json:"combo_product_id,omitempty"`
	ProductName     *string  `json:"product_name,omitempty"`
	Quantity        float64  `json:"quantity" validate:"required,gt=0"`
	UnitPrice       float64  `json:"unit_price" validate:"required,gt=0"`
	DiscountPercent float64  `json:"discount_percentage"`
	TaxID           *int     `json:"tax_id,omitempty"`
	SerialNumbers   []string `json:"serial_numbers,omitempty"`
	Notes           *string  `json:"notes,omitempty"`
}

type UpdateQuoteRequest struct {
	CustomerID      *int                     `json:"customer_id"`
	Status          *string                  `json:"status,omitempty"`
	TransactionType *string                  `json:"transaction_type,omitempty"`
	Notes           *string                  `json:"notes,omitempty"`
	ValidUntil      *FlexibleTime            `json:"valid_until,omitempty"`
	DiscountAmount  *float64                 `json:"discount_amount,omitempty"`
	Items           []CreateQuoteItemRequest `json:"items,omitempty" validate:"omitempty,min=1"`
}

type ShareQuoteRequest struct {
	// Email is optional. The Flutter client shares via share sheets and may not
	// provide an email address.
	Email *string `json:"email,omitempty" validate:"omitempty,email"`
}

type ConvertQuoteToSaleRequest struct {
	OverridePassword *string `json:"override_password,omitempty"`
}

// QuotePrintDataResponse is returned to client apps so they can render
// and print/share quotes locally.
type QuotePrintDataResponse struct {
	Quote   Quote   `json:"quote"`
	Company Company `json:"company"`
}
