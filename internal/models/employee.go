package models

import "time"

type Employee struct {
	EmployeeID   int        `json:"employee_id" db:"employee_id"`
	CompanyID    int        `json:"company_id" db:"company_id"`
	LocationID   *int       `json:"location_id,omitempty" db:"location_id"`
	EmployeeCode *string    `json:"employee_code,omitempty" db:"employee_code"`
	Name         string     `json:"name" db:"name" validate:"required,min=2,max=255"`
	Phone        *string    `json:"phone,omitempty" db:"phone"`
	Email        *string    `json:"email,omitempty" db:"email" validate:"omitempty,email"`
	Address      *string    `json:"address,omitempty" db:"address"`
	Position     *string    `json:"position,omitempty" db:"position"`
	Department   *string    `json:"department,omitempty" db:"department"`
	Salary       *float64   `json:"salary,omitempty" db:"salary"`
	HireDate     *time.Time `json:"hire_date,omitempty" db:"hire_date"`
	IsActive     bool       `json:"is_active" db:"is_active"`
	LastCheckIn  *time.Time `json:"last_check_in,omitempty" db:"last_check_in"`
	LastCheckOut *time.Time `json:"last_check_out,omitempty" db:"last_check_out"`
	LeaveBalance *float64   `json:"leave_balance,omitempty" db:"leave_balance"`
	SyncModel
}

type CreateEmployeeRequest struct {
	LocationID   *int       `json:"location_id,omitempty"`
	EmployeeCode *string    `json:"employee_code,omitempty"`
	Name         string     `json:"name" validate:"required,min=2,max=255"`
	Phone        *string    `json:"phone,omitempty"`
	Email        *string    `json:"email,omitempty" validate:"omitempty,email"`
	Address      *string    `json:"address,omitempty"`
	Position     *string    `json:"position,omitempty"`
	Department   *string    `json:"department,omitempty"`
	Salary       *float64   `json:"salary,omitempty"`
	HireDate     *time.Time `json:"hire_date,omitempty"`
	IsActive     *bool      `json:"is_active,omitempty"`
	LeaveBalance *float64   `json:"leave_balance,omitempty"`
}

type UpdateEmployeeRequest struct {
	LocationID   *int       `json:"location_id,omitempty"`
	EmployeeCode *string    `json:"employee_code,omitempty"`
	Name         *string    `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Phone        *string    `json:"phone,omitempty"`
	Email        *string    `json:"email,omitempty" validate:"omitempty,email"`
	Address      *string    `json:"address,omitempty"`
	Position     *string    `json:"position,omitempty"`
	Department   *string    `json:"department,omitempty"`
	Salary       *float64   `json:"salary,omitempty"`
	HireDate     *time.Time `json:"hire_date,omitempty"`
	IsActive     *bool      `json:"is_active,omitempty"`
	LeaveBalance *float64   `json:"leave_balance,omitempty"`
}
