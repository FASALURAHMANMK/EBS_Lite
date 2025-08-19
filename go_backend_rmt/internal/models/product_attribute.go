package models

// ProductAttributeDefinition represents a definable attribute for products
// e.g. color, size with metadata like type and requirement
// Options is JSON for SELECT type
// Example: {"Red","Blue"}
type ProductAttributeDefinition struct {
	AttributeID int     `json:"attribute_id" db:"attribute_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	Name        string  `json:"name" db:"name" validate:"required"`
	Type        string  `json:"type" db:"type" validate:"required,oneof=TEXT NUMBER DATE BOOLEAN SELECT"`
	IsRequired  bool    `json:"is_required" db:"is_required"`
	Options     *string `json:"options,omitempty" db:"options"`
	BaseModel
	SyncModel
}

// ProductAttributeValue stores value of attribute for a product
// Definition holds the attribute definition metadata
// Value is stored as string; service ensures type correctness
type ProductAttributeValue struct {
	AttributeID int                        `json:"attribute_id" db:"attribute_id"`
	ProductID   int                        `json:"product_id" db:"product_id"`
	Value       string                     `json:"value" db:"value"`
	Definition  ProductAttributeDefinition `json:"definition" db:"-"`
}

// Requests for attribute definition management
type CreateProductAttributeDefinitionRequest struct {
	Name       string  `json:"name" validate:"required"`
	Type       string  `json:"type" validate:"required,oneof=TEXT NUMBER DATE BOOLEAN SELECT"`
	IsRequired bool    `json:"is_required"`
	Options    *string `json:"options,omitempty"`
}

type UpdateProductAttributeDefinitionRequest struct {
	Name       *string `json:"name,omitempty"`
	Type       *string `json:"type,omitempty"`
	IsRequired *bool   `json:"is_required,omitempty"`
	Options    *string `json:"options,omitempty"`
	IsActive   *bool   `json:"is_active,omitempty"`
}
