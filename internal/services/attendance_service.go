package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type AttendanceService struct {
	db *sql.DB
}

func NewAttendanceService() *AttendanceService {
	return &AttendanceService{db: database.GetDB()}
}

// AutoMarkNonWorkingDays inserts ABSENT attendance records for holidays or weekends.
func (s *AttendanceService) AutoMarkNonWorkingDays(companyID int, date time.Time, userID int) error {
	weekday := date.Weekday()
	isWeekend := weekday == time.Saturday || weekday == time.Sunday

	var isHoliday bool
	err := s.db.QueryRow(`SELECT EXISTS(
                SELECT 1 FROM holidays
                WHERE company_id = $1 AND is_deleted = FALSE AND (
                        date = $2 OR (is_recurring = TRUE AND EXTRACT(MONTH FROM date) = $3 AND EXTRACT(DAY FROM date) = $4)
                )
        )`, companyID, date, date.Month(), date.Day()).Scan(&isHoliday)
	if err != nil {
		return fmt.Errorf("failed to check holidays: %w", err)
	}

	if !isWeekend && !isHoliday {
		return nil
	}

	note := "Weekend"
	if isHoliday {
		note = "Holiday"
		var desc sql.NullString
		if err := s.db.QueryRow(`SELECT description FROM holidays
                        WHERE company_id = $1 AND is_deleted = FALSE AND (
                                date = $2 OR (is_recurring = TRUE AND EXTRACT(MONTH FROM date) = $3 AND EXTRACT(DAY FROM date) = $4)
                        ) LIMIT 1`,
			companyID, date, date.Month(), date.Day()).Scan(&desc); err == nil && desc.Valid && desc.String != "" {
			note = desc.String
		}
	}

	_, err = s.db.Exec(`INSERT INTO attendance (employee_id, date, status, notes, created_by)
                SELECT employee_id, $1, 'ABSENT', $2, $3
                FROM employees
                WHERE company_id = $4 AND is_deleted = FALSE
                ON CONFLICT (employee_id, date) DO NOTHING`,
		date, note, userID, companyID)
	if err != nil {
		return fmt.Errorf("failed to insert attendance: %w", err)
	}
	return nil
}
func (s *AttendanceService) CheckIn(companyID, employeeID int) (*models.Attendance, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM employees WHERE employee_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, employeeID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify employee: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("employee not found")
	}
	var att models.Attendance
	err = s.db.QueryRow(`INSERT INTO attendance (employee_id, check_in) VALUES ($1, CURRENT_TIMESTAMP) RETURNING attendance_id, check_in, created_at`, employeeID).Scan(&att.AttendanceID, &att.CheckIn, &att.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to check in: %w", err)
	}
	att.EmployeeID = employeeID
	att.SyncStatus = "SYNCED"
	return &att, nil
}

func (s *AttendanceService) CheckOut(companyID, employeeID int) (*models.Attendance, error) {
	var att models.Attendance
	err := s.db.QueryRow(`UPDATE attendance SET check_out = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = (
                SELECT attendance_id FROM attendance a JOIN employees e ON a.employee_id = e.employee_id
                WHERE a.employee_id = $1 AND e.company_id = $2 AND a.check_out IS NULL ORDER BY a.check_in DESC LIMIT 1)
                RETURNING attendance_id, employee_id, check_in, check_out`, employeeID, companyID).Scan(&att.AttendanceID, &att.EmployeeID, &att.CheckIn, &att.CheckOut)
	if err != nil {
		return nil, fmt.Errorf("failed to check out: %w", err)
	}
	att.SyncStatus = "SYNCED"
	return &att, nil
}

func (s *AttendanceService) ApplyLeave(companyID int, req *models.LeaveRequest) (*models.Leave, error) {
	start, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start date")
	}
	end, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		return nil, fmt.Errorf("invalid end date")
	}
	var exists bool
	err = s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM employees WHERE employee_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, req.EmployeeID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify employee: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("employee not found")
	}
	var leave models.Leave
	err = s.db.QueryRow(`INSERT INTO leaves (employee_id, start_date, end_date, reason, status) VALUES ($1,$2,$3,$4,'PENDING') RETURNING leave_id, status, created_at`, req.EmployeeID, start, end, req.Reason).Scan(&leave.LeaveID, &leave.Status, &leave.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to apply leave: %w", err)
	}
	leave.EmployeeID = req.EmployeeID
	leave.StartDate = start
	leave.EndDate = end
	leave.Reason = req.Reason
	leave.SyncStatus = "SYNCED"
	return &leave, nil
}

func (s *AttendanceService) GetHolidays(companyID int) ([]models.Holiday, error) {
	rows, err := s.db.Query(`SELECT holiday_id, company_id, date, name, sync_status, created_at, updated_at, is_deleted FROM holidays WHERE (company_id = $1 OR company_id IS NULL) AND is_deleted = FALSE`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get holidays: %w", err)
	}
	defer rows.Close()

	var holidays []models.Holiday
	for rows.Next() {
		var h models.Holiday
		if err := rows.Scan(&h.HolidayID, &h.CompanyID, &h.Date, &h.Name, &h.SyncStatus, &h.CreatedAt, &h.UpdatedAt, &h.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan holiday: %w", err)
		}
		holidays = append(holidays, h)
	}
	return holidays, nil
}
