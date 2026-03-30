package services

import (
	"testing"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func TestReportsServiceGetTaxReviewReportReturnsOutputInputAndNet(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &ReportsService{db: db}

	mock.ExpectQuery("WITH sales_tax AS").
		WithArgs(1, "2026-03-01", "2026-03-31").
		WillReturnRows(sqlmock.NewRows([]string{"tax_side", "tax_name", "tax_rate", "taxable_amount", "tax_amount"}).
			AddRow("OUTPUT", "VAT 5%", 5.0, 1000.0, 50.0).
			AddRow("INPUT", "VAT 5%", 5.0, 400.0, 20.0).
			AddRow("NET", nil, nil, nil, 30.0))

	rows, err := service.GetTaxReviewReport(1, "2026-03-01", "2026-03-31")
	if err != nil {
		t.Fatalf("GetTaxReviewReport returned error: %v", err)
	}
	if len(rows) != 3 {
		t.Fatalf("expected 3 rows, got %d", len(rows))
	}
	if rows[0]["tax_side"] != "OUTPUT" || rows[0]["tax_amount"] != 50.0 {
		t.Fatalf("unexpected output tax row: %#v", rows[0])
	}
	if rows[1]["tax_side"] != "INPUT" || rows[1]["tax_amount"] != 20.0 {
		t.Fatalf("unexpected input tax row: %#v", rows[1])
	}
	if rows[2]["tax_side"] != "NET" || rows[2]["tax_amount"] != 30.0 {
		t.Fatalf("unexpected net tax row: %#v", rows[2])
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
