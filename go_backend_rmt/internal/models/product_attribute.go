package models

// ProductAttribute represents a custom attribute for products
// Example: color, size, material etc.
type ProductAttribute struct {
	AttributeID int    `json:"attribute_id" db:"attribute_id"`
	CompanyID   int    `json:"company_id" db:"company_id"`
	Name        string `json:"name" db:"name" validate:"required"`
	Value       string `json:"value" db:"value" validate:"required"`
	BaseModel
	SyncModel
}

type CreateProductAttributeRequest struct {
	Name  string `json:"name" validate:"required"`
	Value string `json:"value" validate:"required"`
}

type UpdateProductAttributeRequest struct {
	Name     *string `json:"name,omitempty"`
	Value    *string `json:"value,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
}
