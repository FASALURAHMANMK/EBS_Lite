package services

import (
	"database/sql"
	"regexp"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
	"github.com/lib/pq"

	"erp-backend/internal/models"
)

func TestExpenseService_CreateExpense_IdempotencyExistingReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &ExpenseService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		idemKey    = "idem-exp-1"
	)

	req := &models.CreateExpenseRequest{
		CategoryID:  7,
		Amount:      12.5,
		ExpenseDate: time.Date(2026, 3, 3, 0, 0, 0, 0, time.UTC),
		Notes: func() *string {
			v := "test"
			return &v
		}(),
	}

	mock.ExpectQuery("(?s)SELECT e\\.expense_id.*FROM expenses e.*WHERE e\\.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"expense_id"}).AddRow(99))

	id, err := svc.CreateExpense(companyID, locationID, userID, req, idemKey)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if id != 99 {
		t.Fatalf("expected existing expense_id=99, got %d", id)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestExpenseService_CreateExpense_IdempotencyUniqueViolationReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &ExpenseService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		idemKey    = "idem-exp-2"
	)

	req := &models.CreateExpenseRequest{
		CategoryID:  7,
		Amount:      12.5,
		ExpenseDate: time.Date(2026, 3, 3, 0, 0, 0, 0, time.UTC),
		Notes: func() *string {
			v := "test"
			return &v
		}(),
	}

	mock.ExpectQuery("(?s)SELECT e\\.expense_id.*FROM expenses e.*WHERE e\\.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectBegin()

	mock.ExpectExec(regexp.QuoteMeta("SELECT pg_advisory_xact_lock($1)")).
		WithArgs(sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)SELECT sequence_id, prefix, sequence_length, current_number.*FROM numbering_sequences.*location_id = \\$3.*FOR UPDATE").
		WithArgs("expense", companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{"sequence_id", "prefix", "sequence_length", "current_number"}).
			AddRow(1, "EXP-", 6, 41))

	mock.ExpectExec(regexp.QuoteMeta("UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2")).
		WithArgs(42, 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)INSERT INTO expenses .*RETURNING expense_id").
		WithArgs("EXP-000042", req.CategoryID, locationID, req.Amount, req.Notes, req.ExpenseDate, userID, userID, idemKey).
		WillReturnError(&pq.Error{Code: "23505"})

	mock.ExpectRollback()

	mock.ExpectQuery("(?s)SELECT e\\.expense_id.*FROM expenses e.*WHERE e\\.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"expense_id"}).AddRow(123))

	id, err := svc.CreateExpense(companyID, locationID, userID, req, idemKey)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if id != 123 {
		t.Fatalf("expected existing expense_id=123, got %d", id)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
