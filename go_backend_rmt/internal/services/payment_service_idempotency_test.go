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

func TestPaymentService_CreatePayment_IdempotencyUniqueViolationReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &PaymentService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		supplierID = 10
		idemKey    = "idem-pay-1"
	)

	req := &models.CreatePaymentRequest{
		SupplierID: func() *int {
			v := supplierID
			return &v
		}(),
		Amount: 50,
		IdempotencyKey: func() *string {
			v := idemKey
			return &v
		}(),
	}

	mock.ExpectBegin()

	mock.ExpectQuery("(?s)SELECT pay.payment_id, pay.payment_number.*FROM payments pay.*WHERE pay.location_id = \\$1.*pay.idempotency_key = \\$2.*").
		WithArgs(locationID, idemKey, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT 1 FROM suppliers WHERE supplier_id = $1 AND company_id = $2 AND is_active = TRUE")).
		WithArgs(supplierID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(1))

	mock.ExpectExec(regexp.QuoteMeta("SELECT pg_advisory_xact_lock($1)")).
		WithArgs(sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)SELECT sequence_id, prefix, sequence_length, current_number.*FROM numbering_sequences.*FOR UPDATE").
		WithArgs("payment", companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{"sequence_id", "prefix", "sequence_length", "current_number"}).
			AddRow(1, "PAY-", 6, 9))

	mock.ExpectExec(regexp.QuoteMeta("UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2")).
		WithArgs(10, 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)INSERT INTO payments .*RETURNING payment_id, payment_number, payment_date, created_at, updated_at").
		WillReturnError(&pq.Error{Code: "23505"})

	now := time.Now()
	mock.ExpectQuery("(?s)SELECT pay.payment_id, pay.payment_number.*FROM payments pay.*WHERE pay.location_id = \\$1.*pay.idempotency_key = \\$2.*").
		WithArgs(locationID, idemKey, companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"payment_id", "payment_number", "supplier_id", "purchase_id", "location_id",
			"amount", "payment_method_id", "reference_number", "notes", "idempotency_key",
			"payment_date", "created_by", "updated_by", "created_at", "updated_at",
		}).AddRow(
			42, "PAY-000010", supplierID, nil, locationID,
			50.0, nil, nil, nil, idemKey,
			now, userID, nil, now, now,
		))

	mock.ExpectRollback()

	payment, err := svc.CreatePayment(companyID, locationID, userID, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if payment == nil || payment.PaymentID != 42 {
		t.Fatalf("expected existing payment_id=42, got %#v", payment)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
