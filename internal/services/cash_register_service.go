package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type CashRegisterService struct {
	db *sql.DB
}

func NewCashRegisterService() *CashRegisterService {
	return &CashRegisterService{db: database.GetDB()}
}

func (s *CashRegisterService) GetCashRegisters(companyID, locationID int) ([]models.CashRegister, error) {
	query := `
        SELECT cr.register_id, cr.location_id, cr.date, cr.opening_balance, cr.closing_balance,
               cr.expected_balance, cr.cash_in, cr.cash_out, cr.variance,
               cr.opened_by, cr.closed_by, cr.status, cr.sync_status,
               cr.created_at, cr.updated_at
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE l.company_id = $1 AND cr.location_id = $2
        ORDER BY cr.date DESC, cr.register_id DESC`

	rows, err := s.db.Query(query, companyID, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cash registers: %w", err)
	}
	defer rows.Close()

	var registers []models.CashRegister
	for rows.Next() {
		var cr models.CashRegister
		err := rows.Scan(
			&cr.RegisterID, &cr.LocationID, &cr.Date, &cr.OpeningBalance, &cr.ClosingBalance,
			&cr.ExpectedBalance, &cr.CashIn, &cr.CashOut, &cr.Variance,
			&cr.OpenedBy, &cr.ClosedBy, &cr.Status, &cr.SyncStatus,
			&cr.CreatedAt, &cr.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan cash register: %w", err)
		}
		registers = append(registers, cr)
	}

	return registers, nil
}

func (s *CashRegisterService) OpenCashRegister(companyID, locationID, userID int, openingBalance float64) (int, error) {
	// Verify location belongs to company
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM locations WHERE location_id = $1 AND company_id = $2 AND is_deleted = FALSE`, locationID, companyID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to verify location: %w", err)
	}
	if count == 0 {
		return 0, fmt.Errorf("location not found")
	}

	// Ensure no open register exists
	var existing int
	err = s.db.QueryRow(`SELECT register_id FROM cash_register WHERE location_id = $1 AND status = 'OPEN'`, locationID).Scan(&existing)
	if err != sql.ErrNoRows {
		if err == nil {
			return 0, fmt.Errorf("cash register already open")
		}
		return 0, fmt.Errorf("failed to check open register: %w", err)
	}

	var registerID int
	err = s.db.QueryRow(`
        INSERT INTO cash_register (location_id, date, opening_balance, expected_balance, opened_by)
        VALUES ($1, CURRENT_DATE, $2, $2, $3)
        RETURNING register_id`,
		locationID, openingBalance, userID).Scan(&registerID)
	if err != nil {
		return 0, fmt.Errorf("failed to open cash register: %w", err)
	}

	return registerID, nil
}

func (s *CashRegisterService) CloseCashRegister(companyID, locationID, userID int, closingBalance float64) error {
	var registerID int
	var openingBalance, cashIn, cashOut float64
	err := s.db.QueryRow(`
        SELECT cr.register_id, cr.opening_balance, cr.cash_in, cr.cash_out
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
    `, locationID, companyID).Scan(&registerID, &openingBalance, &cashIn, &cashOut)
	if err == sql.ErrNoRows {
		return fmt.Errorf("no open cash register")
	}
	if err != nil {
		return fmt.Errorf("failed to get open register: %w", err)
	}

	expected := openingBalance + cashIn - cashOut
	variance := closingBalance - expected

	_, err = s.db.Exec(`
        UPDATE cash_register
        SET closing_balance = $1,
            expected_balance = $2,
            variance = $3,
            closed_by = $4,
            status = 'CLOSED',
            updated_at = $5
        WHERE register_id = $6`,
		closingBalance, expected, variance, userID, time.Now(), registerID)
	if err != nil {
		return fmt.Errorf("failed to close cash register: %w", err)
	}

	return nil
}
