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

func TestSalesService_CreateSale_IdempotencyUniqueViolationReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &SalesService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		idemKey    = "idem-sale"
	)

	productName := "Custom item"
	req := &models.CreateSaleRequest{
		Items: []models.CreateSaleDetailRequest{
			{
				ProductName: &productName,
				Quantity:    1,
				UnitPrice:   10,
			},
		},
		PaidAmount: 10,
	}

	mock.ExpectQuery("(?s)SELECT COUNT\\(\\*\\) FROM locations.*WHERE location_id = \\$1 AND company_id = \\$2 AND is_active = TRUE").
		WithArgs(locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(1))

	mock.ExpectQuery("(?s)SELECT s\\.sale_id FROM sales s.*WHERE s\\.idempotency_key = \\$1 AND s\\.location_id = \\$2 AND l\\.company_id = \\$3 AND s\\.is_deleted = FALSE").
		WithArgs(idemKey, locationID, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectBegin()

	mock.ExpectExec(regexp.QuoteMeta("SELECT pg_advisory_xact_lock($1)")).
		WithArgs(sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)SELECT sequence_id, prefix, sequence_length, current_number.*FROM numbering_sequences.*FOR UPDATE").
		WithArgs("sale", companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{"sequence_id", "prefix", "sequence_length", "current_number"}).
			AddRow(1, "INV-", 6, 12))

	mock.ExpectExec(regexp.QuoteMeta("UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2")).
		WithArgs(13, 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)INSERT INTO sales \\(sale_number, location_id, customer_id, sale_date, sale_time,.*RETURNING sale_id").
		WillReturnError(&pq.Error{Code: "23505"})

	mock.ExpectQuery("(?s)SELECT s\\.sale_id FROM sales s.*WHERE s\\.idempotency_key = \\$1 AND s\\.location_id = \\$2 AND l\\.company_id = \\$3 AND s\\.is_deleted = FALSE").
		WithArgs(idemKey, locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"sale_id"}).AddRow(99))

	now := time.Now()
	mock.ExpectQuery("(?s)SELECT s.sale_id, s.sale_number, s.location_id, s.customer_id, s.sale_date, s.sale_time.*COALESCE\\(s\\.is_training, FALSE\\) AS is_training.*FROM sales s.*WHERE s.sale_id = \\$1 AND l.company_id = \\$2 AND s.is_deleted = FALSE").
		WithArgs(99, companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"sale_id", "sale_number", "location_id", "customer_id", "sale_date", "sale_time",
			"subtotal", "tax_amount", "discount_amount", "total_amount", "paid_amount",
			"payment_method_id", "status", "pos_status", "is_quick_sale", "is_training", "notes",
			"created_by", "updated_by", "sync_status", "created_at", "updated_at",
			"customer_name", "payment_method_name",
		}).AddRow(
			99, "INV-000013", locationID, nil, now, now,
			10.0, 0.0, 0.0, 10.0, 10.0,
			nil, "COMPLETED", "COMPLETED", false, false, nil,
			userID, nil, "synced", now, now,
			nil, nil,
		))

	mock.ExpectQuery("(?s)SELECT sd.sale_detail_id, sd.sale_id, sd.product_id, sd.barcode_id, sd.product_name,.*FROM sale_details sd.*WHERE sd.sale_id = \\$1 AND l.company_id = \\$2.*ORDER BY sd.sale_detail_id").
		WithArgs(99, companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"sale_detail_id", "sale_id", "product_id", "barcode_id", "product_name", "barcode", "variant_name", "tracking_type", "is_serialized", "quantity",
			"unit_price", "discount_percentage", "discount_amount", "tax_id",
			"tax_amount", "line_total", "serial_numbers", "notes",
			"product_name_from_table",
		}).AddRow(
			1, 99, nil, nil, productName, nil, nil, "VARIANT", false, 1.0,
			10.0, 0.0, 0.0, nil,
			0.0, 10.0, "{}", nil,
			nil,
		))

	mock.ExpectRollback()

	sale, err := svc.CreateSale(companyID, locationID, userID, req, func() *string {
		v := idemKey
		return &v
	}())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if sale == nil || sale.SaleID != 99 {
		t.Fatalf("expected existing sale_id=99, got %#v", sale)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
