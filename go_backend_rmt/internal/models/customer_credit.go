package models

import "time"

// CreditTransaction represents a credit or debit adjustment for a customer.
type CreditTransaction struct {
	TransactionID int       `json:"transaction_id" db:"transaction_id"`
	CustomerID    int       `json:"customer_id" db:"customer_id"`
	CompanyID     int       `json:"company_id" db:"company_id"`
	Amount        float64   `json:"amount" db:"amount"`
	Type          string    `json:"type" db:"type"`
	Description   *string   `json:"description,omitempty" db:"description"`
	CreatedBy     int       `json:"created_by" db:"created_by"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	NewBalance    float64   `json:"new_balance,omitempty" db:"-"`
}

// CreditTransactionRequest is used to record a credit or debit for a customer.
type CreditTransactionRequest struct {
	Amount      float64 `json:"amount" validate:"required,gt=0"`
	Type        string  `json:"type" validate:"required,oneof=credit debit"`
	Description *string `json:"description,omitempty"`
}
