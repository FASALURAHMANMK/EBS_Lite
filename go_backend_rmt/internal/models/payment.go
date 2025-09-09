package models

import "time"

// Payment represents a supplier payment entry.
type Payment struct {
    PaymentID      int        `json:"payment_id" db:"payment_id"`
    PaymentNumber  string     `json:"payment_number" db:"payment_number"`
    SupplierID     *int       `json:"supplier_id,omitempty" db:"supplier_id"`
    PurchaseID     *int       `json:"purchase_id,omitempty" db:"purchase_id"`
    LocationID     *int       `json:"location_id,omitempty" db:"location_id"`
    Amount         float64    `json:"amount" db:"amount"`
    PaymentMethodID *int      `json:"payment_method_id,omitempty" db:"payment_method_id"`
    ReferenceNumber *string   `json:"reference_number,omitempty" db:"reference_number"`
    Notes          *string    `json:"notes,omitempty" db:"notes"`
    PaymentDate    time.Time  `json:"payment_date" db:"payment_date"`
    CreatedBy      int        `json:"created_by" db:"created_by"`
    UpdatedBy      *int       `json:"updated_by,omitempty" db:"updated_by"`
    SyncModel
}

// CreatePaymentRequest defines payload for recording a supplier payment
// Location and created_by are derived from context and not required in the request
// PaymentDate maps to payment_date in the database
type CreatePaymentRequest struct {
    SupplierID      *int    `json:"supplier_id,omitempty"`
    PurchaseID      *int    `json:"purchase_id,omitempty"`
    Amount          float64 `json:"amount" validate:"required,gt=0"`
    PaymentMethodID *int    `json:"payment_method_id,omitempty"`
    PaymentDate     *string `json:"payment_date,omitempty"`
    ReferenceNumber *string `json:"reference_number,omitempty"`
    Notes           *string `json:"notes,omitempty"`
}
