package models

import "time"

type Attendance struct {
	AttendanceID int        `json:"attendance_id" db:"attendance_id"`
	EmployeeID   int        `json:"employee_id" db:"employee_id"`
	CheckIn      time.Time  `json:"check_in" db:"check_in"`
	CheckOut     *time.Time `json:"check_out,omitempty" db:"check_out"`
	SyncModel
}

type CheckInRequest struct {
	EmployeeID int `json:"employee_id" validate:"required"`
}

type CheckOutRequest struct {
	EmployeeID int `json:"employee_id" validate:"required"`
}

type Leave struct {
	LeaveID       int        `json:"leave_id" db:"leave_id"`
	EmployeeID    int        `json:"employee_id" db:"employee_id"`
	StartDate     time.Time  `json:"start_date" db:"start_date"`
	EndDate       time.Time  `json:"end_date" db:"end_date"`
	Reason        string     `json:"reason" db:"reason"`
	Status        string     `json:"status" db:"status"`
	ApprovedBy    *int       `json:"approved_by,omitempty" db:"approved_by"`
	ApprovedAt    *time.Time `json:"approved_at,omitempty" db:"approved_at"`
	DecisionNotes *string    `json:"decision_notes,omitempty" db:"decision_notes"`
	SyncModel
}

type LeaveRequest struct {
	EmployeeID int    `json:"employee_id" validate:"required"`
	StartDate  string `json:"start_date" validate:"required"`
	EndDate    string `json:"end_date" validate:"required"`
	Reason     string `json:"reason" validate:"required"`
}

type LeaveDecisionRequest struct {
	DecisionNotes *string `json:"decision_notes,omitempty"`
}

type LeaveWithEmployee struct {
	Leave
	EmployeeName string `json:"employee_name" db:"employee_name"`
}

type Holiday struct {
	HolidayID int       `json:"holiday_id" db:"holiday_id"`
	CompanyID int       `json:"company_id" db:"company_id"`
	Date      time.Time `json:"date" db:"date"`
	Name      string    `json:"name" db:"name"`
	SyncModel
}
