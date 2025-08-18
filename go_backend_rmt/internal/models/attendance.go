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
	LeaveID    int       `json:"leave_id" db:"leave_id"`
	EmployeeID int       `json:"employee_id" db:"employee_id"`
	StartDate  time.Time `json:"start_date" db:"start_date"`
	EndDate    time.Time `json:"end_date" db:"end_date"`
	Reason     string    `json:"reason" db:"reason"`
	Status     string    `json:"status" db:"status"`
	SyncModel
}

type LeaveRequest struct {
	EmployeeID int    `json:"employee_id" validate:"required"`
	StartDate  string `json:"start_date" validate:"required"`
	EndDate    string `json:"end_date" validate:"required"`
	Reason     string `json:"reason" validate:"required"`
}

type Holiday struct {
	HolidayID int       `json:"holiday_id" db:"holiday_id"`
	CompanyID int       `json:"company_id" db:"company_id"`
	Date      time.Time `json:"date" db:"date"`
	Name      string    `json:"name" db:"name"`
	SyncModel
}
