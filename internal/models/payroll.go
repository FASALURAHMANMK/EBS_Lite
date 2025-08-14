package models

import "time"

type Payroll struct {
	PayrollID       int       `json:"payroll_id" db:"payroll_id"`
	EmployeeID      int       `json:"employee_id" db:"employee_id"`
	PayPeriodStart  time.Time `json:"pay_period_start" db:"pay_period_start"`
	PayPeriodEnd    time.Time `json:"pay_period_end" db:"pay_period_end"`
	BasicSalary     float64   `json:"basic_salary" db:"basic_salary"`
	GrossSalary     float64   `json:"gross_salary" db:"gross_salary"`
	TotalDeductions float64   `json:"total_deductions" db:"total_deductions"`
	NetSalary       float64   `json:"net_salary" db:"net_salary"`
	Status          string    `json:"status" db:"status"`
	ProcessedBy     *int      `json:"processed_by,omitempty" db:"processed_by"`
	SyncModel
}

type CreatePayrollRequest struct {
	EmployeeID  int     `json:"employee_id" validate:"required"`
	Month       string  `json:"month" validate:"required"`
	BasicSalary float64 `json:"basic_salary" validate:"required,gte=0"`
	Allowances  float64 `json:"allowances" validate:"gte=0"`
	Deductions  float64 `json:"deductions" validate:"gte=0"`
}
