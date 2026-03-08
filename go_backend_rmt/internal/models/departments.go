package models

import "time"

type Department struct {
	DepartmentID int       `json:"department_id" db:"department_id"`
	CompanyID    int       `json:"company_id" db:"company_id"`
	Name         string    `json:"name" db:"name" validate:"required,min=2,max=100"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	CreatedBy    int       `json:"created_by" db:"created_by"`
	UpdatedBy    *int      `json:"updated_by,omitempty" db:"updated_by"`
	SyncStatus   string    `json:"sync_status" db:"sync_status"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
	IsDeleted    bool      `json:"is_deleted" db:"is_deleted"`
}

type CreateDepartmentRequest struct {
	Name     string `json:"name" validate:"required,min=2,max=100"`
	IsActive *bool  `json:"is_active,omitempty"`
}

type UpdateDepartmentRequest struct {
	Name     *string `json:"name,omitempty" validate:"omitempty,min=2,max=100"`
	IsActive *bool   `json:"is_active,omitempty"`
}
