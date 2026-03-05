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

func TestPurchaseService_CreatePurchase_IdempotencyUniqueViolationReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &PurchaseService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		supplierID = 10
		idemKey    = "idem-abc"
	)

	req := &models.CreatePurchaseRequest{
		SupplierID: supplierID,
		Items: []models.CreatePurchaseDetailRequest{
			{ProductID: 1, Quantity: 1, UnitPrice: 10},
		},
	}

	mock.ExpectBegin()

	mock.ExpectQuery(regexp.QuoteMeta("SELECT company_id FROM suppliers WHERE supplier_id = $1 AND is_active = TRUE")).
		WithArgs(supplierID).
		WillReturnRows(sqlmock.NewRows([]string{"company_id"}).AddRow(companyID))

	mock.ExpectQuery("(?s)SELECT p.purchase_id, p.purchase_number.*FROM purchases p.*WHERE p.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT COUNT(*) FROM locations WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE")).
		WithArgs(locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(1))

	mock.ExpectExec(regexp.QuoteMeta("SELECT pg_advisory_xact_lock($1)")).
		WithArgs(sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)SELECT sequence_id, prefix, sequence_length, current_number.*FROM numbering_sequences.*FOR UPDATE").
		WithArgs("purchase", companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{"sequence_id", "prefix", "sequence_length", "current_number"}).
			AddRow(1, "PO-", 6, 41))

	mock.ExpectExec(regexp.QuoteMeta("UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2")).
		WithArgs(42, 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)SELECT cr\\.date\\s+FROM cash_register cr.*WHERE cr\\.location_id = \\$1.*cr\\.status = 'OPEN'.*").
		WithArgs(locationID, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT company_id FROM products WHERE product_id = $1 AND is_deleted = FALSE")).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"company_id"}).AddRow(companyID))

	mock.ExpectQuery("(?s)INSERT INTO purchases \\(purchase_number, location_id, supplier_id, purchase_date,.*RETURNING purchase_id, created_at").
		WillReturnError(&pq.Error{Code: "23505"})

	now := time.Now()
	mock.ExpectQuery("(?s)SELECT p.purchase_id, p.purchase_number.*FROM purchases p.*WHERE p.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"purchase_id", "purchase_number", "location_id", "supplier_id",
			"purchase_date", "subtotal", "tax_amount", "discount_amount",
			"total_amount", "paid_amount", "payment_terms", "due_date",
			"status", "reference_number", "notes", "created_by", "created_at", "updated_at",
		}).AddRow(
			55, "PO-000042", locationID, supplierID,
			now, 10.0, 0.0, 0.0,
			10.0, 0.0, 0, nil,
			"PENDING", nil, nil, userID, now, now,
		))

	mock.ExpectRollback()

	p, err := svc.CreatePurchase(companyID, locationID, userID, req, idemKey)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if p == nil || p.PurchaseID != 55 {
		t.Fatalf("expected existing purchase_id=55, got %#v", p)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
