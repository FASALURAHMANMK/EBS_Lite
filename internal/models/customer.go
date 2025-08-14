package models

type Customer struct {
	CustomerID   int     `json:"customer_id" db:"customer_id"`
	CompanyID    int     `json:"company_id" db:"company_id"`
	Name         string  `json:"name" db:"name" validate:"required,min=2,max=255"`
	Phone        *string `json:"phone,omitempty" db:"phone"`
	Email        *string `json:"email,omitempty" db:"email" validate:"omitempty,email"`
	Address      *string `json:"address,omitempty" db:"address"`
	TaxNumber    *string `json:"tax_number,omitempty" db:"tax_number"`
	CreditLimit  float64 `json:"credit_limit" db:"credit_limit"`
	PaymentTerms int     `json:"payment_terms" db:"payment_terms"` // Days
	IsActive     bool    `json:"is_active" db:"is_active"`
	SyncModel
}

type CreateCustomerRequest struct {
	Name         string  `json:"name" validate:"required,min=2,max=255"`
	Phone        *string `json:"phone,omitempty"`
	Email        *string `json:"email,omitempty" validate:"omitempty,email"`
	Address      *string `json:"address,omitempty"`
	TaxNumber    *string `json:"tax_number,omitempty"`
	CreditLimit  float64 `json:"credit_limit"`
	PaymentTerms int     `json:"payment_terms"`
}

type UpdateCustomerRequest struct {
	Name         *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Phone        *string  `json:"phone,omitempty"`
	Email        *string  `json:"email,omitempty" validate:"omitempty,email"`
	Address      *string  `json:"address,omitempty"`
	TaxNumber    *string  `json:"tax_number,omitempty"`
	CreditLimit  *float64 `json:"credit_limit,omitempty"`
	PaymentTerms *int     `json:"payment_terms,omitempty"`
	IsActive     *bool    `json:"is_active,omitempty"`
}
