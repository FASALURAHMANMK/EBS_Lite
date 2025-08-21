package services

import (
	"regexp"
	"testing"
	"time"

	"erp-backend/internal/models"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func TestRecordCreditTransaction(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &CustomerService{db: db}
	now := time.Now()

	mock.ExpectQuery(regexp.QuoteMeta(`INSERT INTO customer_credit_transactions (customer_id, company_id, amount, type, description, created_by)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING transaction_id, created_at`)).
		WithArgs(1, 1, 100.0, "credit", nil, 1).
		WillReturnRows(sqlmock.NewRows([]string{"transaction_id", "created_at"}).AddRow(1, now))

	mock.ExpectQuery(regexp.QuoteMeta(`SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),0)
         FROM customer_credit_transactions WHERE customer_id = $1 AND company_id = $2`)).
		WithArgs(1, 1).
		WillReturnRows(sqlmock.NewRows([]string{"balance"}).AddRow(100.0))

	req := &models.CreditTransactionRequest{Amount: 100, Type: "credit"}

	tx, err := svc.RecordCreditTransaction(1, 1, 1, req)
	if err != nil {
		t.Fatalf("RecordCreditTransaction returned error: %v", err)
	}
	if tx.NewBalance != 100 {
		t.Fatalf("expected balance 100, got %f", tx.NewBalance)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("there were unfulfilled expectations: %v", err)
	}
}

func TestGetCreditHistory(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &CustomerService{db: db}
	now := time.Now()

	rows := sqlmock.NewRows([]string{"transaction_id", "customer_id", "company_id", "amount", "type", "description", "created_by", "created_at", "new_balance"}).
		AddRow(1, 1, 1, 100.0, "credit", "init", 1, now, 100.0).
		AddRow(2, 1, 1, 50.0, "debit", "payment", 1, now.Add(time.Hour), 50.0)

	mock.ExpectQuery(regexp.QuoteMeta(`SELECT transaction_id, customer_id, company_id, amount, type, description, created_by, created_at,
                SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END) OVER (ORDER BY created_at ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS new_balance
         FROM customer_credit_transactions
         WHERE customer_id = $1 AND company_id = $2
         ORDER BY created_at DESC`)).
		WithArgs(1, 1).
		WillReturnRows(rows)

	history, err := svc.GetCreditHistory(1, 1)
	if err != nil {
		t.Fatalf("GetCreditHistory returned error: %v", err)
	}
	if len(history) != 2 {
		t.Fatalf("expected 2 transactions, got %d", len(history))
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("there were unfulfilled expectations: %v", err)
	}
}
