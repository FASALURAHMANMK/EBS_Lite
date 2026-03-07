package models

// Tax represents a tax rate configuration for a company
// maps to taxes table

type Tax struct {
	TaxID      int            `json:"tax_id" db:"tax_id"`
	CompanyID  int            `json:"company_id" db:"company_id"`
	Name       string         `json:"name" db:"name"`
	Percentage float64        `json:"percentage" db:"percentage"`
	IsCompound bool           `json:"is_compound" db:"is_compound"`
	IsActive   bool           `json:"is_active" db:"is_active"`
	Components []TaxComponent `json:"components,omitempty"`
	BaseModel
}

// TaxComponent represents a component of a tax (breakdown), e.g. GST -> CGST/SGST.
// maps to tax_components table
type TaxComponent struct {
	ComponentID int     `json:"component_id" db:"component_id"`
	TaxID       int     `json:"tax_id" db:"tax_id"`
	Name        string  `json:"name" db:"name"`
	Percentage  float64 `json:"percentage" db:"percentage"`
	SortOrder   int     `json:"sort_order" db:"sort_order"`
	BaseModel
}

// TaxComponentRequest represents request body for creating/updating tax components.
type TaxComponentRequest struct {
	Name       string  `json:"name" validate:"required"`
	Percentage float64 `json:"percentage" validate:"required,gte=0,lte=100"`
	SortOrder  int     `json:"sort_order,omitempty"`
}

// CreateTaxRequest represents request body for creating a tax
// Percentage must be between 0 and 100
// IsCompound indicates whether tax is calculated on top of other taxes

type CreateTaxRequest struct {
	Name       string                `json:"name" validate:"required"`
	Percentage *float64              `json:"percentage,omitempty" validate:"omitempty,gte=0,lte=100"`
	Components []TaxComponentRequest `json:"components,omitempty" validate:"omitempty,dive"`
	IsCompound bool                  `json:"is_compound"`
	IsActive   bool                  `json:"is_active"`
}

// UpdateTaxRequest represents request body for updating a tax
// Fields are optional; only provided fields will be updated

type UpdateTaxRequest struct {
	Name       *string                `json:"name,omitempty"`
	Percentage *float64               `json:"percentage,omitempty" validate:"omitempty,gte=0,lte=100"`
	Components *[]TaxComponentRequest `json:"components,omitempty" validate:"omitempty,dive"`
	IsCompound *bool                  `json:"is_compound,omitempty"`
	IsActive   *bool                  `json:"is_active,omitempty"`
}
