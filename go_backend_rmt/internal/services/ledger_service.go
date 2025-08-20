package services

import (
	"database/sql"
	"fmt"

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
func (s *LedgerService) RecordExpense(companyID, expenseID int, amount float64, userID int) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, debit, created_by, updated_by) VALUES ($1,$2,$3,$4,$4)`, companyID, expenseID, amount, userID)
	return err
}

// RecordSale creates ledger entries for a sale
func (s *LedgerService) RecordSale(companyID, saleID int, amount float64, userID int) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, credit, created_by, updated_by) VALUES ($1,$2,$3,$4,$4)`, companyID, saleID, amount, userID)
	return err
}

// RecordPurchase creates ledger entries for a purchase
func (s *LedgerService) RecordPurchase(companyID, purchaseID int, amount float64, userID int) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, debit, created_by, updated_by) VALUES ($1,$2,$3,$4,$4)`, companyID, purchaseID, amount, userID)
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

// GetAccountEntries retrieves ledger entries for an account with optional filters and pagination
func (s *LedgerService) GetAccountEntries(companyID, accountID int, filters map[string]string, page, pageSize int) ([]models.LedgerEntryWithDetails, int, error) {
	baseQuery := `SELECT le.entry_id, le.company_id, le.account_id, le.voucher_id, le.date, le.debit, le.credit, le.balance, le.transaction_type, le.transaction_id, le.description, le.created_by, le.updated_by, le.sync_status, le.created_at, le.updated_at,
                v.type, v.amount, v.reference, v.description,
                s.sale_id, s.sale_number, s.total_amount, s.sale_date,
                p.purchase_id, p.purchase_number, p.total_amount, p.purchase_date
                FROM ledger_entries le
                LEFT JOIN vouchers v ON le.voucher_id = v.voucher_id AND v.is_deleted = FALSE
                LEFT JOIN sales s ON le.transaction_type = 'sale' AND le.transaction_id = s.sale_id
                LEFT JOIN purchases p ON le.transaction_type = 'purchase' AND le.transaction_id = p.purchase_id
                WHERE le.company_id = $1 AND le.account_id = $2`

	countQuery := `SELECT COUNT(*) FROM ledger_entries le WHERE le.company_id = $1 AND le.account_id = $2`

	args := []interface{}{companyID, accountID}
	countArgs := []interface{}{companyID, accountID}
	argPos := 2

	if v, ok := filters["date_from"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND le.date >= $%d", argPos)
		countQuery += fmt.Sprintf(" AND le.date >= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND le.date <= $%d", argPos)
		countQuery += fmt.Sprintf(" AND le.date <= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}

	var total int
	if err := s.db.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("failed to count ledger entries: %w", err)
	}

	if pageSize <= 0 {
		pageSize = 20
	}
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * pageSize
	baseQuery += fmt.Sprintf(" ORDER BY le.date DESC, le.entry_id DESC LIMIT $%d OFFSET $%d", argPos+1, argPos+2)
	args = append(args, pageSize, offset)

	rows, err := s.db.Query(baseQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get ledger entries: %w", err)
	}
	defer rows.Close()

	var entries []models.LedgerEntryWithDetails
	for rows.Next() {
		var e models.LedgerEntryWithDetails
		var voucherType, voucherRef, voucherDesc sql.NullString
		var voucherAmount sql.NullFloat64
		var saleID sql.NullInt64
		var saleNumber sql.NullString
		var saleAmount sql.NullFloat64
		var saleDate sql.NullTime
		var purchaseID sql.NullInt64
		var purchaseNumber sql.NullString
		var purchaseAmount sql.NullFloat64
		var purchaseDate sql.NullTime
		var transactionType, description sql.NullString
		var transactionID, updatedBy sql.NullInt64
		var voucherID sql.NullInt64

		if err := rows.Scan(
			&e.EntryID, &e.CompanyID, &e.AccountID, &voucherID, &e.Date, &e.Debit, &e.Credit, &e.Balance, &transactionType, &transactionID, &description, &e.CreatedBy, &updatedBy, &e.SyncStatus, &e.CreatedAt, &e.UpdatedAt,
			&voucherType, &voucherAmount, &voucherRef, &voucherDesc,
			&saleID, &saleNumber, &saleAmount, &saleDate,
			&purchaseID, &purchaseNumber, &purchaseAmount, &purchaseDate,
		); err != nil {
			return nil, 0, fmt.Errorf("failed to scan ledger entry: %w", err)
		}

		if voucherID.Valid {
			v := int(voucherID.Int64)
			e.VoucherID = &v
		}
		if transactionType.Valid {
			e.TransactionType = &transactionType.String
		}
		if transactionID.Valid {
			id := int(transactionID.Int64)
			e.TransactionID = &id
		}
		if description.Valid {
			e.Description = &description.String
		}
		if updatedBy.Valid {
			u := int(updatedBy.Int64)
			e.UpdatedBy = &u
		}

		if voucherType.Valid {
			e.Voucher = &models.Voucher{
				VoucherID:   0,
				Type:        voucherType.String,
				Amount:      voucherAmount.Float64,
				Reference:   voucherRef.String,
				Description: nullStringToStringPtr(voucherDesc),
			}
			if e.VoucherID != nil {
				e.Voucher.VoucherID = *e.VoucherID
			}
		}
		if saleID.Valid {
			e.Sale = &models.Sale{
				SaleID:      int(saleID.Int64),
				SaleNumber:  saleNumber.String,
				TotalAmount: saleAmount.Float64,
			}
			if saleDate.Valid {
				e.Sale.SaleDate = saleDate.Time
			}
		}
		if purchaseID.Valid {
			e.Purchase = &models.Purchase{
				PurchaseID:     int(purchaseID.Int64),
				PurchaseNumber: purchaseNumber.String,
				TotalAmount:    purchaseAmount.Float64,
			}
			if purchaseDate.Valid {
				e.Purchase.PurchaseDate = purchaseDate.Time
			}
		}

		entries = append(entries, e)
	}

	return entries, total, nil
}

// RecordPurchaseReturn creates ledger entries for a purchase return
func (s *LedgerService) RecordPurchaseReturn(companyID, returnID int, amount float64, userID int) error {
	_, err := s.db.Exec(`INSERT INTO ledger_entries (company_id, reference, credit, created_by, updated_by) VALUES ($1,$2,$3,$4,$4)`, companyID, returnID, amount, userID)
	return err
}
