package services

import (
	"database/sql"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type LedgerService struct {
	db *sql.DB
}

func NewLedgerService() *LedgerService {
	return &LedgerService{db: database.GetDB()}
}

// RecordExpense creates ledger entries for an expense
func (s *LedgerService) RecordExpense(companyID, expenseID int, amount float64) error {
	// Placeholder implementation
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, debit) VALUES ($1,$2,$3)`, companyID, expenseID, amount)
	return err
}

// RecordSale creates ledger entries for a sale
func (s *LedgerService) RecordSale(companyID, saleID int, amount float64) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, credit) VALUES ($1,$2,$3)`, companyID, saleID, amount)
	return err
}

// RecordPurchase creates ledger entries for a purchase
func (s *LedgerService) RecordPurchase(companyID, purchaseID int, amount float64) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, debit) VALUES ($1,$2,$3)`, companyID, purchaseID, amount)
	return err
}

// GetAccountBalances returns balances for all accounts
func (s *LedgerService) GetAccountBalances(companyID int) ([]models.AccountBalance, error) {
	rows, err := s.db.Query(`SELECT account_id, SUM(debit - credit) as balance FROM ledger_entries WHERE company_id=$1 GROUP BY account_id`, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var balances []models.AccountBalance
	for rows.Next() {
		var b models.AccountBalance
		if err := rows.Scan(&b.AccountID, &b.Balance); err != nil {
			return nil, err
		}
		balances = append(balances, b)
	}
	return balances, nil
}
