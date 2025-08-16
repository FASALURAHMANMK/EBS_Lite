package models

// CreateCurrencyRequest represents request body for creating a currency
// Code should be a unique currency code (e.g. USD)
type CreateCurrencyRequest struct {
	Code           string  `json:"code" validate:"required,alpha,len=3"`
	Name           string  `json:"name" validate:"required"`
	Symbol         *string `json:"symbol,omitempty" validate:"omitempty,max=10"`
	ExchangeRate   float64 `json:"exchange_rate" validate:"required,gt=0"`
	IsBaseCurrency bool    `json:"is_base_currency"`
}

// UpdateCurrencyRequest represents request body for updating a currency
// Fields are optional; only provided fields will be updated
type UpdateCurrencyRequest struct {
	Code           *string  `json:"code,omitempty" validate:"omitempty,alpha,len=3"`
	Name           *string  `json:"name,omitempty"`
	Symbol         *string  `json:"symbol,omitempty" validate:"omitempty,max=10"`
	ExchangeRate   *float64 `json:"exchange_rate,omitempty" validate:"omitempty,gt=0"`
	IsBaseCurrency *bool    `json:"is_base_currency,omitempty"`
}
