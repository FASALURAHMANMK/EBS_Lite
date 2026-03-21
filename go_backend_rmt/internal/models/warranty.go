package models

import "time"

type WarrantyRegistration struct {
	WarrantyID      int            `json:"warranty_id" db:"warranty_id"`
	CompanyID       int            `json:"company_id" db:"company_id"`
	SaleID          int            `json:"sale_id" db:"sale_id"`
	SaleNumber      string         `json:"sale_number" db:"sale_number"`
	CustomerID      *int           `json:"customer_id,omitempty" db:"customer_id"`
	CustomerName    string         `json:"customer_name" db:"customer_name"`
	CustomerPhone   *string        `json:"customer_phone,omitempty" db:"customer_phone"`
	CustomerEmail   *string        `json:"customer_email,omitempty" db:"customer_email"`
	CustomerAddress *string        `json:"customer_address,omitempty" db:"customer_address"`
	Notes           *string        `json:"notes,omitempty" db:"notes"`
	RegisteredAt    time.Time      `json:"registered_at" db:"registered_at"`
	CreatedBy       *int           `json:"created_by,omitempty" db:"created_by"`
	UpdatedBy       *int           `json:"updated_by,omitempty" db:"updated_by"`
	Items           []WarrantyItem `json:"items,omitempty" db:"-"`
	BaseModel
}

type WarrantyItem struct {
	WarrantyItemID       int        `json:"warranty_item_id" db:"warranty_item_id"`
	WarrantyID           int        `json:"warranty_id" db:"warranty_id"`
	SaleDetailID         int        `json:"sale_detail_id" db:"sale_detail_id"`
	ProductID            int        `json:"product_id" db:"product_id"`
	BarcodeID            *int       `json:"barcode_id,omitempty" db:"barcode_id"`
	ProductName          string     `json:"product_name" db:"product_name"`
	Barcode              *string    `json:"barcode,omitempty" db:"barcode"`
	VariantName          *string    `json:"variant_name,omitempty" db:"variant_name"`
	TrackingType         string     `json:"tracking_type" db:"tracking_type"`
	IsSerialized         bool       `json:"is_serialized" db:"is_serialized"`
	Quantity             float64    `json:"quantity" db:"quantity"`
	SerialNumber         *string    `json:"serial_number,omitempty" db:"serial_number"`
	StockLotID           *int       `json:"stock_lot_id,omitempty" db:"stock_lot_id"`
	BatchNumber          *string    `json:"batch_number,omitempty" db:"batch_number"`
	BatchExpiryDate      *time.Time `json:"batch_expiry_date,omitempty" db:"batch_expiry_date"`
	WarrantyPeriodMonths int        `json:"warranty_period_months" db:"warranty_period_months"`
	WarrantyStartDate    time.Time  `json:"warranty_start_date" db:"warranty_start_date"`
	WarrantyEndDate      time.Time  `json:"warranty_end_date" db:"warranty_end_date"`
	Notes                *string    `json:"notes,omitempty" db:"notes"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
}

type WarrantyCustomerSnapshot struct {
	CustomerID *int    `json:"customer_id,omitempty"`
	Name       string  `json:"name"`
	Phone      *string `json:"phone,omitempty"`
	Email      *string `json:"email,omitempty"`
	Address    *string `json:"address,omitempty"`
}

type WarrantyCandidate struct {
	SaleDetailID         int        `json:"sale_detail_id"`
	ProductID            int        `json:"product_id"`
	BarcodeID            *int       `json:"barcode_id,omitempty"`
	ProductName          string     `json:"product_name"`
	Barcode              *string    `json:"barcode,omitempty"`
	VariantName          *string    `json:"variant_name,omitempty"`
	TrackingType         string     `json:"tracking_type"`
	IsSerialized         bool       `json:"is_serialized"`
	Quantity             float64    `json:"quantity"`
	SerialNumber         *string    `json:"serial_number,omitempty"`
	StockLotID           *int       `json:"stock_lot_id,omitempty"`
	BatchNumber          *string    `json:"batch_number,omitempty"`
	BatchExpiryDate      *time.Time `json:"batch_expiry_date,omitempty"`
	WarrantyPeriodMonths int        `json:"warranty_period_months"`
	WarrantyStartDate    time.Time  `json:"warranty_start_date"`
	WarrantyEndDate      time.Time  `json:"warranty_end_date"`
	AlreadyRegistered    bool       `json:"already_registered"`
}

type PrepareWarrantyResponse struct {
	SaleID             int                       `json:"sale_id"`
	SaleNumber         string                    `json:"sale_number"`
	SaleDate           time.Time                 `json:"sale_date"`
	InvoiceCustomer    *WarrantyCustomerSnapshot `json:"invoice_customer,omitempty"`
	EligibleItems      []WarrantyCandidate       `json:"eligible_items"`
	ExistingWarranties []WarrantyRegistration    `json:"existing_warranties,omitempty"`
}

type CreateWarrantyRequest struct {
	SaleNumber      string                      `json:"sale_number" validate:"required"`
	CustomerID      *int                        `json:"customer_id,omitempty"`
	CustomerName    *string                     `json:"customer_name,omitempty"`
	CustomerPhone   *string                     `json:"customer_phone,omitempty"`
	CustomerEmail   *string                     `json:"customer_email,omitempty" validate:"omitempty,email"`
	CustomerAddress *string                     `json:"customer_address,omitempty"`
	Notes           *string                     `json:"notes,omitempty"`
	Items           []CreateWarrantyItemRequest `json:"items" validate:"required,min=1,dive"`
}

type CreateWarrantyItemRequest struct {
	SaleDetailID int     `json:"sale_detail_id" validate:"required"`
	Quantity     float64 `json:"quantity" validate:"required,gt=0"`
	SerialNumber *string `json:"serial_number,omitempty"`
	StockLotID   *int    `json:"stock_lot_id,omitempty"`
}

type WarrantyLookupFilters struct {
	SaleNumber string `json:"sale_number,omitempty"`
	Phone      string `json:"phone,omitempty"`
}

type WarrantyCardDataResponse struct {
	Warranty WarrantyRegistration `json:"warranty"`
	Company  Company              `json:"company"`
}
