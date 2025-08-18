package models

import "time"

// AuditLog represents an entry in the audit_log table
// It tracks changes and actions performed in the system.
type AuditLog struct {
	LogID        int       `json:"log_id" db:"log_id"`
	UserID       *int      `json:"user_id,omitempty" db:"user_id"`
	Action       string    `json:"action" db:"action"`
	TableName    string    `json:"table_name" db:"table_name"`
	RecordID     *int      `json:"record_id,omitempty" db:"record_id"`
	OldValue     *JSONB    `json:"old_value,omitempty" db:"old_value"`
	NewValue     *JSONB    `json:"new_value,omitempty" db:"new_value"`
	FieldChanges *JSONB    `json:"field_changes,omitempty" db:"field_changes"`
	IPAddress    *string   `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent    *string   `json:"user_agent,omitempty" db:"user_agent"`
	Timestamp    time.Time `json:"timestamp" db:"timestamp"`
}
