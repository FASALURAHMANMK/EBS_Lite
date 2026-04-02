package services

import (
	"database/sql"
	"regexp"
	"testing"

	"erp-backend/internal/models"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func TestSalesService_CalculateTotals_BatchedQueries(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &SalesService{db: db}

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT value
		FROM settings
		WHERE company_id = $1 AND key = 'tax'
	`)).
		WithArgs(1).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT product_id, unit_id, purchase_unit_id, selling_unit_id, tax_id, CASE WHEN COALESCE(is_serialized, FALSE) OR COALESCE(tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized, COALESCE(cost_price, 0)::float8,")).
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"product_id", "unit_id", "purchase_unit_id", "selling_unit_id", "tax_id", "is_serialized", "cost_price", "purchase_to_stock_factor", "selling_to_stock_factor", "is_weighable", "purchase_uom_mode", "selling_uom_mode"}).
			AddRow(1, 1, 1, 1, 10, false, 25.0, 1.0, 1.0, false, "LOOSE", "LOOSE").
			AddRow(2, 2, 2, 2, nil, false, 15.0, 1.0, 1.0, false, "LOOSE", "LOOSE"))

	mock.ExpectQuery(regexp.QuoteMeta("SELECT tax_id, percentage")).
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"tax_id", "percentage"}).
			AddRow(10, 5.0).
			AddRow(20, 10.0))

	req := &models.CreateSaleRequest{
		Items: []models.CreateSaleDetailRequest{
			{ProductID: ptrInt(1), Quantity: 2, UnitPrice: 100},
			{ProductID: ptrInt(2), TaxID: ptrInt(20), Quantity: 1, UnitPrice: 50, DiscountPercent: 10},
		},
		DiscountAmount: 0,
	}

	subtotal, tax, total, err := svc.CalculateTotals(1, req)
	if err != nil {
		t.Fatalf("CalculateTotals returned error: %v", err)
	}
	if subtotal != 245 {
		t.Fatalf("unexpected subtotal: %v", subtotal)
	}
	if tax != 14.5 {
		t.Fatalf("unexpected tax: %v", tax)
	}
	if total != 259.5 {
		t.Fatalf("unexpected total: %v", total)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("there were unfulfilled expectations: %v", err)
	}
}

func TestSalesService_CalculateTotals_MissingTaxUsesStableError(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &SalesService{db: db}

	mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT value
		FROM settings
		WHERE company_id = $1 AND key = 'tax'
	`)).
		WithArgs(1).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT product_id, unit_id, purchase_unit_id, selling_unit_id, tax_id, CASE WHEN COALESCE(is_serialized, FALSE) OR COALESCE(tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized, COALESCE(cost_price, 0)::float8,")).
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"product_id", "unit_id", "purchase_unit_id", "selling_unit_id", "tax_id", "is_serialized", "cost_price", "purchase_to_stock_factor", "selling_to_stock_factor", "is_weighable", "purchase_uom_mode", "selling_uom_mode"}).
			AddRow(1, 1, 1, 1, 10, false, 25.0, 1.0, 1.0, false, "LOOSE", "LOOSE"))

	mock.ExpectQuery(regexp.QuoteMeta("SELECT tax_id, percentage")).
		WithArgs(1, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"tax_id", "percentage"}))

	req := &models.CreateSaleRequest{
		Items: []models.CreateSaleDetailRequest{
			{ProductID: ptrInt(1), Quantity: 1, UnitPrice: 100},
		},
	}

	_, _, _, err = svc.CalculateTotals(1, req)
	if err == nil {
		t.Fatalf("expected error but got nil")
	}
	if err.Error() != "failed to calculate tax: failed to get tax percentage: sql: no rows in result set" {
		t.Fatalf("unexpected error: %v", err)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("there were unfulfilled expectations: %v", err)
	}
}

func ptrInt(v int) *int {
	return &v
}
