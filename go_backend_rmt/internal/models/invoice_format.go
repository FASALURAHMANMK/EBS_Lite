package models

// InvoiceFormat holds formatting and tax configuration for invoices
// at the company/location level.
type InvoiceFormat struct {
	FormatID   int    `json:"format_id" db:"format_id"`
	CompanyID  int    `json:"company_id" db:"company_id" validate:"required"`
	LocationID *int   `json:"location_id,omitempty" db:"location_id"`
	SequenceID *int   `json:"sequence_id,omitempty" db:"sequence_id"`
	Name       string `json:"name" db:"name" validate:"required"`
	TaxFields  JSONB  `json:"tax_fields,omitempty" db:"tax_fields"`
	IsDefault  bool   `json:"is_default" db:"is_default"`
	BaseModel
}

// CreateInvoiceFormatRequest is the payload for creating invoice formats.
type CreateInvoiceFormatRequest struct {
	CompanyID  int    `json:"company_id" validate:"required"`
	LocationID *int   `json:"location_id,omitempty"`
	SequenceID *int   `json:"sequence_id,omitempty"`
	Name       string `json:"name" validate:"required"`
	TaxFields  JSONB  `json:"tax_fields,omitempty"`
	IsDefault  bool   `json:"is_default,omitempty"`
}

// UpdateInvoiceFormatRequest is the payload for updating invoice formats.
type UpdateInvoiceFormatRequest struct {
	SequenceID *int    `json:"sequence_id,omitempty"`
	Name       *string `json:"name,omitempty"`
	TaxFields  *JSONB  `json:"tax_fields,omitempty"`
	IsDefault  *bool   `json:"is_default,omitempty"`
}
