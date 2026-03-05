package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/google/uuid"
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
               cr.opened_by, cr.closed_by, cr.status,
               COALESCE(cr.training_mode, FALSE) AS training_mode,
               cr.training_mode_updated_at, cr.training_mode_updated_by,
               cr.sync_status,
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
			&cr.OpenedBy, &cr.ClosedBy, &cr.Status,
			&cr.TrainingMode, &cr.TrainingModeUpdatedAt, &cr.TrainingModeUpdatedBy,
			&cr.SyncStatus,
			&cr.CreatedAt, &cr.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan cash register: %w", err)
		}
		registers = append(registers, cr)
	}

	return registers, nil
}

func (s *CashRegisterService) SetTrainingMode(
	companyID, locationID, userID int,
	enabled bool,
	sessionID, requestID string,
	ip, ua *string,
) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var registerID int
	var current bool
	err = tx.QueryRow(`
        SELECT cr.register_id, COALESCE(cr.training_mode, FALSE)
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        FOR UPDATE
    `, locationID, companyID).Scan(&registerID, &current)
	if err == sql.ErrNoRows {
		return fmt.Errorf("no open cash register")
	}
	if err != nil {
		return fmt.Errorf("failed to get open register: %w", err)
	}

	if current == enabled {
		// Idempotent: already in desired mode.
		return tx.Commit()
	}

	now := time.Now()
	if _, err := tx.Exec(`
        UPDATE cash_register
        SET training_mode = $1,
            training_mode_updated_at = $2,
            training_mode_updated_by = $3,
            updated_at = $2
        WHERE register_id = $4
    `, enabled, now, userID, registerID); err != nil {
		return fmt.Errorf("failed to update training mode: %w", err)
	}

	eventType := "TRAINING_DISABLED"
	action := "TRAINING_DISABLED"
	if enabled {
		eventType = "TRAINING_ENABLED"
		action = "TRAINING_ENABLED"
	}

	if _, err := s.insertCashRegisterEvent(tx, registerID, locationID, nil, userID, sessionID, requestID, eventType, nil); err != nil {
		return err
	}

	fieldChanges := models.JSONB{
		"event_type":    eventType,
		"register_id":   registerID,
		"location_id":   locationID,
		"training_mode": enabled,
		"request_id":    requestID,
		"session_id":    sessionID,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, action, "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return fmt.Errorf("failed to log audit: %w", err)
	}

	return tx.Commit()
}

func (s *CashRegisterService) OpenCashRegister(
	companyID, locationID, userID int,
	openingBalance float64,
	sessionID, requestID string,
	ip, ua *string,
) (int, error) {
	// Verify location belongs to company (no tx needed).
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM locations WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE`, locationID, companyID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to verify location: %w", err)
	}
	if count == 0 {
		return 0, fmt.Errorf("location not found")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Ensure no open register exists
	var existing int
	err = tx.QueryRow(`SELECT register_id FROM cash_register WHERE location_id = $1 AND status = 'OPEN'`, locationID).Scan(&existing)
	if err != sql.ErrNoRows {
		if err == nil {
			return 0, fmt.Errorf("cash register already open")
		}
		return 0, fmt.Errorf("failed to check open register: %w", err)
	}

	now := time.Now()
	openedSessionID := uuidOrNil(sessionID)
	var registerID int
	err = tx.QueryRow(`
        INSERT INTO cash_register (location_id, date, opening_balance, closing_balance, expected_balance, cash_in, cash_out, variance, opened_by, status, opened_at, opened_session_id, opened_request_id)
        VALUES ($1, CURRENT_DATE, $2, NULL, $2, 0, 0, 0, $3, 'OPEN', $4, $5, $6)
        RETURNING register_id`,
		locationID, openingBalance, userID, now, openedSessionID, nullIfEmptyString(requestID),
	).Scan(&registerID)
	if err != nil {
		return 0, fmt.Errorf("failed to open cash register: %w", err)
	}

	if _, err := s.insertCashRegisterEvent(
		tx,
		registerID,
		locationID,
		&models.CashRegisterMovementRequest{
			Direction:  "IN",
			Amount:     0,
			ReasonCode: "OPEN",
		},
		userID,
		sessionID,
		requestID,
		"OPEN",
		nil,
	); err != nil {
		return 0, err
	}

	fieldChanges := models.JSONB{
		"event_type":  "OPEN",
		"register_id": registerID,
		"location_id": locationID,
		"request_id":  requestID,
		"session_id":  sessionID,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, "OPEN", "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return 0, fmt.Errorf("failed to log audit: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit: %w", err)
	}

	return registerID, nil
}

func (s *CashRegisterService) CloseCashRegister(
	companyID, locationID, userID int,
	closingBalance float64,
	denominations *models.JSONB,
	sessionID, requestID string,
	ip, ua *string,
) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var registerID int
	var openingBalance, cashIn, cashOut float64
	err = tx.QueryRow(`
        SELECT cr.register_id, cr.opening_balance, cr.cash_in, cr.cash_out
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        FOR UPDATE
    `, locationID, companyID).Scan(&registerID, &openingBalance, &cashIn, &cashOut)
	if err == sql.ErrNoRows {
		return fmt.Errorf("no open cash register")
	}
	if err != nil {
		return fmt.Errorf("failed to get open register: %w", err)
	}

	expected := openingBalance + cashIn - cashOut
	variance := closingBalance - expected

	now := time.Now()
	closedSessionID := uuidOrNil(sessionID)
	_, err = tx.Exec(`
        UPDATE cash_register
        SET closing_balance = $1,
            expected_balance = $2,
            variance = $3,
            closed_by = $4,
            status = 'CLOSED',
            closed_at = $5,
            closed_session_id = $6,
            closed_request_id = $7,
            updated_at = $5
        WHERE register_id = $8`,
		closingBalance,
		expected,
		variance,
		userID,
		now,
		closedSessionID,
		nullIfEmptyString(requestID),
		registerID,
	)
	if err != nil {
		return fmt.Errorf("failed to close cash register: %w", err)
	}

	if _, err := s.insertCashRegisterEvent(tx, registerID, locationID, nil, userID, sessionID, requestID, "CLOSE", denominations); err != nil {
		return err
	}

	fieldChanges := models.JSONB{
		"event_type":       "CLOSE",
		"register_id":      registerID,
		"location_id":      locationID,
		"closing_balance":  closingBalance,
		"expected_balance": expected,
		"variance":         variance,
		"request_id":       requestID,
		"session_id":       sessionID,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, "CLOSE", "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return fmt.Errorf("failed to log audit: %w", err)
	}

	return tx.Commit()
}

func (s *CashRegisterService) RecordMovement(
	companyID, locationID, userID int,
	req *models.CashRegisterMovementRequest,
	sessionID, requestID string,
	ip, ua *string,
) (int, error) {
	if req == nil {
		return 0, fmt.Errorf("request is nil")
	}
	if req.Direction != "IN" && req.Direction != "OUT" {
		return 0, fmt.Errorf("invalid direction")
	}
	if req.Amount <= 0 {
		return 0, fmt.Errorf("amount must be greater than 0")
	}
	if req.ReasonCode == "" {
		return 0, fmt.Errorf("reason_code is required")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var registerID int
	var openingBalance, cashIn, cashOut float64
	err = tx.QueryRow(`
        SELECT cr.register_id, cr.opening_balance, cr.cash_in, cr.cash_out
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        FOR UPDATE
    `, locationID, companyID).Scan(&registerID, &openingBalance, &cashIn, &cashOut)
	if err == sql.ErrNoRows {
		return 0, fmt.Errorf("no open cash register")
	}
	if err != nil {
		return 0, fmt.Errorf("failed to get open register: %w", err)
	}

	if req.Direction == "IN" {
		cashIn += req.Amount
	} else {
		cashOut += req.Amount
	}
	expected := openingBalance + cashIn - cashOut

	if _, err := tx.Exec(`
        UPDATE cash_register
        SET cash_in = $1,
            cash_out = $2,
            expected_balance = $3,
            updated_at = $4
        WHERE register_id = $5
    `, cashIn, cashOut, expected, time.Now(), registerID); err != nil {
		return 0, fmt.Errorf("failed to update cash register: %w", err)
	}

	eventType := "CASH_IN"
	if req.Direction == "OUT" {
		eventType = "CASH_OUT"
	}
	eventID, err := s.insertCashRegisterEvent(tx, registerID, locationID, req, userID, sessionID, requestID, eventType, nil)
	if err != nil {
		return 0, err
	}

	fieldChanges := models.JSONB{
		"event_type":       eventType,
		"register_id":      registerID,
		"location_id":      locationID,
		"direction":        req.Direction,
		"amount":           req.Amount,
		"reason_code":      req.ReasonCode,
		"request_id":       requestID,
		"session_id":       sessionID,
		"expected_balance": expected,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, "CASH_MOVEMENT", "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return 0, fmt.Errorf("failed to log audit: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit: %w", err)
	}

	return eventID, nil
}

func (s *CashRegisterService) ForceClose(
	companyID, locationID, userID int,
	req *models.ForceCloseCashRegisterRequest,
	sessionID, requestID string,
	ip, ua *string,
) error {
	if req == nil {
		return fmt.Errorf("request is nil")
	}
	if req.Reason == "" {
		return fmt.Errorf("reason is required")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var registerID int
	var openingBalance, cashIn, cashOut float64
	err = tx.QueryRow(`
        SELECT cr.register_id, cr.opening_balance, cr.cash_in, cr.cash_out
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        FOR UPDATE
    `, locationID, companyID).Scan(&registerID, &openingBalance, &cashIn, &cashOut)
	if err == sql.ErrNoRows {
		return fmt.Errorf("no open cash register")
	}
	if err != nil {
		return fmt.Errorf("failed to get open register: %w", err)
	}

	expected := openingBalance + cashIn - cashOut
	closing := expected
	if req.ClosingBalance != nil {
		closing = *req.ClosingBalance
	}
	variance := closing - expected

	now := time.Now()
	closedSessionID := uuidOrNil(sessionID)
	if _, err := tx.Exec(`
        UPDATE cash_register
        SET closing_balance = $1,
            expected_balance = $2,
            variance = $3,
            closed_by = $4,
            status = 'CLOSED',
            closed_at = $5,
            closed_session_id = $6,
            closed_request_id = $7,
            forced_closed = TRUE,
            forced_close_reason = $8,
            updated_at = $5
        WHERE register_id = $9
    `, closing, expected, variance, userID, now, closedSessionID, nullIfEmptyString(requestID), req.Reason, registerID); err != nil {
		return fmt.Errorf("failed to force close cash register: %w", err)
	}

	notes := req.Reason
	_, err = s.insertCashRegisterEvent(
		tx,
		registerID,
		locationID,
		&models.CashRegisterMovementRequest{
			Direction:  "OUT",
			Amount:     0,
			ReasonCode: "FORCE_CLOSE",
			Notes:      &notes,
		},
		userID,
		sessionID,
		requestID,
		"FORCE_CLOSE",
		req.Denominations,
	)
	if err != nil {
		return err
	}

	fieldChanges := models.JSONB{
		"event_type":       "FORCE_CLOSE",
		"register_id":      registerID,
		"location_id":      locationID,
		"reason":           req.Reason,
		"closing_balance":  closing,
		"expected_balance": expected,
		"variance":         variance,
		"request_id":       requestID,
		"session_id":       sessionID,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, "FORCE_CLOSE", "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return fmt.Errorf("failed to log audit: %w", err)
	}

	return tx.Commit()
}

func (s *CashRegisterService) RecordTally(
	companyID, locationID, userID int,
	count float64,
	notes *string,
	denominations *models.JSONB,
	sessionID, requestID string,
	ip, ua *string,
) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var registerID int
	err = tx.QueryRow(`
        SELECT cr.register_id
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
    `, locationID, companyID).Scan(&registerID)
	if err == sql.ErrNoRows {
		return fmt.Errorf("no open cash register")
	}
	if err != nil {
		return fmt.Errorf("failed to get open register: %w", err)
	}

	if _, err := tx.Exec(`INSERT INTO cash_register_tally (location_id, count, notes, recorded_by) VALUES ($1,$2,$3,$4)`, locationID, count, notes, userID); err != nil {
		return fmt.Errorf("failed to record tally: %w", err)
	}

	notesVal := notes
	if notesVal == nil {
		n := ""
		notesVal = &n
	}
	_, err = s.insertCashRegisterEvent(
		tx,
		registerID,
		locationID,
		&models.CashRegisterMovementRequest{
			Direction:  "IN",
			Amount:     0,
			ReasonCode: "TALLY",
			Notes:      notesVal,
		},
		userID,
		sessionID,
		requestID,
		"TALLY",
		denominations,
	)
	if err != nil {
		return err
	}

	fieldChanges := models.JSONB{
		"event_type":  "TALLY",
		"register_id": registerID,
		"location_id": locationID,
		"count":       count,
		"request_id":  requestID,
		"session_id":  sessionID,
	}
	rec := registerID
	actor := userID
	if err := LogAudit(tx, "TALLY", "cash_register", &rec, &actor, nil, nil, &fieldChanges, ip, ua); err != nil {
		return fmt.Errorf("failed to log audit: %w", err)
	}

	return tx.Commit()
}

func (s *CashRegisterService) GetEvents(companyID, locationID int, registerID *int, limit int) ([]models.CashRegisterEvent, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	query := `
        SELECT e.event_id, e.register_id, e.location_id, e.event_type, e.direction, e.amount,
               e.reason_code, e.notes, e.denominations, e.created_by, e.session_id, e.request_id, e.created_at
        FROM cash_register_events e
        JOIN cash_register cr ON e.register_id = cr.register_id
        JOIN locations l ON cr.location_id = l.location_id
        WHERE l.company_id = $1 AND e.location_id = $2
    `
	args := []interface{}{companyID, locationID}
	argCount := 2
	if registerID != nil && *registerID > 0 {
		argCount++
		query += fmt.Sprintf(" AND e.register_id = $%d", argCount)
		args = append(args, *registerID)
	}
	query += " ORDER BY e.created_at DESC, e.event_id DESC"
	argCount++
	query += fmt.Sprintf(" LIMIT $%d", argCount)
	args = append(args, limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query events: %w", err)
	}
	defer rows.Close()

	var events []models.CashRegisterEvent
	for rows.Next() {
		var e models.CashRegisterEvent
		var direction, reason, notes, sessionID, requestID sql.NullString
		var amount sql.NullFloat64
		var denom models.JSONB
		if err := rows.Scan(
			&e.EventID,
			&e.RegisterID,
			&e.LocationID,
			&e.EventType,
			&direction,
			&amount,
			&reason,
			&notes,
			&denom,
			&e.CreatedBy,
			&sessionID,
			&requestID,
			&e.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan event: %w", err)
		}
		if direction.Valid {
			v := direction.String
			e.Direction = &v
		}
		if amount.Valid {
			v := amount.Float64
			e.Amount = &v
		}
		if reason.Valid {
			v := reason.String
			e.ReasonCode = &v
		}
		if notes.Valid {
			v := notes.String
			e.Notes = &v
		}
		if sessionID.Valid {
			v := sessionID.String
			e.SessionID = &v
		}
		if requestID.Valid {
			v := requestID.String
			e.RequestID = &v
		}
		if len(denom) > 0 {
			e.Denominations = &denom
		}
		events = append(events, e)
	}
	return events, nil
}

func (s *CashRegisterService) insertCashRegisterEvent(
	tx *sql.Tx,
	registerID, locationID int,
	movement *models.CashRegisterMovementRequest,
	userID int,
	sessionID, requestID, eventType string,
	denominations *models.JSONB,
) (int, error) {
	if tx == nil {
		return 0, fmt.Errorf("transaction is nil")
	}

	var direction, reason, notes interface{}
	var amount interface{}
	if movement != nil {
		if movement.Direction != "" {
			direction = movement.Direction
		}
		if movement.ReasonCode != "" {
			reason = movement.ReasonCode
		}
		if movement.Notes != nil && *movement.Notes != "" {
			notes = *movement.Notes
		}
		if movement.Amount != 0 {
			amount = movement.Amount
		}
	}

	var denomVal interface{}
	if denominations != nil {
		denomVal = *denominations
	}

	var reqVal interface{}
	if requestID != "" {
		reqVal = requestID
	}

	var eventID int
	err := tx.QueryRow(`
        INSERT INTO cash_register_events (register_id, location_id, event_type, direction, amount, reason_code, notes, denominations, created_by, session_id, request_id)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
        RETURNING event_id
    `,
		registerID,
		locationID,
		eventType,
		direction,
		amount,
		reason,
		notes,
		denomVal,
		userID,
		uuidOrNil(sessionID),
		reqVal,
	).Scan(&eventID)
	if err != nil {
		return 0, fmt.Errorf("failed to insert cash register event: %w", err)
	}
	return eventID, nil
}

// RecordCashTransactionTx records a cash-impacting transaction (sale/collection/expense/etc)
// against the currently OPEN cash register for the location.
//
// This is best-effort:
// - If there is no open cash register, it returns nil (doesn't block operations).
// - If requestID+reasonCode was already recorded, it is idempotent.
func (s *CashRegisterService) RecordCashTransactionTx(
	tx *sql.Tx,
	companyID, locationID, userID int,
	direction string,
	amount float64,
	eventType string,
	reasonCode string,
	notes *string,
	sessionID string,
	requestID string,
) error {
	if amount <= 0 {
		return nil
	}

	ownTx := false
	if tx == nil {
		var err error
		tx, err = s.db.Begin()
		if err != nil {
			return fmt.Errorf("failed to begin transaction: %w", err)
		}
		ownTx = true
		defer tx.Rollback()
	}

	var registerID int
	err := tx.QueryRow(`
        SELECT cr.register_id
        FROM cash_register cr
        JOIN locations l ON cr.location_id = l.location_id
        WHERE cr.location_id = $1 AND l.company_id = $2 AND cr.status = 'OPEN'
        LIMIT 1
        FOR UPDATE
    `, locationID, companyID).Scan(&registerID)
	if err == sql.ErrNoRows {
		if ownTx {
			return tx.Commit()
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to get open cash register: %w", err)
	}

	if strings.TrimSpace(requestID) != "" && strings.TrimSpace(reasonCode) != "" {
		var exists bool
		if err := tx.QueryRow(`
            SELECT EXISTS(
                SELECT 1 FROM cash_register_events
                WHERE register_id = $1 AND request_id = $2 AND reason_code = $3
            )
        `, registerID, requestID, reasonCode).Scan(&exists); err == nil && exists {
			if ownTx {
				return tx.Commit()
			}
			return nil
		}
	}

	switch strings.ToUpper(strings.TrimSpace(direction)) {
	case "IN":
		if _, err := tx.Exec(`
            UPDATE cash_register
            SET cash_in = cash_in + $1,
                expected_balance = expected_balance + $1,
                updated_at = CURRENT_TIMESTAMP
            WHERE register_id = $2
        `, amount, registerID); err != nil {
			return fmt.Errorf("failed to update cash register cash_in: %w", err)
		}
		direction = "IN"
	case "OUT":
		if _, err := tx.Exec(`
            UPDATE cash_register
            SET cash_out = cash_out + $1,
                expected_balance = expected_balance - $1,
                updated_at = CURRENT_TIMESTAMP
            WHERE register_id = $2
        `, amount, registerID); err != nil {
			return fmt.Errorf("failed to update cash register cash_out: %w", err)
		}
		direction = "OUT"
	default:
		return fmt.Errorf("invalid cash register direction")
	}

	_, err = s.insertCashRegisterEvent(
		tx,
		registerID,
		locationID,
		&models.CashRegisterMovementRequest{
			Direction:  direction,
			Amount:     amount,
			ReasonCode: reasonCode,
			Notes:      notes,
		},
		userID,
		sessionID,
		requestID,
		eventType,
		nil,
	)
	if err != nil {
		return err
	}

	if ownTx {
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("failed to commit cash register transaction: %w", err)
		}
	}
	return nil
}

func uuidOrNil(raw string) interface{} {
	if raw == "" {
		return nil
	}
	parsed, err := uuid.Parse(raw)
	if err != nil {
		return nil
	}
	return parsed
}

func nullIfEmptyString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
