package models

import "time"

type HolidayDetail struct {
	HolidayID   int       `json:"holiday_id" db:"holiday_id"`
	CompanyID   int       `json:"company_id" db:"company_id"`
	Date        time.Time `json:"date" db:"date"`
	Description *string   `json:"description,omitempty" db:"description"`
	IsRecurring bool      `json:"is_recurring" db:"is_recurring"`
	SyncModel
}

type CreateHolidayRequest struct {
	Date        time.Time `json:"date" validate:"required"`
	Description *string   `json:"description,omitempty"`
	IsRecurring bool      `json:"is_recurring"`
}
