package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
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
