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

func TestCollectionService_CreateCollection_IdempotencyUniqueViolationReturnsExisting(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &CollectionService{db: db}

	const (
		companyID  = 1
		locationID = 2
		userID     = 3
		customerID = 9
		idemKey    = "idem-col"
	)

	req := &models.CreateCollectionRequest{
		CustomerID: customerID,
		Amount:     25,
		SkipAllocation: func() *bool {
			v := true
			return &v
		}(),
	}

	mock.ExpectQuery(regexp.QuoteMeta("SELECT company_id FROM customers WHERE customer_id = $1 AND is_deleted = FALSE")).
		WithArgs(customerID).
		WillReturnRows(sqlmock.NewRows([]string{"company_id"}).AddRow(companyID))

	mock.ExpectBegin()

	mock.ExpectQuery("(?s)SELECT c.collection_id, c.collection_number.*FROM collections c.*WHERE c.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnError(sql.ErrNoRows)

	mock.ExpectQuery("(?s)SELECT sequence_id, prefix, sequence_length, current_number.*FROM numbering_sequences.*FOR UPDATE").
		WithArgs("collection", companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{"sequence_id", "prefix", "sequence_length", "current_number"}).
			AddRow(7, "COL-", 6, 10))

	mock.ExpectExec(regexp.QuoteMeta("UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2")).
		WithArgs(11, 7).
		WillReturnResult(sqlmock.NewResult(0, 1))

	mock.ExpectQuery("(?s)INSERT INTO collections \\(collection_number, customer_id, location_id, amount,.*RETURNING collection_id, collection_number, collection_date, created_at, updated_at").
		WillReturnError(&pq.Error{Code: "23505"})

	now := time.Now()
	mock.ExpectQuery("(?s)SELECT c.collection_id, c.collection_number.*FROM collections c.*WHERE c.idempotency_key = \\$1.*").
		WithArgs(idemKey, locationID, companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"collection_id", "collection_number", "customer_id", "location_id", "amount",
			"collection_date", "payment_method_id", "reference_number", "notes", "created_by", "updated_by",
			"created_at", "updated_at",
		}).AddRow(
			99, "COL-000011", customerID, locationID, 25.0,
			now, nil, nil, nil, userID, nil,
			now, now,
		))

	mock.ExpectRollback()

	col, err := svc.CreateCollection(companyID, locationID, userID, req, idemKey)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if col == nil || col.CollectionID != 99 {
		t.Fatalf("expected existing collection_id=99, got %#v", col)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
