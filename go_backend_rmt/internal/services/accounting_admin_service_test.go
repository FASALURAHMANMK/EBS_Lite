package services

import (
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"

	"erp-backend/internal/models"
)

func TestAccountingAdminServiceCloseAccountingPeriodBlockedByChecklist(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &AccountingAdminService{db: db}
	startDate := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery("SELECT period_id, company_id, period_name").
		WithArgs(1, 5).
		WillReturnRows(sqlmock.NewRows([]string{
			"period_id", "company_id", "period_name", "start_date", "end_date", "status", "checklist", "notes",
			"closed_at", "closed_by", "reopened_at", "reopened_by", "created_at",
		}).AddRow(5, 1, "2026-03", startDate, endDate, "OPEN", []byte(`{}`), nil, nil, nil, nil, nil, startDate))
	mock.ExpectQuery("SELECT COALESCE\\(ABS\\(SUM\\(debit\\) - SUM\\(credit\\)\\), 0\\)::float8").
		WithArgs(1, "2026-03-01", "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"difference"}).AddRow(0.0))
	mock.ExpectQuery("SELECT COUNT\\(\\*\\)\\s+FROM finance_integrity_outbox").
		WithArgs(1, "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(0))
	mock.ExpectQuery("SELECT COUNT\\(\\*\\)\\s+FROM bank_statement_entries").
		WithArgs(1, "2026-03-01", "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(2))

	_, err = service.CloseAccountingPeriod(1, 5, 7, &models.UpdateAccountingPeriodStatusRequest{})
	if err == nil {
		t.Fatalf("expected checklist failure")
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestAccountingAdminServiceCloseAccountingPeriodSucceedsWhenChecklistPasses(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &AccountingAdminService{db: db}
	startDate := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC)
	mock.ExpectQuery("SELECT period_id, company_id, period_name").
		WithArgs(1, 5).
		WillReturnRows(sqlmock.NewRows([]string{
			"period_id", "company_id", "period_name", "start_date", "end_date", "status", "checklist", "notes",
			"closed_at", "closed_by", "reopened_at", "reopened_by", "created_at",
		}).AddRow(5, 1, "2026-03", startDate, endDate, "OPEN", []byte(`{}`), nil, nil, nil, nil, nil, startDate))
	mock.ExpectQuery("SELECT COALESCE\\(ABS\\(SUM\\(debit\\) - SUM\\(credit\\)\\), 0\\)::float8").
		WithArgs(1, "2026-03-01", "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"difference"}).AddRow(0.0))
	mock.ExpectQuery("SELECT COUNT\\(\\*\\)\\s+FROM finance_integrity_outbox").
		WithArgs(1, "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(0))
	mock.ExpectQuery("SELECT COUNT\\(\\*\\)\\s+FROM bank_statement_entries").
		WithArgs(1, "2026-03-01", "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(0))
	mock.ExpectExec("UPDATE accounting_periods").
		WithArgs(sqlmock.AnyArg(), nil, 7, 1, 5).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectQuery("SELECT period_id, company_id, period_name").
		WithArgs(1, 5).
		WillReturnRows(sqlmock.NewRows([]string{
			"period_id", "company_id", "period_name", "start_date", "end_date", "status", "checklist", "notes",
			"closed_at", "closed_by", "reopened_at", "reopened_by", "created_at",
		}).AddRow(5, 1, "2026-03", startDate, endDate, "CLOSED", []byte(`{"trial_balance_balanced":{"passed":true,"difference":0},"finance_integrity_clear":{"passed":true,"count":0},"bank_reconciliation_complete":{"passed":true,"count":0}}`), nil, startDate, 7, nil, nil, startDate))

	item, err := service.CloseAccountingPeriod(1, 5, 7, &models.UpdateAccountingPeriodStatusRequest{})
	if err != nil {
		t.Fatalf("CloseAccountingPeriod returned error: %v", err)
	}
	if item.Status != "CLOSED" {
		t.Fatalf("expected CLOSED status, got %s", item.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
