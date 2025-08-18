package models

// NumberingSequence defines document numbering settings for a company/location
// allowing configurable prefixes and sequence lengths.
type NumberingSequence struct {
	SequenceID     int     `json:"sequence_id" db:"sequence_id"`
	CompanyID      int     `json:"company_id" db:"company_id" validate:"required"`
	LocationID     *int    `json:"location_id,omitempty" db:"location_id"`
	Name           string  `json:"name" db:"name" validate:"required"`
	Prefix         *string `json:"prefix,omitempty" db:"prefix"`
	SequenceLength int     `json:"sequence_length" db:"sequence_length"`
	CurrentNumber  int     `json:"current_number" db:"current_number"`
	BaseModel
}

// CreateNumberingSequenceRequest is the payload for creating a numbering sequence.
type CreateNumberingSequenceRequest struct {
	CompanyID      int     `json:"company_id" validate:"required"`
	LocationID     *int    `json:"location_id,omitempty"`
	Name           string  `json:"name" validate:"required"`
	Prefix         *string `json:"prefix,omitempty"`
	SequenceLength int     `json:"sequence_length" validate:"required"`
	StartFrom      *int    `json:"start_from,omitempty"`
}

// UpdateNumberingSequenceRequest is the payload for updating a numbering sequence.
type UpdateNumberingSequenceRequest struct {
	Name           *string `json:"name,omitempty" validate:"omitempty"`
	Prefix         *string `json:"prefix,omitempty" validate:"omitempty"`
	SequenceLength *int    `json:"sequence_length,omitempty" validate:"omitempty"`
}
