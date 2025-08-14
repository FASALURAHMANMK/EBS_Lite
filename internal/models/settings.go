package models

import "time"

// Setting represents a configurable key-value pair in the system
// It maps to the settings table.
type Setting struct {
	SettingID   int       `json:"setting_id" db:"setting_id"`
	CompanyID   int       `json:"company_id" db:"company_id"`
	LocationID  *int      `json:"location_id,omitempty" db:"location_id"`
	Key         string    `json:"key" db:"key"`
	Value       string    `json:"value" db:"value"`
	Description *string   `json:"description,omitempty" db:"description"`
	DataType    string    `json:"data_type" db:"data_type"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UpdateSettingsRequest is used to update multiple settings at once
// The map key represents the setting key and value represents the setting value
// Example: {"currency":"INR"}
type UpdateSettingsRequest struct {
	Settings map[string]string `json:"settings" validate:"required"`
}
