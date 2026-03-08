package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type LedgerService struct {
	db *sql.DB
}

func NewLedgerService() *LedgerService {
	return &LedgerService{db: database.GetDB()}
}

const (
	accountCodeCash          = "1000"
	accountCodeBank          = "1010"
	accountCodeAR            = "1100"
	accountCodeInventory     = "1200"
	accountCodeAP            = "2000"
	accountCodeTaxPayable    = "2100"
	accountCodeTaxReceivable = "2200"
	accountCodeSalesRevenue  = "4000"
	accountCodeExpenses      = "6000"
)

func (s *LedgerService) ensureDefaultAccountID(companyID int, code string) (int, error) {
	var def *defaultAccount
	for i := range minimalDefaultChartOfAccounts {
		if minimalDefaultChartOfAccounts[i].Code == code {
			def = &minimalDefaultChartOfAccounts[i]
			break
		}
	}
	if def == nil {
		return 0, fmt.Errorf("unknown default account code: %s", code)
	}

	// Try fast path first.
	var id int
	if err := s.db.QueryRow(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`, companyID, code).Scan(&id); err == nil {
		return id, nil
	} else if err != sql.ErrNoRows {
		return 0, fmt.Errorf("failed to lookup chart of account (%s): %w", code, err)
	}

	// Best-effort: seed minimal COA for this company and retry.
	tx, err := s.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to begin coa seed tx: %w", err)
	}
	defer tx.Rollback()
	if err := seedMinimalChartOfAccountsTx(tx, companyID); err != nil {
		return 0, err
	}
	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit coa seed tx: %w", err)
	}

	if err := s.db.QueryRow(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`, companyID, code).Scan(&id); err != nil {
		return 0, fmt.Errorf("failed to lookup seeded chart of account (%s): %w", code, err)
	}
	return id, nil
}

func (s *LedgerService) insertEntryIfMissing(companyID int, reference string, accountID int, date time.Time, debit, credit float64, transactionType string, transactionID int, description *string, voucherID *int, userID int) error {
	_, err := s.db.Exec(`
		INSERT INTO ledger_entries (
			company_id, account_id, voucher_id, date, debit, credit, balance,
			transaction_type, transaction_id, description, reference,
			created_by, updated_by
		)
		SELECT $1,$2,$3,$4,$5,$6,0,$7,$8,$9,$10,$11,$11
		WHERE NOT EXISTS (
			SELECT 1 FROM ledger_entries
			WHERE company_id = $1 AND reference = $10
		)
	`, companyID, accountID, voucherID, date, debit, credit, transactionType, transactionID, description, reference, userID)
	if err != nil {
		return fmt.Errorf("failed to insert ledger entry (%s): %w", reference, err)
	}
	return nil
}

// RecordSale posts minimal double-entry ledger lines for a completed sale.
func (s *LedgerService) RecordSale(companyID, saleID, userID int) error {
	var total, tax, paid float64
	var saleDate time.Time
	if err := s.db.QueryRow(`
		SELECT s.total_amount, s.tax_amount, s.paid_amount, s.sale_date
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&total, &tax, &paid, &saleDate); err != nil {
		return fmt.Errorf("failed to load sale for ledger posting: %w", err)
	}

	netSales := total - tax
	if netSales < 0 {
		netSales = 0
	}
	outstanding := total - paid
	if outstanding < 0 {
		outstanding = 0
	}

	cashID, err := s.ensureDefaultAccountID(companyID, accountCodeCash)
	if err != nil {
		return err
	}
	arID, err := s.ensureDefaultAccountID(companyID, accountCodeAR)
	if err != nil {
		return err
	}
	salesID, err := s.ensureDefaultAccountID(companyID, accountCodeSalesRevenue)
	if err != nil {
		return err
	}
	taxPayableID, err := s.ensureDefaultAccountID(companyID, accountCodeTaxPayable)
	if err != nil {
		return err
	}

	if paid > 0 {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeCash)
		if err := s.insertEntryIfMissing(companyID, ref, cashID, saleDate, paid, 0, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if outstanding > 0 {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeAR)
		if err := s.insertEntryIfMissing(companyID, ref, arID, saleDate, outstanding, 0, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if netSales > 0 {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeSalesRevenue)
		if err := s.insertEntryIfMissing(companyID, ref, salesID, saleDate, 0, netSales, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if tax > 0 {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeTaxPayable)
		if err := s.insertEntryIfMissing(companyID, ref, taxPayableID, saleDate, 0, tax, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	return nil
}

// RecordPurchase posts minimal double-entry ledger lines for a purchase.
func (s *LedgerService) RecordPurchase(companyID, purchaseID, userID int) error {
	var total, tax, paid float64
	var purchaseDate time.Time
	if err := s.db.QueryRow(`
		SELECT p.total_amount, p.tax_amount, p.paid_amount, p.purchase_date
		FROM purchases p
		JOIN locations l ON l.location_id = p.location_id
		WHERE p.purchase_id = $1 AND l.company_id = $2 AND p.is_deleted = FALSE
	`, purchaseID, companyID).Scan(&total, &tax, &paid, &purchaseDate); err != nil {
		return fmt.Errorf("failed to load purchase for ledger posting: %w", err)
	}

	netInventory := total - tax
	if netInventory < 0 {
		netInventory = 0
	}
	outstanding := total - paid
	if outstanding < 0 {
		outstanding = 0
	}

	cashID, err := s.ensureDefaultAccountID(companyID, accountCodeCash)
	if err != nil {
		return err
	}
	apID, err := s.ensureDefaultAccountID(companyID, accountCodeAP)
	if err != nil {
		return err
	}
	invID, err := s.ensureDefaultAccountID(companyID, accountCodeInventory)
	if err != nil {
		return err
	}
	taxRecID, err := s.ensureDefaultAccountID(companyID, accountCodeTaxReceivable)
	if err != nil {
		return err
	}

	if netInventory > 0 {
		ref := fmt.Sprintf("purchase:%d:%s", purchaseID, accountCodeInventory)
		if err := s.insertEntryIfMissing(companyID, ref, invID, purchaseDate, netInventory, 0, "purchase", purchaseID, nil, nil, userID); err != nil {
			return err
		}
	}
	if tax > 0 {
		ref := fmt.Sprintf("purchase:%d:%s", purchaseID, accountCodeTaxReceivable)
		if err := s.insertEntryIfMissing(companyID, ref, taxRecID, purchaseDate, tax, 0, "purchase", purchaseID, nil, nil, userID); err != nil {
			return err
		}
	}
	if paid > 0 {
		ref := fmt.Sprintf("purchase:%d:%s", purchaseID, accountCodeCash)
		if err := s.insertEntryIfMissing(companyID, ref, cashID, purchaseDate, 0, paid, "purchase", purchaseID, nil, nil, userID); err != nil {
			return err
		}
	}
	if outstanding > 0 {
		ref := fmt.Sprintf("purchase:%d:%s", purchaseID, accountCodeAP)
		if err := s.insertEntryIfMissing(companyID, ref, apID, purchaseDate, 0, outstanding, "purchase", purchaseID, nil, nil, userID); err != nil {
			return err
		}
	}
	return nil
}

// RecordExpense posts minimal double-entry ledger lines for an expense.
func (s *LedgerService) RecordExpense(companyID, expenseID, userID int) error {
	var amount float64
	var expenseDate time.Time
	if err := s.db.QueryRow(`
		SELECT e.amount, e.expense_date
		FROM expenses e
		JOIN expense_categories c ON c.category_id = e.category_id
		WHERE e.expense_id = $1 AND c.company_id = $2 AND e.is_deleted = FALSE
	`, expenseID, companyID).Scan(&amount, &expenseDate); err != nil {
		return fmt.Errorf("failed to load expense for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	expID, err := s.ensureDefaultAccountID(companyID, accountCodeExpenses)
	if err != nil {
		return err
	}
	cashID, err := s.ensureDefaultAccountID(companyID, accountCodeCash)
	if err != nil {
		return err
	}

	ref1 := fmt.Sprintf("expense:%d:%s", expenseID, accountCodeExpenses)
	if err := s.insertEntryIfMissing(companyID, ref1, expID, expenseDate, amount, 0, "expense", expenseID, nil, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("expense:%d:%s", expenseID, accountCodeCash)
	if err := s.insertEntryIfMissing(companyID, ref2, cashID, expenseDate, 0, amount, "expense", expenseID, nil, nil, userID); err != nil {
		return err
	}
	return nil
}

// RecordPayrollPayment posts a minimal double-entry for a paid payroll.
// Debit: Expenses (6000)
// Credit: Cash (1000)
func (s *LedgerService) RecordPayrollPayment(companyID, payrollID, userID int, paymentDate time.Time) error {
	var amount float64
	if err := s.db.QueryRow(`
		SELECT p.net_salary
		FROM payroll p
		JOIN employees e ON p.employee_id = e.employee_id
		WHERE p.payroll_id = $1 AND e.company_id = $2
	`, payrollID, companyID).Scan(&amount); err != nil {
		return fmt.Errorf("failed to load payroll for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	expID, err := s.ensureDefaultAccountID(companyID, accountCodeExpenses)
	if err != nil {
		return err
	}
	cashID, err := s.ensureDefaultAccountID(companyID, accountCodeCash)
	if err != nil {
		return err
	}

	desc := fmt.Sprintf("Payroll payment #%d", payrollID)
	ref1 := fmt.Sprintf("payroll:%d:%s", payrollID, accountCodeExpenses)
	if err := s.insertEntryIfMissing(companyID, ref1, expID, paymentDate, amount, 0, "payroll", payrollID, &desc, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("payroll:%d:%s", payrollID, accountCodeCash)
	if err := s.insertEntryIfMissing(companyID, ref2, cashID, paymentDate, 0, amount, "payroll", payrollID, &desc, nil, userID); err != nil {
		return err
	}
	return nil
}

// RecordCollection posts minimal double-entry ledger lines for a collection.
func (s *LedgerService) RecordCollection(companyID, collectionID, userID int) error {
	var amount float64
	var collectionDate time.Time
	var paymentType sql.NullString
	if err := s.db.QueryRow(`
		SELECT c.amount, c.collection_date, pm.type
		FROM collections c
		JOIN customers cu ON cu.customer_id = c.customer_id
		LEFT JOIN payment_methods pm ON pm.method_id = c.payment_method_id
		WHERE c.collection_id = $1 AND cu.company_id = $2
	`, collectionID, companyID).Scan(&amount, &collectionDate, &paymentType); err != nil {
		return fmt.Errorf("failed to load collection for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	assetCode := accountCodeCash
	if paymentType.Valid && paymentType.String != "" && paymentType.String != "CASH" && paymentType.String != "cash" {
		assetCode = accountCodeBank
	}

	assetID, err := s.ensureDefaultAccountID(companyID, assetCode)
	if err != nil {
		return err
	}
	arID, err := s.ensureDefaultAccountID(companyID, accountCodeAR)
	if err != nil {
		return err
	}

	ref1 := fmt.Sprintf("collection:%d:%s", collectionID, assetCode)
	if err := s.insertEntryIfMissing(companyID, ref1, assetID, collectionDate, amount, 0, "collection", collectionID, nil, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("collection:%d:%s", collectionID, accountCodeAR)
	if err := s.insertEntryIfMissing(companyID, ref2, arID, collectionDate, 0, amount, "collection", collectionID, nil, nil, userID); err != nil {
		return err
	}
	return nil
}

// RecordSupplierPayment posts minimal double-entry ledger lines for a supplier payment.
func (s *LedgerService) RecordSupplierPayment(companyID, paymentID, userID int) error {
	var amount float64
	var paymentDate time.Time
	var paymentType sql.NullString
	if err := s.db.QueryRow(`
		SELECT p.amount, p.payment_date, pm.type
		FROM payments p
		LEFT JOIN payment_methods pm ON pm.method_id = p.payment_method_id
		LEFT JOIN suppliers s ON s.supplier_id = p.supplier_id
		WHERE p.payment_id = $1 AND (s.company_id = $2 OR p.supplier_id IS NULL)
	`, paymentID, companyID).Scan(&amount, &paymentDate, &paymentType); err != nil {
		return fmt.Errorf("failed to load supplier payment for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	assetCode := accountCodeCash
	if paymentType.Valid && paymentType.String != "" && paymentType.String != "CASH" && paymentType.String != "cash" {
		assetCode = accountCodeBank
	}

	apID, err := s.ensureDefaultAccountID(companyID, accountCodeAP)
	if err != nil {
		return err
	}
	assetID, err := s.ensureDefaultAccountID(companyID, assetCode)
	if err != nil {
		return err
	}

	ref1 := fmt.Sprintf("payment:%d:%s", paymentID, accountCodeAP)
	if err := s.insertEntryIfMissing(companyID, ref1, apID, paymentDate, amount, 0, "payment", paymentID, nil, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("payment:%d:%s", paymentID, assetCode)
	if err := s.insertEntryIfMissing(companyID, ref2, assetID, paymentDate, 0, amount, "payment", paymentID, nil, nil, userID); err != nil {
		return err
	}
	return nil
}

// GetAccountBalances returns balances for all accounts
func (s *LedgerService) GetAccountBalances(companyID int) ([]models.AccountBalance, error) {
	rows, err := s.db.Query(`
		SELECT
			coa.account_id,
			coa.account_code,
			coa.name,
			coa.type,
			COALESCE(SUM(le.debit - le.credit), 0)::float8 AS balance
		FROM chart_of_accounts coa
		LEFT JOIN ledger_entries le
		       ON le.company_id = $1 AND le.account_id = coa.account_id
		WHERE coa.company_id = $1 AND coa.is_active = TRUE
		GROUP BY coa.account_id, coa.account_code, coa.name, coa.type
		ORDER BY coa.account_code NULLS LAST, coa.account_id
	`, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var balances []models.AccountBalance
	for rows.Next() {
		var b models.AccountBalance
		if err := rows.Scan(&b.AccountID, &b.AccountCode, &b.AccountName, &b.AccountType, &b.Balance); err != nil {
			return nil, err
		}
		balances = append(balances, b)
	}
	return balances, nil
}

// GetAccountEntries retrieves ledger entries for an account with optional filters and pagination
func (s *LedgerService) GetAccountEntries(companyID, accountID int, filters map[string]string, page, pageSize int) ([]models.LedgerEntryWithDetails, int, error) {
	baseQuery := `WITH filtered AS (
					SELECT le.*,
					       COALESCE(
					         SUM(le.debit - le.credit) OVER (
					           PARTITION BY le.company_id, le.account_id
					           ORDER BY le.date, le.entry_id
					           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
					         ),
					         0
					       )::float8 AS running_balance
					FROM ledger_entries le
					WHERE le.company_id = $1 AND le.account_id = $2
				)
				SELECT le.entry_id, le.company_id, le.account_id, le.voucher_id, le.date, le.debit, le.credit, le.running_balance AS balance, le.transaction_type, le.transaction_id, le.description, le.created_by, le.updated_by, le.sync_status, le.created_at, le.updated_at,
                v.type, v.amount, v.reference, v.description,
                s.sale_id, s.sale_number, s.total_amount, s.sale_date,
                p.purchase_id, p.purchase_number, p.total_amount, p.purchase_date
                FROM filtered le
                LEFT JOIN vouchers v ON le.voucher_id = v.voucher_id AND v.is_deleted = FALSE
                LEFT JOIN sales s ON le.transaction_type = 'sale' AND le.transaction_id = s.sale_id
                LEFT JOIN purchases p ON le.transaction_type = 'purchase' AND le.transaction_id = p.purchase_id
                WHERE 1=1`

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

// RecordPurchaseReturn posts minimal ledger lines for a purchase return.
func (s *LedgerService) RecordPurchaseReturn(companyID, returnID, userID int) error {
	var amount float64
	var returnDate time.Time
	if err := s.db.QueryRow(`
		SELECT pr.total_amount, pr.return_date
		FROM purchase_returns pr
		JOIN locations l ON l.location_id = pr.location_id
		WHERE pr.return_id = $1 AND l.company_id = $2 AND pr.is_deleted = FALSE
	`, returnID, companyID).Scan(&amount, &returnDate); err != nil {
		return fmt.Errorf("failed to load purchase return for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	apID, err := s.ensureDefaultAccountID(companyID, accountCodeAP)
	if err != nil {
		return err
	}
	invID, err := s.ensureDefaultAccountID(companyID, accountCodeInventory)
	if err != nil {
		return err
	}

	ref1 := fmt.Sprintf("purchase_return:%d:%s", returnID, accountCodeAP)
	if err := s.insertEntryIfMissing(companyID, ref1, apID, returnDate, amount, 0, "purchase_return", returnID, nil, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("purchase_return:%d:%s", returnID, accountCodeInventory)
	if err := s.insertEntryIfMissing(companyID, ref2, invID, returnDate, 0, amount, "purchase_return", returnID, nil, nil, userID); err != nil {
		return err
	}
	return nil
}

// RecordVoucher posts minimal ledger lines for a voucher.
// Interpretation:
// - payment: debit voucher.account_id, credit cash
// - receipt: debit cash, credit voucher.account_id
// - journal: not supported for automatic posting (no lines available)
func (s *LedgerService) RecordVoucher(companyID, voucherID, userID int) error {
	var vType string
	var amount float64
	var accountID int
	var vDate time.Time
	var reference sql.NullString
	var description sql.NullString
	if err := s.db.QueryRow(`
		SELECT v.type, v.amount, v.account_id, v.date, v.reference, v.description
		FROM vouchers v
		WHERE v.voucher_id = $1 AND v.company_id = $2 AND v.is_deleted = FALSE
	`, voucherID, companyID).Scan(&vType, &amount, &accountID, &vDate, &reference, &description); err != nil {
		return fmt.Errorf("failed to load voucher for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}
	if vType == "journal" {
		return nil
	}

	cashID, err := s.ensureDefaultAccountID(companyID, accountCodeCash)
	if err != nil {
		return err
	}

	var desc *string
	if description.Valid && description.String != "" {
		desc = &description.String
	} else if reference.Valid && reference.String != "" {
		desc = &reference.String
	}

	switch vType {
	case "payment":
		ref1 := fmt.Sprintf("voucher:%d:acct:%d:debit", voucherID, accountID)
		if err := s.insertEntryIfMissing(companyID, ref1, accountID, vDate, amount, 0, "voucher", voucherID, desc, &voucherID, userID); err != nil {
			return err
		}
		ref2 := fmt.Sprintf("voucher:%d:%s:credit", voucherID, accountCodeCash)
		if err := s.insertEntryIfMissing(companyID, ref2, cashID, vDate, 0, amount, "voucher", voucherID, desc, &voucherID, userID); err != nil {
			return err
		}
	case "receipt":
		ref1 := fmt.Sprintf("voucher:%d:%s:debit", voucherID, accountCodeCash)
		if err := s.insertEntryIfMissing(companyID, ref1, cashID, vDate, amount, 0, "voucher", voucherID, desc, &voucherID, userID); err != nil {
			return err
		}
		ref2 := fmt.Sprintf("voucher:%d:acct:%d:credit", voucherID, accountID)
		if err := s.insertEntryIfMissing(companyID, ref2, accountID, vDate, 0, amount, "voucher", voucherID, desc, &voucherID, userID); err != nil {
			return err
		}
	default:
		return nil
	}
	return nil
}
