package services

import (
	"regexp"
	"testing"

	sqlmock "github.com/DATA-DOG/go-sqlmock"

	"erp-backend/internal/models"
)

func TestVoucherServiceCreateVoucherRejectsImbalancedJournal(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &VoucherService{db: db}

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, 20).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectRollback()

	_, err = service.CreateVoucher(1, 2, "journal", &models.CreateVoucherRequest{
		Reference: "JV-1",
		Lines: []models.CreateVoucherLineRequest{
			{AccountID: 10, Debit: 50},
			{AccountID: 20, Credit: 40},
		},
	})
	if err == nil {
		t.Fatalf("expected error for imbalanced journal voucher")
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestVoucherServiceCreateVoucherCreatesBalancedJournalWithLedgerLines(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &VoucherService{db: db}

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, 100).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT EXISTS \\(").
		WithArgs(1, 200).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO vouchers (
			company_id, type, date, amount, account_id, settlement_account_id, bank_account_id,
			reference, description, created_by, updated_by, idempotency_key
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10,NULLIF($11,''))
		RETURNING voucher_id
	`)).
		WithArgs(1, "journal", sqlmock.AnyArg(), 100.0, 100, nil, nil, "JV-100", nil, 2, "").
		WillReturnRows(sqlmock.NewRows([]string{"voucher_id"}).AddRow(55))

	mock.ExpectExec(regexp.QuoteMeta(`
			INSERT INTO voucher_lines (
				voucher_id, company_id, account_id, line_no, debit, credit, description, created_by, updated_by
			)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
		`)).
		WithArgs(55, 1, 100, 1, 100.0, 0.0, nil, 2).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectExec(regexp.QuoteMeta(`
			INSERT INTO voucher_lines (
				voucher_id, company_id, account_id, line_no, debit, credit, description, created_by, updated_by
			)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
		`)).
		WithArgs(55, 1, 200, 2, 0.0, 100.0, nil, 2).
		WillReturnResult(sqlmock.NewResult(1, 1))

	mock.ExpectExec(regexp.QuoteMeta(`
			INSERT INTO ledger_entries (
				company_id, account_id, voucher_id, date, debit, credit, balance,
				transaction_type, transaction_id, description, reference,
				created_by, updated_by
			)
			SELECT $1,$2,$3,$4,$5,$6,0,'voucher',$3,$7,$8,$9,$9
			WHERE NOT EXISTS (
				SELECT 1 FROM ledger_entries WHERE company_id = $1 AND reference = $8
			)
		`)).
		WithArgs(1, 100, 55, sqlmock.AnyArg(), 100.0, 0.0, nil, "voucher:55:line:1", 2).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectExec(regexp.QuoteMeta(`
			INSERT INTO ledger_entries (
				company_id, account_id, voucher_id, date, debit, credit, balance,
				transaction_type, transaction_id, description, reference,
				created_by, updated_by
			)
			SELECT $1,$2,$3,$4,$5,$6,0,'voucher',$3,$7,$8,$9,$9
			WHERE NOT EXISTS (
				SELECT 1 FROM ledger_entries WHERE company_id = $1 AND reference = $8
			)
		`)).
		WithArgs(1, 200, 55, sqlmock.AnyArg(), 0.0, 100.0, nil, "voucher:55:line:2", 2).
		WillReturnResult(sqlmock.NewResult(1, 1))

	mock.ExpectCommit()

	id, err := service.CreateVoucher(1, 2, "journal", &models.CreateVoucherRequest{
		Reference: "JV-100",
		Lines: []models.CreateVoucherLineRequest{
			{AccountID: 100, Debit: 100},
			{AccountID: 200, Credit: 100},
		},
	})
	if err != nil {
		t.Fatalf("CreateVoucher returned error: %v", err)
	}
	if id != 55 {
		t.Fatalf("unexpected voucher id: %d", id)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
