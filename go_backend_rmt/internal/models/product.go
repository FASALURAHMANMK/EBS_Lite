package models

type Product struct {
	ProductID    int                `json:"product_id" db:"product_id"`
	CompanyID    int                `json:"company_id" db:"company_id"`
	CategoryID   *int               `json:"category_id,omitempty" db:"category_id"`
	BrandID      *int               `json:"brand_id,omitempty" db:"brand_id"`
	UnitID       *int               `json:"unit_id,omitempty" db:"unit_id"`
	Name         string             `json:"name" db:"name" validate:"required,min=2,max=255"`
	SKU          *string            `json:"sku,omitempty" db:"sku"`
	Barcodes     []ProductBarcode   `json:"barcodes,omitempty" db:"-"`
	Description  *string            `json:"description,omitempty" db:"description"`
	CostPrice    *float64           `json:"cost_price,omitempty" db:"cost_price"`
	SellingPrice *float64           `json:"selling_price,omitempty" db:"selling_price"`
	ReorderLevel int                `json:"reorder_level" db:"reorder_level"`
	Weight       *float64           `json:"weight,omitempty" db:"weight"`
	Dimensions   *string            `json:"dimensions,omitempty" db:"dimensions"`
	IsSerialized bool               `json:"is_serialized" db:"is_serialized"`
	IsActive     bool               `json:"is_active" db:"is_active"`
	CreatedBy    int                `json:"created_by" db:"created_by"`
	UpdatedBy    *int               `json:"updated_by,omitempty" db:"updated_by"`
	Attributes   []ProductAttribute `json:"attributes,omitempty" db:"-"`
	SyncModel
}

type CreateProductRequest struct {
	CategoryID   *int             `json:"category_id,omitempty"`
	BrandID      *int             `json:"brand_id,omitempty"`
	UnitID       *int             `json:"unit_id,omitempty"`
	Name         string           `json:"name" validate:"required,min=2,max=255"`
	SKU          *string          `json:"sku,omitempty"`
	Barcodes     []ProductBarcode `json:"barcodes" validate:"required,min=1,dive"`
	Description  *string          `json:"description,omitempty"`
	CostPrice    *float64         `json:"cost_price,omitempty"`
	SellingPrice *float64         `json:"selling_price,omitempty"`
	ReorderLevel int              `json:"reorder_level"`
	Weight       *float64         `json:"weight,omitempty"`
	Dimensions   *string          `json:"dimensions,omitempty"`
	IsSerialized bool             `json:"is_serialized"`
}

type UpdateProductRequest struct {
	CategoryID   *int             `json:"category_id,omitempty"`
	BrandID      *int             `json:"brand_id,omitempty"`
	UnitID       *int             `json:"unit_id,omitempty"`
	Name         *string          `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	SKU          *string          `json:"sku,omitempty"`
	Barcodes     []ProductBarcode `json:"barcodes,omitempty" validate:"omitempty,dive"`
	Description  *string          `json:"description,omitempty"`
	CostPrice    *float64         `json:"cost_price,omitempty"`
	SellingPrice *float64         `json:"selling_price,omitempty"`
	ReorderLevel *int             `json:"reorder_level,omitempty"`
	Weight       *float64         `json:"weight,omitempty"`
	Dimensions   *string          `json:"dimensions,omitempty"`
	IsSerialized *bool            `json:"is_serialized,omitempty"`
	IsActive     *bool            `json:"is_active,omitempty"`
}

type Category struct {
	CategoryID  int     `json:"category_id" db:"category_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	Name        string  `json:"name" db:"name" validate:"required,min=2,max=255"`
	Description *string `json:"description,omitempty" db:"description"`
	ParentID    *int    `json:"parent_id,omitempty" db:"parent_id"`
	IsActive    bool    `json:"is_active" db:"is_active"`
	CreatedBy   int     `json:"created_by" db:"created_by"`
	UpdatedBy   *int    `json:"updated_by,omitempty" db:"updated_by"`
	BaseModel
}

type CreateCategoryRequest struct {
	Name        string  `json:"name" validate:"required,min=2,max=255"`
	Description *string `json:"description,omitempty"`
	ParentID    *int    `json:"parent_id,omitempty"`
}

type UpdateCategoryRequest struct {
	Name        *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description *string `json:"description,omitempty"`
	ParentID    *int    `json:"parent_id,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

type Brand struct {
	BrandID     int     `json:"brand_id" db:"brand_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	Name        string  `json:"name" db:"name" validate:"required,min=2,max=255"`
	Description *string `json:"description,omitempty" db:"description"`
	IsActive    bool    `json:"is_active" db:"is_active"`
	CreatedBy   int     `json:"created_by" db:"created_by"`
	UpdatedBy   *int    `json:"updated_by,omitempty" db:"updated_by"`
	BaseModel
}

type CreateBrandRequest struct {
	Name        string  `json:"name" validate:"required,min=2,max=255"`
	Description *string `json:"description,omitempty"`
}

type UpdateBrandRequest struct {
	Name        *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description *string `json:"description,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

type Unit struct {
	UnitID           int      `json:"unit_id" db:"unit_id"`
	Name             string   `json:"name" db:"name" validate:"required,min=1,max=50"`
	Symbol           *string  `json:"symbol,omitempty" db:"symbol"`
	BaseUnitID       *int     `json:"base_unit_id,omitempty" db:"base_unit_id"`
	ConversionFactor *float64 `json:"conversion_factor,omitempty" db:"conversion_factor"`
}

type CreateUnitRequest struct {
	Name             string   `json:"name" validate:"required,min=1,max=50"`
	Symbol           *string  `json:"symbol,omitempty"`
	BaseUnitID       *int     `json:"base_unit_id,omitempty"`
	ConversionFactor *float64 `json:"conversion_factor,omitempty"`
}
