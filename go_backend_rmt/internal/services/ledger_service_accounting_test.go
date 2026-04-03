package services

import (
	"regexp"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func expectAccountLookup(mock sqlmock.Sqlmock, companyID int, code string, accountID int) {
	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`)).
		WithArgs(companyID, code).
		WillReturnRows(sqlmock.NewRows([]string{"account_id"}).AddRow(accountID))
}

func expectLedgerInsert(
	mock sqlmock.Sqlmock,
	companyID int,
	accountID int,
	entryDate time.Time,
	debit float64,
	credit float64,
	transactionType string,
	transactionID int,
	reference string,
	userID int,
) {
	mock.ExpectExec(regexp.QuoteMeta(`
		INSERT INTO ledger_entries (
			company_id, account_id, voucher_id, date, debit, credit, balance,
			transaction_type, transaction_id, description, reference,
			created_by, updated_by
		)
		SELECT
			$1::int,
			$2::int,
			$3::int,
			$4::date,
			$5::numeric,
			$6::numeric,
			0::numeric,
			$7::varchar,
			$8::int,
			$9::text,
			$10::varchar,
			$11::int,
			$11::int
		WHERE NOT EXISTS (
			SELECT 1 FROM ledger_entries
			WHERE company_id = $1::int AND reference = $10::varchar
		)
	`)).
		WithArgs(companyID, accountID, nil, entryDate, debit, credit, transactionType, transactionID, nil, reference, userID).
		WillReturnResult(sqlmock.NewResult(0, 1))
}

func TestLedgerServiceRecordSalePostsCOGS(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &LedgerService{db: db}
	companyID := 1
	saleID := 55
	userID := 7
	saleDate := time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT s.total_amount, s.tax_amount, s.paid_amount, s.sale_date
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`)).
		WithArgs(saleID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"total_amount", "tax_amount", "paid_amount", "sale_date"}).
			AddRow(100.0, 10.0, 40.0, saleDate))

	expectAccountLookup(mock, companyID, accountCodeCash, 100)
	expectAccountLookup(mock, companyID, accountCodeAR, 110)
	expectAccountLookup(mock, companyID, accountCodeSalesRevenue, 400)
	expectAccountLookup(mock, companyID, accountCodeTaxPayable, 210)
	expectAccountLookup(mock, companyID, accountCodeCOGS, 500)
	expectAccountLookup(mock, companyID, accountCodeInventory, 120)

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT COALESCE(SUM(sd.quantity * COALESCE(sd.cost_price, 0)), 0)::float8
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE sd.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`)).
		WithArgs(saleID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"amount"}).AddRow(25.0))

	expectLedgerInsert(mock, companyID, 100, saleDate, 40.0, 0.0, "sale", saleID, "sale:55:1000", userID)
	expectLedgerInsert(mock, companyID, 110, saleDate, 60.0, 0.0, "sale", saleID, "sale:55:1100", userID)
	expectLedgerInsert(mock, companyID, 400, saleDate, 0.0, 90.0, "sale", saleID, "sale:55:4000", userID)
	expectLedgerInsert(mock, companyID, 210, saleDate, 0.0, 10.0, "sale", saleID, "sale:55:2100", userID)
	expectLedgerInsert(mock, companyID, 500, saleDate, 25.0, 0.0, "sale", saleID, "sale:55:5000", userID)
	expectLedgerInsert(mock, companyID, 120, saleDate, 0.0, 25.0, "sale", saleID, "sale:55:1200", userID)

	if err := service.RecordSale(companyID, saleID, userID); err != nil {
		t.Fatalf("RecordSale returned error: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestLedgerServiceRecordSaleReturnPostsCreditNoteAndCOGSReversal(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &LedgerService{db: db}
	companyID := 1
	returnID := 77
	userID := 9
	returnDate := time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT
			sr.total_amount,
			sr.return_date,
			COALESCE(SUM(COALESCE(srd.tax_amount, 0)), 0)::float8 AS tax_amount,
			COALESCE(SUM(srd.quantity * COALESCE(srd.cost_price, 0)), 0)::float8 AS cogs_reversal
		FROM sale_returns sr
		JOIN locations l ON l.location_id = sr.location_id
		LEFT JOIN sale_return_details srd ON srd.return_id = sr.return_id
		WHERE sr.return_id = $1 AND l.company_id = $2 AND sr.is_deleted = FALSE
		GROUP BY sr.return_id, sr.total_amount, sr.return_date
	`)).
		WithArgs(returnID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"total_amount", "return_date", "tax_amount", "cogs_reversal"}).
			AddRow(56.0, returnDate, 6.0, 15.0))

	expectAccountLookup(mock, companyID, accountCodeAR, 110)
	expectAccountLookup(mock, companyID, accountCodeSalesRevenue, 400)
	expectAccountLookup(mock, companyID, accountCodeTaxPayable, 210)
	expectAccountLookup(mock, companyID, accountCodeInventory, 120)
	expectAccountLookup(mock, companyID, accountCodeCOGS, 500)

	expectLedgerInsert(mock, companyID, 400, returnDate, 50.0, 0.0, "sale_return", returnID, "sale_return:77:4000", userID)
	expectLedgerInsert(mock, companyID, 210, returnDate, 6.0, 0.0, "sale_return", returnID, "sale_return:77:2100", userID)
	expectLedgerInsert(mock, companyID, 110, returnDate, 0.0, 56.0, "sale_return", returnID, "sale_return:77:1100", userID)
	expectLedgerInsert(mock, companyID, 120, returnDate, 15.0, 0.0, "sale_return", returnID, "sale_return:77:1200", userID)
	expectLedgerInsert(mock, companyID, 500, returnDate, 0.0, 15.0, "sale_return", returnID, "sale_return:77:5000", userID)

	if err := service.RecordSaleReturn(companyID, returnID, userID); err != nil {
		t.Fatalf("RecordSaleReturn returned error: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestLedgerServiceRecordPurchaseReturnSplitsInventoryAndTax(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &LedgerService{db: db}
	companyID := 3
	returnID := 88
	userID := 5
	returnDate := time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT
			pr.total_amount,
			pr.return_date,
			COALESCE(SUM(
				CASE
					WHEN prd.purchase_detail_id IS NOT NULL AND COALESCE(pd.quantity, 0) <> 0
						THEN (COALESCE(pd.tax_amount, 0) / pd.quantity) * prd.quantity
					ELSE 0
				END
			), 0)::float8 AS tax_amount
		FROM purchase_returns pr
		JOIN locations l ON l.location_id = pr.location_id
		LEFT JOIN purchase_return_details prd ON prd.return_id = pr.return_id
		LEFT JOIN purchase_details pd ON pd.purchase_detail_id = prd.purchase_detail_id
		WHERE pr.return_id = $1 AND l.company_id = $2 AND pr.is_deleted = FALSE
		GROUP BY pr.return_id, pr.total_amount, pr.return_date
	`)).
		WithArgs(returnID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"total_amount", "return_date", "tax_amount"}).
			AddRow(112.0, returnDate, 12.0))

	expectAccountLookup(mock, companyID, accountCodeAP, 200)
	expectAccountLookup(mock, companyID, accountCodeInventory, 120)
	expectAccountLookup(mock, companyID, accountCodeTaxReceivable, 220)

	expectLedgerInsert(mock, companyID, 200, returnDate, 112.0, 0.0, "purchase_return", returnID, "purchase_return:88:2000", userID)
	expectLedgerInsert(mock, companyID, 120, returnDate, 0.0, 100.0, "purchase_return", returnID, "purchase_return:88:1200", userID)
	expectLedgerInsert(mock, companyID, 220, returnDate, 0.0, 12.0, "purchase_return", returnID, "purchase_return:88:2200", userID)

	if err := service.RecordPurchaseReturn(companyID, returnID, userID); err != nil {
		t.Fatalf("RecordPurchaseReturn returned error: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
