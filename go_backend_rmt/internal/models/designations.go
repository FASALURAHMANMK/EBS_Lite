package models

import "time"

type Designation struct {
	DesignationID    int       `json:"designation_id" db:"designation_id"`
	CompanyID        int       `json:"company_id" db:"company_id"`
	DepartmentID     *int      `json:"department_id,omitempty" db:"department_id"`
	DefaultAppRoleID *int      `json:"default_app_role_id,omitempty" db:"default_app_role_id"`
	Name             string    `json:"name" db:"name" validate:"required,min=2,max=100"`
	Description      *string   `json:"description,omitempty" db:"description"`
	IsActive         bool      `json:"is_active" db:"is_active"`
	CreatedBy        int       `json:"created_by" db:"created_by"`
	UpdatedBy        *int      `json:"updated_by,omitempty" db:"updated_by"`
	SyncStatus       string    `json:"sync_status" db:"sync_status"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
	IsDeleted        bool      `json:"is_deleted" db:"is_deleted"`
}

type CreateDesignationRequest struct {
	DepartmentID     int     `json:"department_id" validate:"required,gt=0"`
	DefaultAppRoleID *int    `json:"default_app_role_id,omitempty"`
	Name             string  `json:"name" validate:"required,min=2,max=100"`
	Description      *string `json:"description,omitempty"`
	IsActive         *bool   `json:"is_active,omitempty"`
}

type UpdateDesignationRequest struct {
	DepartmentID *int `json:"department_id,omitempty"`
	// If provided as 0, clears the default app role.
	DefaultAppRoleID *int    `json:"default_app_role_id,omitempty"`
	Name             *string `json:"name,omitempty" validate:"omitempty,min=2,max=100"`
	Description      *string `json:"description,omitempty"`
	IsActive         *bool   `json:"is_active,omitempty"`
}
