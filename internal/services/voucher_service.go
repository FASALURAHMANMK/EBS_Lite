package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type VoucherService struct {
	db *sql.DB
}

func NewVoucherService() *VoucherService {
	return &VoucherService{db: database.GetDB()}
}

func (s *VoucherService) CreateVoucher(companyID, userID int, vType string, req *models.CreateVoucherRequest) (int, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO vouchers (company_id, type, account_id, amount, reference, description, created_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING voucher_id`,
		companyID, vType, req.AccountID, req.Amount, req.Reference, req.Description, userID).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create voucher: %w", err)
	}
	ledger := NewLedgerService()
	switch vType {
	case "payment":
		_ = ledger.RecordExpense(companyID, id, req.Amount)
	case "receipt":
		_ = ledger.RecordSale(companyID, id, req.Amount)
	case "journal":
		// Placeholder for journal entries
	}
	return id, nil
}
