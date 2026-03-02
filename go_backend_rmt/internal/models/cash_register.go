package models

import "time"

type CashRegister struct {
	RegisterID      int       `json:"register_id" db:"register_id"`
	LocationID      int       `json:"location_id" db:"location_id"`
	Date            time.Time `json:"date" db:"date"`
	OpeningBalance  float64   `json:"opening_balance" db:"opening_balance"`
	ClosingBalance  *float64  `json:"closing_balance,omitempty" db:"closing_balance"`
	ExpectedBalance float64   `json:"expected_balance" db:"expected_balance"`
	CashIn          float64   `json:"cash_in" db:"cash_in"`
	CashOut         float64   `json:"cash_out" db:"cash_out"`
	Variance        float64   `json:"variance" db:"variance"`
	OpenedBy        *int      `json:"opened_by,omitempty" db:"opened_by"`
	ClosedBy        *int      `json:"closed_by,omitempty" db:"closed_by"`
	Status          string    `json:"status" db:"status"`
	TrainingMode    bool      `json:"training_mode" db:"training_mode"`
	// Updated whenever training mode is enabled/disabled.
	TrainingModeUpdatedAt *time.Time `json:"training_mode_updated_at,omitempty" db:"training_mode_updated_at"`
	TrainingModeUpdatedBy *int       `json:"training_mode_updated_by,omitempty" db:"training_mode_updated_by"`
	SyncModel
}

type OpenCashRegisterRequest struct {
	OpeningBalance float64 `json:"opening_balance" validate:"required"`
}

type CloseCashRegisterRequest struct {
	ClosingBalance float64 `json:"closing_balance" validate:"required"`
	Denominations  *JSONB  `json:"denominations,omitempty"`
}

type CashTallyRequest struct {
	Count float64 `json:"count" validate:"required"`
	Notes *string `json:"notes,omitempty"`
	// Optional breakdown captured as a JSON object, e.g. {"100":2,"50":1}
	Denominations *JSONB `json:"denominations,omitempty"`
}
