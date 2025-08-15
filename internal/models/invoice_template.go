package models

// InvoiceTemplate represents configurable invoice templates per company.
type InvoiceTemplate struct {
	TemplateID        int     `json:"template_id" db:"template_id"`
	CompanyID         int     `json:"company_id" db:"company_id" validate:"required"`
	Name              string  `json:"name" db:"name" validate:"required"`
	TemplateType      string  `json:"template_type" db:"template_type" validate:"required"`
	Layout            JSONB   `json:"layout" db:"layout" validate:"required"`
	PrimaryLanguage   *string `json:"primary_language,omitempty" db:"primary_language"`
	SecondaryLanguage *string `json:"secondary_language,omitempty" db:"secondary_language"`
	IsDefault         bool    `json:"is_default" db:"is_default"`
	IsActive          bool    `json:"is_active" db:"is_active"`
	BaseModel
}

// CreateInvoiceTemplateRequest is the payload for creating invoice templates.
type CreateInvoiceTemplateRequest struct {
	CompanyID         int     `json:"company_id" validate:"required"`
	Name              string  `json:"name" validate:"required"`
	TemplateType      string  `json:"template_type" validate:"required"`
	Layout            JSONB   `json:"layout" validate:"required"`
	PrimaryLanguage   *string `json:"primary_language,omitempty"`
	SecondaryLanguage *string `json:"secondary_language,omitempty"`
	IsDefault         bool    `json:"is_default,omitempty"`
	IsActive          bool    `json:"is_active,omitempty"`
}

// UpdateInvoiceTemplateRequest is the payload for updating invoice templates.
type UpdateInvoiceTemplateRequest struct {
	Name              *string `json:"name,omitempty"`
	TemplateType      *string `json:"template_type,omitempty"`
	Layout            *JSONB  `json:"layout,omitempty"`
	PrimaryLanguage   *string `json:"primary_language,omitempty"`
	SecondaryLanguage *string `json:"secondary_language,omitempty"`
	IsDefault         *bool   `json:"is_default,omitempty"`
	IsActive          *bool   `json:"is_active,omitempty"`
}
