package models

import "time"

type CashRegisterEvent struct {
	EventID       int       `json:"event_id" db:"event_id"`
	RegisterID    int       `json:"register_id" db:"register_id"`
	LocationID    int       `json:"location_id" db:"location_id"`
	EventType     string    `json:"event_type" db:"event_type"`
	Direction     *string   `json:"direction,omitempty" db:"direction"`
	Amount        *float64  `json:"amount,omitempty" db:"amount"`
	ReasonCode    *string   `json:"reason_code,omitempty" db:"reason_code"`
	Notes         *string   `json:"notes,omitempty" db:"notes"`
	Denominations *JSONB    `json:"denominations,omitempty" db:"denominations"`
	CreatedBy     int       `json:"created_by" db:"created_by"`
	SessionID     *string   `json:"session_id,omitempty" db:"session_id"`
	RequestID     *string   `json:"request_id,omitempty" db:"request_id"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
}

type CashRegisterMovementRequest struct {
	Direction  string  `json:"direction" validate:"required,oneof=IN OUT"`
	Amount     float64 `json:"amount" validate:"required,gt=0"`
	ReasonCode string  `json:"reason_code" validate:"required"`
	Notes      *string `json:"notes,omitempty"`
}

type ForceCloseCashRegisterRequest struct {
	Reason         string   `json:"reason" validate:"required"`
	ClosingBalance *float64 `json:"closing_balance,omitempty"`
	Denominations  *JSONB   `json:"denominations,omitempty"`
}
