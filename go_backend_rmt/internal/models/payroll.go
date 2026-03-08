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
	EmployeeID    int     `json:"employee_id" validate:"required"`
	Month         string  `json:"month" validate:"required"`
	BasicSalary   float64 `json:"basic_salary" validate:"required,gte=0"`
	Allowances    float64 `json:"allowances" validate:"gte=0"`
	Deductions    float64 `json:"deductions" validate:"gte=0"`
	AutoCalculate *bool   `json:"auto_calculate,omitempty"`
}

type PayrollCalculation struct {
	EmployeeID          int       `json:"employee_id"`
	Month               string    `json:"month"`
	PayPeriodStart      time.Time `json:"pay_period_start"`
	PayPeriodEnd        time.Time `json:"pay_period_end"`
	BaseMonthlySalary   float64   `json:"base_monthly_salary"`
	WorkingDays         int       `json:"working_days"`
	PayableDays         float64   `json:"payable_days"`
	PresentDays         float64   `json:"present_days"`
	ApprovedLeaveDays   float64   `json:"approved_leave_days"`
	UnpaidAbsenceDays   float64   `json:"unpaid_absence_days"`
	ProratedBasicSalary float64   `json:"prorated_basic_salary"`
}

type SalaryComponent struct {
	ComponentID int     `json:"component_id" db:"component_id"`
	PayrollID   int     `json:"payroll_id" db:"payroll_id"`
	Type        string  `json:"type" db:"type"`
	Amount      float64 `json:"amount" db:"amount"`
	SyncModel
}

type AddComponentRequest struct {
	Type   string  `json:"type" validate:"required"`
	Amount float64 `json:"amount" validate:"required,gt=0"`
}

type Advance struct {
	AdvanceID int       `json:"advance_id" db:"advance_id"`
	PayrollID int       `json:"payroll_id" db:"payroll_id"`
	Amount    float64   `json:"amount" db:"amount"`
	Date      time.Time `json:"date" db:"date"`
	SyncModel
}

type AdvanceRequest struct {
	Amount float64 `json:"amount" validate:"required,gt=0"`
	Date   string  `json:"date" validate:"required"`
}

type Deduction struct {
	DeductionID int       `json:"deduction_id" db:"deduction_id"`
	PayrollID   int       `json:"payroll_id" db:"payroll_id"`
	Type        string    `json:"type" db:"type"`
	Amount      float64   `json:"amount" db:"amount"`
	Date        time.Time `json:"date" db:"date"`
	SyncModel
}

type DeductionRequest struct {
	Type   string  `json:"type" validate:"required"`
	Amount float64 `json:"amount" validate:"required,gt=0"`
	Date   string  `json:"date" validate:"required"`
}

type Payslip struct {
	Payroll    Payroll           `json:"payroll"`
	Components []SalaryComponent `json:"components"`
	Advances   []Advance         `json:"advances"`
	Deductions []Deduction       `json:"deductions"`
	NetPay     float64           `json:"net_pay"`
}
