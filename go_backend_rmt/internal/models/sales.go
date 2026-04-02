package models

import (
	"time"
)

type Sale struct {
	SaleID          int                `json:"sale_id" db:"sale_id"`
	SaleNumber      string             `json:"sale_number" db:"sale_number"`
	LocationID      int                `json:"location_id" db:"location_id"`
	CustomerID      *int               `json:"customer_id,omitempty" db:"customer_id"`
	SaleDate        time.Time          `json:"sale_date" db:"sale_date"`
	SaleTime        *time.Time         `json:"sale_time,omitempty" db:"sale_time"`
	Subtotal        float64            `json:"subtotal" db:"subtotal"`
	TaxAmount       float64            `json:"tax_amount" db:"tax_amount"`
	TaxBreakdown    []TaxBreakdownLine `json:"tax_breakdown,omitempty"`
	DiscountAmount  float64            `json:"discount_amount" db:"discount_amount"`
	TotalAmount     float64            `json:"total_amount" db:"total_amount"`
	PaidAmount      float64            `json:"paid_amount" db:"paid_amount"`
	PaymentMethodID *int               `json:"payment_method_id,omitempty" db:"payment_method_id"`
	Status          string             `json:"status" db:"status"`
	POSStatus       string             `json:"pos_status" db:"pos_status"`
	IsQuickSale     bool               `json:"is_quick_sale" db:"is_quick_sale"`
	IsTraining      bool               `json:"is_training" db:"is_training"`
	Notes           *string            `json:"notes,omitempty" db:"notes"`
	CreatedBy       int                `json:"created_by" db:"created_by"`
	UpdatedBy       *int               `json:"updated_by,omitempty" db:"updated_by"`
	Items           []SaleDetail       `json:"items,omitempty"`
	Customer        *Customer          `json:"customer,omitempty"`
	PaymentMethod   *PaymentMethod     `json:"payment_method,omitempty"`
	SyncModel
}

type SaleDetail struct {
	SaleDetailID           int                           `json:"sale_detail_id" db:"sale_detail_id"`
	SaleID                 int                           `json:"sale_id" db:"sale_id"`
	ProductID              *int                          `json:"product_id,omitempty" db:"product_id"`
	ComboProductID         *int                          `json:"combo_product_id,omitempty" db:"combo_product_id"`
	BarcodeID              *int                          `json:"barcode_id,omitempty" db:"barcode_id"`
	ProductName            *string                       `json:"product_name,omitempty" db:"product_name"`
	Barcode                *string                       `json:"barcode,omitempty" db:"barcode"`
	VariantName            *string                       `json:"variant_name,omitempty" db:"variant_name"`
	IsVirtualCombo         bool                          `json:"is_virtual_combo" db:"-"`
	TrackingType           string                        `json:"tracking_type,omitempty" db:"tracking_type"`
	IsSerialized           bool                          `json:"is_serialized" db:"is_serialized"`
	Quantity               float64                       `json:"quantity" db:"quantity"`
	UnitPrice              float64                       `json:"unit_price" db:"unit_price"`
	DiscountPercent        float64                       `json:"discount_percentage" db:"discount_percentage"`
	DiscountAmount         float64                       `json:"discount_amount" db:"discount_amount"`
	TaxID                  *int                          `json:"tax_id,omitempty" db:"tax_id"`
	TaxAmount              float64                       `json:"tax_amount" db:"tax_amount"`
	LineTotal              float64                       `json:"line_total" db:"line_total"`
	SerialNumbers          []string                      `json:"serial_numbers,omitempty" db:"serial_numbers"`
	ComboComponentTracking []ComboComponentTrackingInput `json:"combo_component_tracking,omitempty" db:"-"`
	Notes                  *string                       `json:"notes,omitempty" db:"notes"`
	Product                *Product                      `json:"product,omitempty"`
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
	Sale         *Sale              `json:"sale,omitempty"`
	Customer     *Customer          `json:"customer,omitempty"`
	SyncModel
}

type SaleReturnDetail struct {
	ReturnDetailID int     `json:"return_detail_id" db:"return_detail_id"`
	ReturnID       int     `json:"return_id" db:"return_id"`
	SaleDetailID   *int    `json:"sale_detail_id,omitempty" db:"sale_detail_id"`
	ProductID      *int    `json:"product_id,omitempty" db:"product_id"`
	ComboProductID *int    `json:"combo_product_id,omitempty" db:"combo_product_id"`
	BarcodeID      *int    `json:"barcode_id,omitempty" db:"barcode_id"`
	ProductName    *string `json:"product_name,omitempty" db:"product_name"`
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
	// SaleNumber is optional. When provided (e.g. offline-first POS), the server
	// will persist it as-is instead of allocating from numbering sequences.
	SaleNumber       *string                   `json:"sale_number,omitempty"`
	CustomerID       *int                      `json:"customer_id,omitempty"`
	Items            []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
	PaymentMethodID  *int                      `json:"payment_method_id,omitempty"`
	PaidAmount       float64                   `json:"paid_amount" validate:"gte=0"`
	DiscountAmount   float64                   `json:"discount_amount"`
	Notes            *string                   `json:"notes,omitempty"`
	OverridePassword *string                   `json:"override_password,omitempty"`
}

type CreateSaleDetailRequest struct {
	ProductID              *int                           `json:"product_id,omitempty"`
	ComboProductID         *int                           `json:"combo_product_id,omitempty"`
	BarcodeID              *int                           `json:"barcode_id,omitempty"`
	ProductName            *string                        `json:"product_name,omitempty"` // For quick sales
	Quantity               float64                        `json:"quantity" validate:"required,gt=0"`
	UnitPrice              float64                        `json:"unit_price" validate:"required,gt=0"`
	DiscountPercent        float64                        `json:"discount_percentage"`
	TaxID                  *int                           `json:"tax_id,omitempty"`
	SerialNumbers          []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations       []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	ComboComponentTracking []ComboComponentTrackingInput  `json:"combo_component_tracking,omitempty"`
	Notes                  *string                        `json:"notes,omitempty"`
}

type ComboComponentTrackingInput struct {
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        int                            `json:"barcode_id" validate:"required"`
	ProductName      *string                        `json:"product_name,omitempty"`
	VariantName      *string                        `json:"variant_name,omitempty"`
	QuantityPerCombo *float64                       `json:"quantity_per_combo,omitempty"`
	TrackingType     *string                        `json:"tracking_type,omitempty"`
	IsSerialized     *bool                          `json:"is_serialized,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
}

type UpdateSaleRequest struct {
	PaymentMethodID *int    `json:"payment_method_id,omitempty"`
	Notes           *string `json:"notes,omitempty"`
	Status          *string `json:"status,omitempty"`
}

type CreateSaleReturnRequest struct {
	SaleID           int                           `json:"sale_id" validate:"required"`
	Items            []CreateSaleReturnItemRequest `json:"items" validate:"required,min=1"`
	Reason           *string                       `json:"reason,omitempty" validate:"required"`
	OverridePassword *string                       `json:"override_password,omitempty"`
}

type CreateSaleReturnItemRequest struct {
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	Quantity         float64                        `json:"quantity" validate:"required,gt=0"`
	UnitPrice        float64                        `json:"unit_price" validate:"required,gt=0"`
	BatchNumber      *string                        `json:"batch_number,omitempty"`
	ExpiryDate       *time.Time                     `json:"expiry_date,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
}

type QuickSaleRequest struct {
	Items []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
}

type POSCheckoutRequest struct {
	SaleID *int `json:"sale_id,omitempty"`
	// SaleNumber is optional. When provided (e.g. offline checkout), the server
	// will persist it instead of allocating a new number.
	SaleNumber                 *string                   `json:"sale_number,omitempty"`
	CustomerID                 *int                      `json:"customer_id,omitempty"`
	Items                      []CreateSaleDetailRequest `json:"items" validate:"required,min=1"`
	PaymentMethodID            *int                      `json:"payment_method_id,omitempty"`
	DiscountAmount             float64                   `json:"discount_amount"`
	PaidAmount                 float64                   `json:"paid_amount" validate:"gte=0"`
	Payments                   []POSPaymentLine          `json:"payments,omitempty"`
	RedeemPoints               *float64                  `json:"redeem_points,omitempty"`
	CouponCode                 *string                   `json:"coupon_code,omitempty"`
	AutoFillRaffleCustomerData *bool                     `json:"auto_fill_raffle_customer_data,omitempty"`
	ManagerOverrideToken       *string                   `json:"manager_override_token,omitempty"`
	OverrideReason             *string                   `json:"override_reason,omitempty"`
	OverridePassword           *string                   `json:"override_password,omitempty"`
}

type POSPrintRequest struct {
	InvoiceID  *int    `json:"invoice_id,omitempty"`
	SaleNumber *string `json:"sale_number,omitempty"`
}

type POSVoidRequest struct {
	Reason               string  `json:"reason" validate:"required"`
	ManagerOverrideToken *string `json:"manager_override_token,omitempty"`
}

// POSPrintDataResponse is returned to client apps so they can render
// and print invoices locally.
type POSPrintDataResponse struct {
	Sale          Sale           `json:"sale"`
	Company       Company        `json:"company"`
	RaffleCoupons []RaffleCoupon `json:"raffle_coupons,omitempty"`
}

type POSProductResponse struct {
	ProductID             int     `json:"product_id"`
	ComboProductID        *int    `json:"combo_product_id,omitempty"`
	BarcodeID             int     `json:"barcode_id"`
	Name                  string  `json:"name"`
	Price                 float64 `json:"price"`
	Stock                 float64 `json:"stock"`
	Barcode               *string `json:"barcode,omitempty"`
	VariantName           *string `json:"variant_name,omitempty"`
	CategoryName          *string `json:"category_name,omitempty"`
	PrimaryStorage        *string `json:"primary_storage,omitempty"`
	IsVirtualCombo        bool    `json:"is_virtual_combo"`
	IsWeighable           bool    `json:"is_weighable"`
	TrackingType          string  `json:"tracking_type"`
	IsSerialized          bool    `json:"is_serialized"`
	SellingUOMMode        string  `json:"selling_uom_mode"`
	SellingUnitID         *int    `json:"selling_unit_id,omitempty"`
	SellingUnitName       *string `json:"selling_unit_name,omitempty"`
	SellingUnitSymbol     *string `json:"selling_unit_symbol,omitempty"`
	IsLoyaltyGift         bool    `json:"is_loyalty_gift"`
	LoyaltyPointsRequired float64 `json:"loyalty_points_required"`
}

// POSPaymentLine represents an individual payment used in POS checkout, which
// may be in a non-base currency.
type POSPaymentLine struct {
	MethodID   int     `json:"method_id" validate:"required"`
	CurrencyID *int    `json:"currency_id,omitempty"`
	Amount     float64 `json:"amount" validate:"required,gt=0"`
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
	OutstandingAmount float64 `json:"outstanding_amount"`
	TopProducts       []struct {
		ProductID   int     `json:"product_id"`
		ProductName string  `json:"product_name"`
		Quantity    float64 `json:"quantity"`
		Revenue     float64 `json:"revenue"`
	} `json:"top_products"`
}
