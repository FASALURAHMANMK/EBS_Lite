package models

import (
	"time"
)

type Supplier struct {
	SupplierID    int     `json:"supplier_id" db:"supplier_id"`
	CompanyID     int     `json:"company_id" db:"company_id"`
	Name          string  `json:"name" db:"name"`
	ContactPerson *string `json:"contact_person,omitempty" db:"contact_person"`
	Phone         *string `json:"phone,omitempty" db:"phone"`
	Email         *string `json:"email,omitempty" db:"email"`
	Address       *string `json:"address,omitempty" db:"address"`
	TaxNumber     *string `json:"tax_number,omitempty" db:"tax_number"`
	PaymentTerms  int     `json:"payment_terms" db:"payment_terms"`
	CreditLimit   float64 `json:"credit_limit" db:"credit_limit"`
	IsActive      bool    `json:"is_active" db:"is_active"`
	CreatedBy     int     `json:"created_by" db:"created_by"`
	UpdatedBy     *int    `json:"updated_by,omitempty" db:"updated_by"`
	SyncModel
}

type SupplierWithStats struct {
	Supplier
	TotalPurchases    float64    `json:"total_purchases"`
	TotalReturns      float64    `json:"total_returns"`
	OutstandingAmount float64    `json:"outstanding_amount"`
	LastPurchaseDate  *time.Time `json:"last_purchase_date,omitempty"`
}

type SupplierSummary struct {
	SupplierID         int     `json:"supplier_id"`
	CompanyID          int     `json:"company_id"`
	TotalPurchases     float64 `json:"total_purchases"`
	TotalPayments      float64 `json:"total_payments"`
	TotalReturns       float64 `json:"total_returns"`
	OutstandingBalance float64 `json:"outstanding_balance"`
}

// Request Models
type CreateSupplierRequest struct {
	Name          string   `json:"name" validate:"required,min=2,max=255"`
	ContactPerson *string  `json:"contact_person,omitempty" validate:"omitempty,min=2,max=255"`
	Phone         *string  `json:"phone,omitempty" validate:"omitempty,min=5,max=50"`
	Email         *string  `json:"email,omitempty" validate:"omitempty,email"`
	Address       *string  `json:"address,omitempty"`
	TaxNumber     *string  `json:"tax_number,omitempty" validate:"omitempty,max=100"`
	PaymentTerms  *int     `json:"payment_terms,omitempty" validate:"omitempty,gte=0"`
	CreditLimit   *float64 `json:"credit_limit,omitempty" validate:"omitempty,gte=0"`
}

type UpdateSupplierRequest struct {
	Name          *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	ContactPerson *string  `json:"contact_person,omitempty" validate:"omitempty,min=2,max=255"`
	Phone         *string  `json:"phone,omitempty" validate:"omitempty,min=5,max=50"`
	Email         *string  `json:"email,omitempty" validate:"omitempty,email"`
	Address       *string  `json:"address,omitempty"`
	TaxNumber     *string  `json:"tax_number,omitempty" validate:"omitempty,max=100"`
	PaymentTerms  *int     `json:"payment_terms,omitempty" validate:"omitempty,gte=0"`
	CreditLimit   *float64 `json:"credit_limit,omitempty" validate:"omitempty,gte=0"`
	IsActive      *bool    `json:"is_active,omitempty"`
}
