package services

import (
	"regexp"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"

	"erp-backend/internal/models"
)

func TestBankingServiceMatchStatementCreatesMatchAndMarksMatched(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &BankingService{db: db, voucherService: &VoucherService{db: db}}
	now := time.Date(2026, 3, 30, 0, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT ledger_account_id").
		WithArgs(1, 2).
		WillReturnRows(sqlmock.NewRows([]string{"ledger_account_id"}).AddRow(101))
	mock.ExpectQuery("SELECT\\s+bse.statement_entry_id").
		WithArgs(1, 2, 500).
		WillReturnRows(sqlmock.NewRows([]string{
			"statement_entry_id", "company_id", "bank_account_id", "entry_date", "value_date", "description", "reference", "external_ref", "source_type",
			"deposit_amount", "withdrawal_amount", "running_balance", "status", "review_reason", "matched_amount", "created_at",
		}).AddRow(10, 1, 2, now, nil, "Deposit", "BNK-1", nil, "MANUAL", 100.0, 0.0, 500.0, "UNMATCHED", nil, 0.0, now))
	mock.ExpectQuery("SELECT\\s+brm.match_id").
		WithArgs(1, 2, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"match_id", "company_id", "bank_account_id", "statement_entry_id", "ledger_entry_id", "matched_amount", "match_kind", "notes", "created_by", "created_at", "date", "reference", "description",
		}))
	mock.ExpectQuery("SELECT debit::float8, credit::float8").
		WithArgs(1, 99, 101).
		WillReturnRows(sqlmock.NewRows([]string{"debit", "credit"}).AddRow(100.0, 0.0))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(matched_amount\\), 0\\)::float8").
		WithArgs(1, 99).
		WillReturnRows(sqlmock.NewRows([]string{"matched"}).AddRow(0.0))
	mock.ExpectExec(regexp.QuoteMeta(`
		INSERT INTO bank_reconciliation_matches (
			company_id, bank_account_id, statement_entry_id, ledger_entry_id, matched_amount, match_kind, notes, created_by
		)
		VALUES ($1,$2,$3,$4,$5,'MANUAL',$6,$7)
	`)).
		WithArgs(1, 2, 10, 99, 100.0, nil, 7).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectQuery("SELECT deposit_amount::float8, withdrawal_amount::float8, review_reason").
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{"deposit_amount", "withdrawal_amount", "review_reason"}).AddRow(100.0, 0.0, nil))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(matched_amount\\), 0\\)::float8").
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{"matched"}).AddRow(100.0))
	mock.ExpectExec("UPDATE bank_statement_entries").
		WithArgs("MATCHED", 1, 10).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	mock.ExpectQuery("SELECT\\s+bse.statement_entry_id").
		WithArgs(1, 2, 500).
		WillReturnRows(sqlmock.NewRows([]string{
			"statement_entry_id", "company_id", "bank_account_id", "entry_date", "value_date", "description", "reference", "external_ref", "source_type",
			"deposit_amount", "withdrawal_amount", "running_balance", "status", "review_reason", "matched_amount", "created_at",
		}).AddRow(10, 1, 2, now, nil, "Deposit", "BNK-1", nil, "MANUAL", 100.0, 0.0, 500.0, "MATCHED", nil, 100.0, now))
	mock.ExpectQuery("SELECT\\s+brm.match_id").
		WithArgs(1, 2, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"match_id", "company_id", "bank_account_id", "statement_entry_id", "ledger_entry_id", "matched_amount", "match_kind", "notes", "created_by", "created_at", "date", "reference", "description",
		}).AddRow(501, 1, 2, 10, 99, 100.0, "MANUAL", nil, 7, now, now, "voucher:1:line:1", "Matched line"))

	item, err := service.MatchStatement(1, 2, 7, &models.MatchBankStatementRequest{
		StatementEntryID: 10,
		LedgerEntryID:    99,
		MatchedAmount:    100,
	})
	if err != nil {
		t.Fatalf("MatchStatement returned error: %v", err)
	}
	if item.Status != "MATCHED" {
		t.Fatalf("expected MATCHED status, got %s", item.Status)
	}
	if len(item.Matches) != 1 {
		t.Fatalf("expected 1 match, got %d", len(item.Matches))
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestBankingServiceUnmatchStatementRestoresUnmatchedStatus(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &BankingService{db: db, voucherService: &VoucherService{db: db}}
	now := time.Date(2026, 3, 30, 0, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE bank_reconciliation_matches").
		WithArgs(1, 2, 10, 501).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectQuery("SELECT deposit_amount::float8, withdrawal_amount::float8, review_reason").
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{"deposit_amount", "withdrawal_amount", "review_reason"}).AddRow(100.0, 0.0, nil))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(matched_amount\\), 0\\)::float8").
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{"matched"}).AddRow(0.0))
	mock.ExpectExec("UPDATE bank_statement_entries").
		WithArgs("UNMATCHED", 1, 10).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	mock.ExpectQuery("SELECT\\s+bse.statement_entry_id").
		WithArgs(1, 2, 500).
		WillReturnRows(sqlmock.NewRows([]string{
			"statement_entry_id", "company_id", "bank_account_id", "entry_date", "value_date", "description", "reference", "external_ref", "source_type",
			"deposit_amount", "withdrawal_amount", "running_balance", "status", "review_reason", "matched_amount", "created_at",
		}).AddRow(10, 1, 2, now, nil, "Deposit", "BNK-1", nil, "MANUAL", 100.0, 0.0, 500.0, "UNMATCHED", nil, 0.0, now))
	mock.ExpectQuery("SELECT\\s+brm.match_id").
		WithArgs(1, 2, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"match_id", "company_id", "bank_account_id", "statement_entry_id", "ledger_entry_id", "matched_amount", "match_kind", "notes", "created_by", "created_at", "date", "reference", "description",
		}))

	item, err := service.UnmatchStatement(1, 2, &models.UnmatchBankStatementRequest{
		StatementEntryID: 10,
		MatchID:          501,
	})
	if err != nil {
		t.Fatalf("UnmatchStatement returned error: %v", err)
	}
	if item.Status != "UNMATCHED" {
		t.Fatalf("expected UNMATCHED status, got %s", item.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
