package models

// PrintReceiptRequest defines the payload to trigger a receipt print
// Type refers to the entity type e.g. sale, purchase etc.
type PrintReceiptRequest struct {
	Type        string `json:"type" validate:"required"`
	ReferenceID int    `json:"reference_id" validate:"required"`
}
