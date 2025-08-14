package models

import "time"

// Collection represents a payment collected from a customer
// It matches the collections table schema and API documentation
// Fields like SyncStatus and timestamps are included for completeness.
type Collection struct {
	CollectionID     int       `json:"collection_id" db:"collection_id"`
	CollectionNumber string    `json:"collection_number" db:"collection_number"`
	CustomerID       int       `json:"customer_id" db:"customer_id"`
	LocationID       int       `json:"location_id" db:"location_id"`
	Amount           float64   `json:"amount" db:"amount"`
	CollectionDate   time.Time `json:"collection_date" db:"collection_date"`
	PaymentMethodID  *int      `json:"payment_method_id,omitempty" db:"payment_method_id"`
	PaymentMethod    *string   `json:"payment_method,omitempty" db:"payment_method"`
	ReferenceNumber  *string   `json:"reference_number,omitempty" db:"reference_number"`
	Notes            *string   `json:"notes,omitempty" db:"notes"`
	CreatedBy        int       `json:"created_by" db:"created_by"`
	SyncStatus       string    `json:"sync_status" db:"sync_status"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// CreateCollectionRequest defines payload for recording a collection
// Location and created_by are derived from context and not required in the request
// PaymentMethodID is used to link to payment_methods table
// ReceivedDate maps to collection_date in the database

type CreateCollectionRequest struct {
	CustomerID      int     `json:"customer_id" validate:"required"`
	Amount          float64 `json:"amount" validate:"required,gt=0"`
	PaymentMethodID *int    `json:"payment_method_id,omitempty"`
	ReceivedDate    *string `json:"received_date,omitempty"`
	ReferenceNumber *string `json:"reference,omitempty"`
	Notes           *string `json:"notes,omitempty"`
}
