package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// JSONB is a custom type for handling JSONB fields
type JSONB map[string]interface{}

func (j JSONB) Value() (driver.Value, error) {
	return json.Marshal(j)
}

func (j *JSONB) Scan(value interface{}) error {
	if value == nil {
		*j = make(map[string]interface{})
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into JSONB", value)
	}

	if len(bytes) == 0 {
		*j = make(map[string]interface{})
		return nil
	}

	if err := json.Unmarshal(bytes, j); err == nil {
		return nil
	}

	var scalar interface{}
	if err := json.Unmarshal(bytes, &scalar); err == nil {
		*j = JSONB{"value": scalar}
		return nil
	}

	*j = JSONB{"value": string(bytes)}
	return nil
}

// BaseModel contains common fields for all models
type BaseModel struct {
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt *time.Time `json:"updated_at,omitempty" db:"updated_at"`
	IsDeleted bool       `json:"is_deleted,omitempty" db:"is_deleted"`
}

// SyncModel adds sync-related fields
type SyncModel struct {
	BaseModel
	SyncStatus string `json:"sync_status" db:"sync_status"`
}

// APIResponse is the standard response format
type APIResponse struct {
	Success   bool        `json:"success"`
	Message   string      `json:"message,omitempty"`
	Data      interface{} `json:"data,omitempty"`
	Error     string      `json:"error,omitempty"`
	RequestID string      `json:"request_id,omitempty"`
	Meta      *Meta       `json:"meta,omitempty"`
}

// Meta contains pagination and other metadata
type Meta struct {
	Page       int `json:"page,omitempty"`
	PerPage    int `json:"per_page,omitempty"`
	Total      int `json:"total,omitempty"`
	TotalPages int `json:"total_pages,omitempty"`
}
