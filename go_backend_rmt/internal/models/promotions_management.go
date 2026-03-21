package models

import "time"

type PromotionProductRule struct {
	PromotionRuleID int        `json:"promotion_rule_id" db:"promotion_rule_id"`
	PromotionID     int        `json:"promotion_id" db:"promotion_id"`
	ProductID       int        `json:"product_id" db:"product_id"`
	BarcodeID       *int       `json:"barcode_id,omitempty" db:"barcode_id"`
	DiscountType    string     `json:"discount_type" db:"discount_type"`
	Value           float64    `json:"value" db:"value"`
	MinQty          float64    `json:"min_qty" db:"min_qty"`
	ProductName     *string    `json:"product_name,omitempty" db:"product_name"`
	Barcode         *string    `json:"barcode,omitempty" db:"barcode"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at,omitempty" db:"updated_at"`
}

type PromotionProductRuleRequest struct {
	ProductID    int     `json:"product_id" validate:"required"`
	BarcodeID    *int    `json:"barcode_id,omitempty"`
	DiscountType string  `json:"discount_type" validate:"required,oneof=PERCENTAGE FIXED FIXED_PRICE"`
	Value        float64 `json:"value" validate:"required,gte=0"`
	MinQty       float64 `json:"min_qty,omitempty" validate:"omitempty,gte=0"`
}

type PromotionEligibilityItem struct {
	ProductID   *int    `json:"product_id,omitempty"`
	BarcodeID   *int    `json:"barcode_id,omitempty"`
	CategoryID  *int    `json:"category_id,omitempty"`
	Quantity    float64 `json:"quantity" validate:"required,gt=0"`
	UnitPrice   float64 `json:"unit_price" validate:"required,gte=0"`
	LineTotal   float64 `json:"line_total" validate:"required,gte=0"`
	ProductName *string `json:"product_name,omitempty"`
}

type PromotionLineApplication struct {
	ProductID       *int     `json:"product_id,omitempty"`
	BarcodeID       *int     `json:"barcode_id,omitempty"`
	ProductName     *string  `json:"product_name,omitempty"`
	Quantity        float64  `json:"quantity"`
	DiscountType    string   `json:"discount_type"`
	Value           float64  `json:"value"`
	DiscountAmount  float64  `json:"discount_amount"`
	AdjustedPrice   *float64 `json:"adjusted_price,omitempty"`
	PromotionRuleID *int     `json:"promotion_rule_id,omitempty"`
}

type PromotionApplication struct {
	PromotionID    int                        `json:"promotion_id"`
	Name           string                     `json:"name"`
	DiscountScope  string                     `json:"discount_scope"`
	DiscountType   string                     `json:"discount_type"`
	Value          float64                    `json:"value"`
	DiscountAmount float64                    `json:"discount_amount"`
	LineItems      []PromotionLineApplication `json:"line_items,omitempty"`
}

type CouponSeries struct {
	CouponSeriesID        int        `json:"coupon_series_id" db:"coupon_series_id"`
	CompanyID             int        `json:"company_id" db:"company_id"`
	Name                  string     `json:"name" db:"name"`
	Description           *string    `json:"description,omitempty" db:"description"`
	Prefix                string     `json:"prefix" db:"prefix"`
	CodeLength            int        `json:"code_length" db:"code_length"`
	DiscountType          string     `json:"discount_type" db:"discount_type"`
	DiscountValue         float64    `json:"discount_value" db:"discount_value"`
	MinPurchaseAmount     float64    `json:"min_purchase_amount" db:"min_purchase_amount"`
	MaxDiscountAmount     *float64   `json:"max_discount_amount,omitempty" db:"max_discount_amount"`
	StartDate             time.Time  `json:"start_date" db:"start_date"`
	EndDate               time.Time  `json:"end_date" db:"end_date"`
	TotalCoupons          int        `json:"total_coupons" db:"total_coupons"`
	UsageLimitPerCoupon   int        `json:"usage_limit_per_coupon" db:"usage_limit_per_coupon"`
	UsageLimitPerCustomer int        `json:"usage_limit_per_customer" db:"usage_limit_per_customer"`
	IsActive              bool       `json:"is_active" db:"is_active"`
	CreatedBy             *int       `json:"created_by,omitempty" db:"created_by"`
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt             *time.Time `json:"updated_at,omitempty" db:"updated_at"`
	AvailableCoupons      int        `json:"available_coupons,omitempty"`
	RedeemedCoupons       int        `json:"redeemed_coupons,omitempty"`
}

type CouponCode struct {
	CouponCodeID       int        `json:"coupon_code_id" db:"coupon_code_id"`
	CouponSeriesID     int        `json:"coupon_series_id" db:"coupon_series_id"`
	Code               string     `json:"code" db:"code"`
	Status             string     `json:"status" db:"status"`
	RedeemCount        int        `json:"redeem_count" db:"redeem_count"`
	IssuedToCustomerID *int       `json:"issued_to_customer_id,omitempty" db:"issued_to_customer_id"`
	IssuedSaleID       *int       `json:"issued_sale_id,omitempty" db:"issued_sale_id"`
	RedeemedSaleID     *int       `json:"redeemed_sale_id,omitempty" db:"redeemed_sale_id"`
	IssuedAt           *time.Time `json:"issued_at,omitempty" db:"issued_at"`
	RedeemedAt         *time.Time `json:"redeemed_at,omitempty" db:"redeemed_at"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          *time.Time `json:"updated_at,omitempty" db:"updated_at"`
}

type CreateCouponSeriesRequest struct {
	Name                  string   `json:"name" validate:"required,min=2,max=255"`
	Description           *string  `json:"description,omitempty"`
	Prefix                string   `json:"prefix" validate:"required,min=2,max=20"`
	CodeLength            int      `json:"code_length" validate:"required,gte=6,lte=32"`
	DiscountType          string   `json:"discount_type" validate:"required,oneof=PERCENTAGE FIXED_AMOUNT"`
	DiscountValue         float64  `json:"discount_value" validate:"required,gt=0"`
	MinPurchaseAmount     float64  `json:"min_purchase_amount,omitempty" validate:"omitempty,gte=0"`
	MaxDiscountAmount     *float64 `json:"max_discount_amount,omitempty" validate:"omitempty,gte=0"`
	StartDate             string   `json:"start_date" validate:"required"`
	EndDate               string   `json:"end_date" validate:"required"`
	TotalCoupons          int      `json:"total_coupons" validate:"required,gte=1,lte=50000"`
	UsageLimitPerCoupon   int      `json:"usage_limit_per_coupon,omitempty" validate:"omitempty,gte=1,lte=100"`
	UsageLimitPerCustomer int      `json:"usage_limit_per_customer,omitempty" validate:"omitempty,gte=1,lte=100"`
	IsActive              *bool    `json:"is_active,omitempty"`
}

type UpdateCouponSeriesRequest struct {
	Name                  *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description           *string  `json:"description,omitempty"`
	Prefix                *string  `json:"prefix,omitempty" validate:"omitempty,min=2,max=20"`
	CodeLength            *int     `json:"code_length,omitempty" validate:"omitempty,gte=6,lte=32"`
	DiscountType          *string  `json:"discount_type,omitempty" validate:"omitempty,oneof=PERCENTAGE FIXED_AMOUNT"`
	DiscountValue         *float64 `json:"discount_value,omitempty" validate:"omitempty,gt=0"`
	MinPurchaseAmount     *float64 `json:"min_purchase_amount,omitempty" validate:"omitempty,gte=0"`
	MaxDiscountAmount     *float64 `json:"max_discount_amount,omitempty" validate:"omitempty,gte=0"`
	StartDate             *string  `json:"start_date,omitempty"`
	EndDate               *string  `json:"end_date,omitempty"`
	UsageLimitPerCoupon   *int     `json:"usage_limit_per_coupon,omitempty" validate:"omitempty,gte=1,lte=100"`
	UsageLimitPerCustomer *int     `json:"usage_limit_per_customer,omitempty" validate:"omitempty,gte=1,lte=100"`
	IsActive              *bool    `json:"is_active,omitempty"`
}

type ValidateCouponCodeRequest struct {
	Code       string  `json:"code" validate:"required,min=4,max=64"`
	CustomerID *int    `json:"customer_id,omitempty"`
	SaleAmount float64 `json:"sale_amount" validate:"required,gt=0"`
}

type CouponValidationResponse struct {
	CouponSeriesID    int      `json:"coupon_series_id"`
	SeriesName        string   `json:"series_name"`
	Code              string   `json:"code"`
	DiscountType      string   `json:"discount_type"`
	DiscountValue     float64  `json:"discount_value"`
	DiscountAmount    float64  `json:"discount_amount"`
	MinPurchaseAmount float64  `json:"min_purchase_amount"`
	MaxDiscountAmount *float64 `json:"max_discount_amount,omitempty"`
}

type RaffleDefinition struct {
	RaffleDefinitionID          int        `json:"raffle_definition_id" db:"raffle_definition_id"`
	CompanyID                   int        `json:"company_id" db:"company_id"`
	Name                        string     `json:"name" db:"name"`
	Description                 *string    `json:"description,omitempty" db:"description"`
	Prefix                      string     `json:"prefix" db:"prefix"`
	CodeLength                  int        `json:"code_length" db:"code_length"`
	StartDate                   time.Time  `json:"start_date" db:"start_date"`
	EndDate                     time.Time  `json:"end_date" db:"end_date"`
	TriggerAmount               float64    `json:"trigger_amount" db:"trigger_amount"`
	CouponsPerTrigger           int        `json:"coupons_per_trigger" db:"coupons_per_trigger"`
	MaxCouponsPerSale           *int       `json:"max_coupons_per_sale,omitempty" db:"max_coupons_per_sale"`
	DefaultAutoFillCustomerData bool       `json:"default_auto_fill_customer_data" db:"default_auto_fill_customer_data"`
	PrintAfterInvoice           bool       `json:"print_after_invoice" db:"print_after_invoice"`
	IsActive                    bool       `json:"is_active" db:"is_active"`
	CreatedBy                   *int       `json:"created_by,omitempty" db:"created_by"`
	CreatedAt                   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt                   *time.Time `json:"updated_at,omitempty" db:"updated_at"`
	IssuedCoupons               int        `json:"issued_coupons,omitempty"`
	WinnerCount                 int        `json:"winner_count,omitempty"`
}

type RaffleCoupon struct {
	RaffleCouponID       int        `json:"raffle_coupon_id" db:"raffle_coupon_id"`
	RaffleDefinitionID   int        `json:"raffle_definition_id" db:"raffle_definition_id"`
	SaleID               int        `json:"sale_id" db:"sale_id"`
	CustomerID           *int       `json:"customer_id,omitempty" db:"customer_id"`
	CouponCode           string     `json:"coupon_code" db:"coupon_code"`
	Status               string     `json:"status" db:"status"`
	AutoFilled           bool       `json:"auto_filled" db:"auto_filled"`
	PrintAfterInvoice    bool       `json:"print_after_invoice" db:"print_after_invoice"`
	CustomerName         *string    `json:"customer_name,omitempty" db:"customer_name"`
	CustomerPhone        *string    `json:"customer_phone,omitempty" db:"customer_phone"`
	CustomerEmail        *string    `json:"customer_email,omitempty" db:"customer_email"`
	CustomerAddress      *string    `json:"customer_address,omitempty" db:"customer_address"`
	WinnerName           *string    `json:"winner_name,omitempty" db:"winner_name"`
	WinnerNotes          *string    `json:"winner_notes,omitempty" db:"winner_notes"`
	IssuedAt             time.Time  `json:"issued_at" db:"issued_at"`
	WinnerMarkedAt       *time.Time `json:"winner_marked_at,omitempty" db:"winner_marked_at"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            *time.Time `json:"updated_at,omitempty" db:"updated_at"`
	RaffleDefinitionName *string    `json:"raffle_definition_name,omitempty" db:"raffle_definition_name"`
	SaleNumber           *string    `json:"sale_number,omitempty" db:"sale_number"`
}

type CreateRaffleDefinitionRequest struct {
	Name                        string  `json:"name" validate:"required,min=2,max=255"`
	Description                 *string `json:"description,omitempty"`
	Prefix                      string  `json:"prefix" validate:"required,min=2,max=20"`
	CodeLength                  int     `json:"code_length" validate:"required,gte=6,lte=32"`
	StartDate                   string  `json:"start_date" validate:"required"`
	EndDate                     string  `json:"end_date" validate:"required"`
	TriggerAmount               float64 `json:"trigger_amount" validate:"required,gt=0"`
	CouponsPerTrigger           int     `json:"coupons_per_trigger" validate:"required,gte=1,lte=100"`
	MaxCouponsPerSale           *int    `json:"max_coupons_per_sale,omitempty" validate:"omitempty,gte=1,lte=1000"`
	DefaultAutoFillCustomerData bool    `json:"default_auto_fill_customer_data"`
	PrintAfterInvoice           bool    `json:"print_after_invoice"`
	IsActive                    *bool   `json:"is_active,omitempty"`
}

type UpdateRaffleDefinitionRequest struct {
	Name                        *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description                 *string  `json:"description,omitempty"`
	Prefix                      *string  `json:"prefix,omitempty" validate:"omitempty,min=2,max=20"`
	CodeLength                  *int     `json:"code_length,omitempty" validate:"omitempty,gte=6,lte=32"`
	StartDate                   *string  `json:"start_date,omitempty"`
	EndDate                     *string  `json:"end_date,omitempty"`
	TriggerAmount               *float64 `json:"trigger_amount,omitempty" validate:"omitempty,gt=0"`
	CouponsPerTrigger           *int     `json:"coupons_per_trigger,omitempty" validate:"omitempty,gte=1,lte=100"`
	MaxCouponsPerSale           *int     `json:"max_coupons_per_sale,omitempty" validate:"omitempty,gte=1,lte=1000"`
	DefaultAutoFillCustomerData *bool    `json:"default_auto_fill_customer_data,omitempty"`
	PrintAfterInvoice           *bool    `json:"print_after_invoice,omitempty"`
	IsActive                    *bool    `json:"is_active,omitempty"`
}

type MarkRaffleWinnerRequest struct {
	WinnerName  string  `json:"winner_name" validate:"required,min=2,max=255"`
	WinnerNotes *string `json:"winner_notes,omitempty"`
}
