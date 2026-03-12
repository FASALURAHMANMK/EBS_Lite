package models

import "time"

type ComboProduct struct {
	ComboProductID int                     `json:"combo_product_id" db:"combo_product_id"`
	CompanyID      int                     `json:"company_id" db:"company_id"`
	Name           string                  `json:"name" db:"name"`
	SKU            *string                 `json:"sku,omitempty" db:"sku"`
	Barcode        string                  `json:"barcode" db:"barcode"`
	SellingPrice   float64                 `json:"selling_price" db:"selling_price"`
	TaxID          int                     `json:"tax_id" db:"tax_id"`
	Notes          *string                 `json:"notes,omitempty" db:"notes"`
	IsActive       bool                    `json:"is_active" db:"is_active"`
	CreatedBy      int                     `json:"created_by" db:"created_by"`
	UpdatedBy      *int                    `json:"updated_by,omitempty" db:"updated_by"`
	AvailableStock *float64                `json:"available_stock,omitempty" db:"-"`
	Components     []ComboProductComponent `json:"components,omitempty" db:"-"`
	SyncModel
}

type ComboProductComponent struct {
	ComboProductItemID int      `json:"combo_product_item_id" db:"combo_product_item_id"`
	ComboProductID     int      `json:"combo_product_id" db:"combo_product_id"`
	ProductID          int      `json:"product_id" db:"product_id"`
	BarcodeID          int      `json:"barcode_id" db:"barcode_id"`
	Quantity           float64  `json:"quantity" db:"quantity"`
	SortOrder          int      `json:"sort_order" db:"sort_order"`
	ProductName        string   `json:"product_name,omitempty" db:"-"`
	ProductSKU         *string  `json:"product_sku,omitempty" db:"-"`
	Barcode            *string  `json:"barcode,omitempty" db:"-"`
	VariantName        *string  `json:"variant_name,omitempty" db:"-"`
	TrackingType       string   `json:"tracking_type,omitempty" db:"-"`
	IsSerialized       bool     `json:"is_serialized" db:"-"`
	UnitSymbol         *string  `json:"unit_symbol,omitempty" db:"-"`
	SellingPrice       *float64 `json:"selling_price,omitempty" db:"-"`
	AvailableStock     *float64 `json:"available_stock,omitempty" db:"-"`
}

type CreateComboProductRequest struct {
	Name         string                      `json:"name" validate:"required,min=2,max=255"`
	SKU          *string                     `json:"sku,omitempty"`
	Barcode      string                      `json:"barcode" validate:"required,min=3,max=100"`
	SellingPrice float64                     `json:"selling_price" validate:"required,gte=0"`
	TaxID        int                         `json:"tax_id" validate:"required"`
	Notes        *string                     `json:"notes,omitempty"`
	IsActive     *bool                       `json:"is_active,omitempty"`
	Components   []CreateComboComponentInput `json:"components" validate:"required,min=1,dive"`
}

type CreateComboComponentInput struct {
	ProductID int     `json:"product_id" validate:"required"`
	BarcodeID int     `json:"barcode_id" validate:"required"`
	Quantity  float64 `json:"quantity" validate:"required,gt=0"`
	SortOrder int     `json:"sort_order"`
}

type UpdateComboProductRequest struct {
	Name         *string                     `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	SKU          *string                     `json:"sku,omitempty"`
	Barcode      *string                     `json:"barcode,omitempty" validate:"omitempty,min=3,max=100"`
	SellingPrice *float64                    `json:"selling_price,omitempty" validate:"omitempty,gte=0"`
	TaxID        *int                        `json:"tax_id,omitempty"`
	Notes        *string                     `json:"notes,omitempty"`
	IsActive     *bool                       `json:"is_active,omitempty"`
	Components   []CreateComboComponentInput `json:"components,omitempty" validate:"omitempty,min=1,dive"`
}

type SaleDetailComboComponent struct {
	SaleDetailComboComponentID int       `json:"sale_detail_combo_component_id" db:"sale_detail_combo_component_id"`
	SaleDetailID               int       `json:"sale_detail_id" db:"sale_detail_id"`
	ComboProductID             int       `json:"combo_product_id" db:"combo_product_id"`
	ProductID                  int       `json:"product_id" db:"product_id"`
	BarcodeID                  int       `json:"barcode_id" db:"barcode_id"`
	Quantity                   float64   `json:"quantity" db:"quantity"`
	UnitCost                   float64   `json:"unit_cost" db:"unit_cost"`
	TotalCost                  float64   `json:"total_cost" db:"total_cost"`
	CreatedAt                  time.Time `json:"created_at" db:"created_at"`
}
