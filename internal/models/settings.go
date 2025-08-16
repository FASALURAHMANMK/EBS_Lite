package models

import "time"

// Setting represents a configurable key-value pair in the system
// It maps to the settings table.
type Setting struct {
	SettingID   int       `json:"setting_id" db:"setting_id"`
	CompanyID   int       `json:"company_id" db:"company_id"`
	LocationID  *int      `json:"location_id,omitempty" db:"location_id"`
	Key         string    `json:"key" db:"key"`
	Value       JSONB     `json:"value" db:"value"`
	Description *string   `json:"description,omitempty" db:"description"`
	DataType    string    `json:"data_type" db:"data_type"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UpdateSettingsRequest is used to update multiple settings at once
// The map key represents the setting key and value represents the setting value
// Example: {"currency":"INR"}
type UpdateSettingsRequest struct {
	Settings map[string]JSONB `json:"settings" validate:"required"`
}

// CompanySettings holds company-related configuration
type CompanySettings struct {
	Name    string  `json:"name,omitempty"`
	Address *string `json:"address,omitempty"`
	Phone   *string `json:"phone,omitempty"`
	Email   *string `json:"email,omitempty"`
}

// InvoiceSettings holds invoice-related configuration
type InvoiceSettings struct {
	Prefix     *string `json:"prefix,omitempty"`
	NextNumber *int    `json:"next_number,omitempty"`
	Notes      *string `json:"notes,omitempty"`
}

// TaxSettings holds tax-related configuration
type TaxSettings struct {
	TaxName    *string  `json:"tax_name,omitempty"`
	TaxPercent *float64 `json:"tax_percent,omitempty"`
}

// DeviceControlSettings holds device control related configuration
type DeviceControlSettings struct {
	AllowRemote bool `json:"allow_remote"`
}

// PrinterProfile represents a printer configuration profile
type PrinterProfile struct {
	PrinterID    int     `json:"printer_id" db:"printer_id"`
	CompanyID    int     `json:"company_id" db:"company_id"`
	LocationID   *int    `json:"location_id,omitempty" db:"location_id"`
	Name         string  `json:"name" db:"name" validate:"required"`
	PrinterType  string  `json:"printer_type" db:"printer_type" validate:"required"`
	PaperSize    *string `json:"paper_size,omitempty" db:"paper_size"`
	Connectivity *JSONB  `json:"connectivity,omitempty" db:"connectivity"`
	IsDefault    bool    `json:"is_default" db:"is_default"`
	IsActive     bool    `json:"is_active" db:"is_active"`
}

// PaymentMethodRequest is used to create or update payment methods
type PaymentMethodRequest struct {
	Name                string `json:"name" validate:"required"`
	Type                string `json:"type" validate:"required"`
	ExternalIntegration *JSONB `json:"external_integration,omitempty"`
	IsActive            bool   `json:"is_active"`
}

// SessionLimitRequest is used to create or update maximum session limits
type SessionLimitRequest struct {
	MaxSessions int `json:"max_sessions" validate:"required"`
}
