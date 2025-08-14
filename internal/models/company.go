package models

type Company struct {
	CompanyID  int     `json:"company_id" db:"company_id"`
	Name       string  `json:"name" db:"name" validate:"required,min=2,max=255"`
	Logo       *string `json:"logo,omitempty" db:"logo"`
	Address    *string `json:"address,omitempty" db:"address"`
	Phone      *string `json:"phone,omitempty" db:"phone"`
	Email      *string `json:"email,omitempty" db:"email" validate:"omitempty,email"`
	TaxNumber  *string `json:"tax_number,omitempty" db:"tax_number"`
	CurrencyID *int    `json:"currency_id,omitempty" db:"currency_id"`
	IsActive   bool    `json:"is_active" db:"is_active"`
	BaseModel
}

type CreateCompanyRequest struct {
	Name       string  `json:"name" validate:"required,min=2,max=255"`
	Logo       *string `json:"logo,omitempty"`
	Address    *string `json:"address,omitempty"`
	Phone      *string `json:"phone,omitempty"`
	Email      *string `json:"email,omitempty" validate:"omitempty,email"`
	TaxNumber  *string `json:"tax_number,omitempty"`
	CurrencyID *int    `json:"currency_id,omitempty"`
}

type UpdateCompanyRequest struct {
	Name       *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Logo       *string `json:"logo,omitempty"`
	Address    *string `json:"address,omitempty"`
	Phone      *string `json:"phone,omitempty"`
	Email      *string `json:"email,omitempty" validate:"omitempty,email"`
	TaxNumber  *string `json:"tax_number,omitempty"`
	CurrencyID *int    `json:"currency_id,omitempty"`
	IsActive   *bool   `json:"is_active,omitempty"`
}

type Currency struct {
	CurrencyID     int     `json:"currency_id" db:"currency_id"`
	Code           string  `json:"code" db:"code"`
	Name           string  `json:"name" db:"name"`
	Symbol         *string `json:"symbol,omitempty" db:"symbol"`
	ExchangeRate   float64 `json:"exchange_rate" db:"exchange_rate"`
	IsBaseCurrency bool    `json:"is_base_currency" db:"is_base_currency"`
	BaseModel
}
