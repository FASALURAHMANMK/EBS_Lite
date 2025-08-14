package models

import (
	"time"
)

type User struct {
	UserID            int        `json:"user_id" db:"user_id"`
	CompanyID         *int       `json:"company_id,omitempty" db:"company_id"` // CHANGE: int -> *int
	LocationID        *int       `json:"location_id,omitempty" db:"location_id"`
	RoleID            *int       `json:"role_id,omitempty" db:"role_id"` // CHANGE: int -> *int
	Username          string     `json:"username" db:"username" validate:"required,min=3,max=50"`
	Email             string     `json:"email" db:"email" validate:"required,email"`
	PasswordHash      string     `json:"-" db:"password_hash"`
	FirstName         *string    `json:"first_name,omitempty" db:"first_name"`
	LastName          *string    `json:"last_name,omitempty" db:"last_name"`
	Phone             *string    `json:"phone,omitempty" db:"phone"`
	PreferredLanguage *string    `json:"preferred_language,omitempty" db:"preferred_language"`
	SecondaryLanguage *string    `json:"secondary_language,omitempty" db:"secondary_language"`
	MaxAllowedDevices int        `json:"max_allowed_devices" db:"max_allowed_devices"`
	IsLocked          bool       `json:"is_locked" db:"is_locked"`
	IsActive          bool       `json:"is_active" db:"is_active"`
	LastLogin         *time.Time `json:"last_login,omitempty" db:"last_login"`
	SyncModel
}

type UserResponse struct {
	UserID            int        `json:"user_id"`
	Username          string     `json:"username"`
	Email             string     `json:"email"`
	FirstName         *string    `json:"first_name,omitempty"`
	LastName          *string    `json:"last_name,omitempty"`
	Phone             *string    `json:"phone,omitempty"`
	RoleID            *int       `json:"role_id,omitempty"` // CHANGE: int -> *int
	LocationID        *int       `json:"location_id,omitempty"`
	CompanyID         *int       `json:"company_id,omitempty"` // CHANGE: int -> *int
	IsActive          bool       `json:"is_active"`
	IsLocked          bool       `json:"is_locked"`
	PreferredLanguage *string    `json:"preferred_language,omitempty"`
	SecondaryLanguage *string    `json:"secondary_language,omitempty"`
	LastLogin         *time.Time `json:"last_login,omitempty"`
	Permissions       []string   `json:"permissions,omitempty"`
}
type CreateUserRequest struct {
	Username          string  `json:"username" validate:"required,min=3,max=50"`
	Email             string  `json:"email" validate:"required,email"`
	Password          string  `json:"password" validate:"required,min=6"`
	FirstName         *string `json:"first_name,omitempty"`
	LastName          *string `json:"last_name,omitempty"`
	Phone             *string `json:"phone,omitempty"`
	RoleID            *int    `json:"role_id,omitempty"`
	LocationID        *int    `json:"location_id,omitempty"`
	CompanyID         int     `json:"company_id" validate:"required"`
	PreferredLanguage *string `json:"preferred_language,omitempty"`
	SecondaryLanguage *string `json:"secondary_language,omitempty"`
}

type UpdateUserRequest struct {
	FirstName         *string `json:"first_name,omitempty"`
	LastName          *string `json:"last_name,omitempty"`
	Phone             *string `json:"phone,omitempty"`
	IsActive          *bool   `json:"is_active,omitempty"`
	IsLocked          *bool   `json:"is_locked,omitempty"`
	RoleID            *int    `json:"role_id,omitempty"`
	LocationID        *int    `json:"location_id,omitempty"`
	PreferredLanguage *string `json:"preferred_language,omitempty"`
	SecondaryLanguage *string `json:"secondary_language,omitempty"`
}

type UserPreference struct {
	PreferenceID int    `json:"preference_id" db:"preference_id"`
	UserID       int    `json:"user_id" db:"user_id"`
	Key          string `json:"key" db:"key"`
	Value        string `json:"value" db:"value"`
}

type DeviceSession struct {
	SessionID    string     `json:"session_id" db:"session_id"`
	UserID       int        `json:"user_id" db:"user_id"`
	DeviceID     string     `json:"device_id" db:"device_id"`
	DeviceName   *string    `json:"device_name,omitempty" db:"device_name"`
	IPAddress    *string    `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent    *string    `json:"user_agent,omitempty" db:"user_agent"`
	LastSeen     time.Time  `json:"last_seen" db:"last_seen"`
	LastSyncTime *time.Time `json:"last_sync_time,omitempty" db:"last_sync_time"`
	IsActive     bool       `json:"is_active" db:"is_active"`
	IsStale      bool       `json:"is_stale" db:"is_stale"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
}
