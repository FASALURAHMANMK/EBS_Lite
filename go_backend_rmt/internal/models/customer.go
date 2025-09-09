package models

type Customer struct {
    CustomerID    int                        `json:"customer_id" db:"customer_id"`
    CompanyID     int                        `json:"company_id" db:"company_id"`
    Name          string                     `json:"name" db:"name" validate:"required,min=2,max=255"`
    Phone         *string                    `json:"phone,omitempty" db:"phone"`
    Email         *string                    `json:"email,omitempty" db:"email" validate:"omitempty,email"`
    Address       *string                    `json:"address,omitempty" db:"address"`
    TaxNumber     *string                    `json:"tax_number,omitempty" db:"tax_number"`
    CreditLimit   float64                    `json:"credit_limit" db:"credit_limit"`
    PaymentTerms  int                        `json:"payment_terms" db:"payment_terms"` // Days
    IsLoyalty     bool                       `json:"is_loyalty" db:"is_loyalty"`
    LoyaltyTierID *int                       `json:"loyalty_tier_id,omitempty" db:"loyalty_tier_id"`
    IsActive      bool                       `json:"is_active" db:"is_active"`
    CreatedBy     int                        `json:"created_by" db:"created_by"`
    UpdatedBy     *int                       `json:"updated_by,omitempty" db:"updated_by"`
    CreditBalance float64                    `json:"credit_balance,omitempty" db:"-"`
    Invoices      []CustomerInvoiceReference `json:"invoices,omitempty" db:"-"`
    SyncModel
}

// CustomerInvoiceReference links a customer to outstanding invoices
type CustomerInvoiceReference struct {
	SaleID     int     `json:"sale_id"`
	SaleNumber string  `json:"sale_number"`
	AmountDue  float64 `json:"amount_due"`
}

// CustomerSummary aggregates financial information for a customer
type CustomerSummary struct {
	CustomerID    int     `json:"customer_id"`
	TotalSales    float64 `json:"total_sales"`
	TotalPayments float64 `json:"total_payments"`
	TotalReturns  float64 `json:"total_returns"`
	LoyaltyPoints float64 `json:"loyalty_points"`
}

type CreateCustomerRequest struct {
    Name         string  `json:"name" validate:"required,min=2,max=255"`
    Phone        *string `json:"phone,omitempty"`
    Email        *string `json:"email,omitempty" validate:"omitempty,email"`
    Address      *string `json:"address,omitempty"`
    TaxNumber    *string `json:"tax_number,omitempty"`
    CreditLimit  float64 `json:"credit_limit"`
    PaymentTerms int     `json:"payment_terms"`
    IsLoyalty    bool    `json:"is_loyalty"`
    LoyaltyTierID *int   `json:"loyalty_tier_id,omitempty"`
}

type UpdateCustomerRequest struct {
    Name         *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
    Phone        *string  `json:"phone,omitempty"`
    Email        *string  `json:"email,omitempty" validate:"omitempty,email"`
    Address      *string  `json:"address,omitempty"`
    TaxNumber    *string  `json:"tax_number,omitempty"`
    CreditLimit  *float64 `json:"credit_limit,omitempty"`
    PaymentTerms *int     `json:"payment_terms,omitempty"`
    IsLoyalty    *bool    `json:"is_loyalty,omitempty"`
    LoyaltyTierID *int    `json:"loyalty_tier_id,omitempty"`
    IsActive     *bool    `json:"is_active,omitempty"`
}
