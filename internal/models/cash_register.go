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
	SyncModel
}

type OpenCashRegisterRequest struct {
	OpeningBalance float64 `json:"opening_balance" validate:"required"`
}

type CloseCashRegisterRequest struct {
	ClosingBalance float64 `json:"closing_balance" validate:"required"`
}
