package services

import (
	"testing"

	sqlmock "github.com/DATA-DOG/go-sqlmock"

	"erp-backend/internal/models"
)

func TestVoucherServiceCreateVoucherRejectsJournal(t *testing.T) {
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	service := &VoucherService{db: db}
	_, err = service.CreateVoucher(1, 2, "journal", &models.CreateVoucherRequest{
		AccountID:   10,
		Amount:      25,
		Reference:   "JV-1",
		Description: nil,
	})
	if err == nil {
		t.Fatalf("expected error for journal voucher")
	}
}
