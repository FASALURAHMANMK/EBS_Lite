package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"
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
	accountCodeFixedAssets   = "1210"
	accountCodeAP            = "2000"
	accountCodeTaxPayable    = "2100"
	accountCodeTaxReceivable = "2200"
	accountCodeSalesRevenue  = "4000"
	accountCodeCOGS          = "5000"
	accountCodeExpenses      = "6000"
	accountCodeConsumables   = "6010"
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

func signedLedgerAmounts(amount float64, positiveAsDebit bool) (float64, float64, bool) {
	if math.Abs(amount) < 0.0001 {
		return 0, 0, false
	}
	if amount > 0 {
		if positiveAsDebit {
			return amount, 0, true
		}
		return 0, amount, true
	}
	if positiveAsDebit {
		return 0, -amount, true
	}
	return -amount, 0, true
}

func (s *LedgerService) saleCOGSAmount(companyID, saleID int) (float64, error) {
	var amount float64
	if err := s.db.QueryRow(`
		SELECT COALESCE(SUM(sd.quantity * COALESCE(sd.cost_price, 0)), 0)::float8
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE sd.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&amount); err != nil {
		return 0, fmt.Errorf("failed to load sale cost for ledger posting: %w", err)
	}
	return amount, nil
}

func (s *LedgerService) saleReturnAmounts(companyID, returnID int) (float64, float64, float64, time.Time, error) {
	var total, tax, cogs float64
	var returnDate time.Time
	if err := s.db.QueryRow(`
		SELECT
			sr.total_amount,
			sr.return_date,
			COALESCE(SUM(COALESCE(srd.tax_amount, 0)), 0)::float8 AS tax_amount,
			COALESCE(SUM(srd.quantity * COALESCE(srd.cost_price, 0)), 0)::float8 AS cogs_reversal
		FROM sale_returns sr
		JOIN locations l ON l.location_id = sr.location_id
		LEFT JOIN sale_return_details srd ON srd.return_id = sr.return_id
		WHERE sr.return_id = $1 AND l.company_id = $2 AND sr.is_deleted = FALSE
		GROUP BY sr.return_id, sr.total_amount, sr.return_date
	`, returnID, companyID).Scan(&total, &returnDate, &tax, &cogs); err != nil {
		return 0, 0, 0, time.Time{}, fmt.Errorf("failed to load sale return for ledger posting: %w", err)
	}
	return total, tax, cogs, returnDate, nil
}

func (s *LedgerService) purchaseReturnAmounts(companyID, returnID int) (float64, float64, time.Time, error) {
	var total, tax float64
	var returnDate time.Time
	if err := s.db.QueryRow(`
		SELECT
			pr.total_amount,
			pr.return_date,
			COALESCE(SUM(
				CASE
					WHEN prd.purchase_detail_id IS NOT NULL AND COALESCE(pd.quantity, 0) <> 0
						THEN (COALESCE(pd.tax_amount, 0) / pd.quantity) * prd.quantity
					ELSE 0
				END
			), 0)::float8 AS tax_amount
		FROM purchase_returns pr
		JOIN locations l ON l.location_id = pr.location_id
		LEFT JOIN purchase_return_details prd ON prd.return_id = pr.return_id
		LEFT JOIN purchase_details pd ON pd.purchase_detail_id = prd.purchase_detail_id
		WHERE pr.return_id = $1 AND l.company_id = $2 AND pr.is_deleted = FALSE
		GROUP BY pr.return_id, pr.total_amount, pr.return_date
	`, returnID, companyID).Scan(&total, &returnDate, &tax); err != nil {
		return 0, 0, time.Time{}, fmt.Errorf("failed to load purchase return for ledger posting: %w", err)
	}
	return total, tax, returnDate, nil
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
	outstanding := total - paid

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
	cogsID, err := s.ensureDefaultAccountID(companyID, accountCodeCOGS)
	if err != nil {
		return err
	}
	inventoryID, err := s.ensureDefaultAccountID(companyID, accountCodeInventory)
	if err != nil {
		return err
	}
	cogsAmount, err := s.saleCOGSAmount(companyID, saleID)
	if err != nil {
		return err
	}

	if debit, credit, ok := signedLedgerAmounts(paid, true); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeCash)
		if err := s.insertEntryIfMissing(companyID, ref, cashID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if debit, credit, ok := signedLedgerAmounts(outstanding, true); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeAR)
		if err := s.insertEntryIfMissing(companyID, ref, arID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if debit, credit, ok := signedLedgerAmounts(netSales, false); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeSalesRevenue)
		if err := s.insertEntryIfMissing(companyID, ref, salesID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if debit, credit, ok := signedLedgerAmounts(tax, false); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeTaxPayable)
		if err := s.insertEntryIfMissing(companyID, ref, taxPayableID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if debit, credit, ok := signedLedgerAmounts(cogsAmount, true); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeCOGS)
		if err := s.insertEntryIfMissing(companyID, ref, cogsID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
			return err
		}
	}
	if debit, credit, ok := signedLedgerAmounts(cogsAmount, false); ok {
		ref := fmt.Sprintf("sale:%d:%s", saleID, accountCodeInventory)
		if err := s.insertEntryIfMissing(companyID, ref, inventoryID, saleDate, debit, credit, "sale", saleID, nil, nil, userID); err != nil {
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
	totalAmount, taxAmount, returnDate, err := s.purchaseReturnAmounts(companyID, returnID)
	if err != nil {
		return err
	}
	if totalAmount <= 0 {
		return nil
	}
	netInventory := totalAmount - taxAmount
	if netInventory < 0 {
		netInventory = 0
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

	ref1 := fmt.Sprintf("purchase_return:%d:%s", returnID, accountCodeAP)
	if err := s.insertEntryIfMissing(companyID, ref1, apID, returnDate, totalAmount, 0, "purchase_return", returnID, nil, nil, userID); err != nil {
		return err
	}
	if netInventory > 0 {
		ref2 := fmt.Sprintf("purchase_return:%d:%s", returnID, accountCodeInventory)
		if err := s.insertEntryIfMissing(companyID, ref2, invID, returnDate, 0, netInventory, "purchase_return", returnID, nil, nil, userID); err != nil {
			return err
		}
	}
	if taxAmount > 0 {
		ref3 := fmt.Sprintf("purchase_return:%d:%s", returnID, accountCodeTaxReceivable)
		if err := s.insertEntryIfMissing(companyID, ref3, taxRecID, returnDate, 0, taxAmount, "purchase_return", returnID, nil, nil, userID); err != nil {
			return err
		}
	}
	return nil
}

func (s *LedgerService) RecordPurchaseCostAdjustment(companyID, adjustmentID, userID int) error {
	var adjustmentDate time.Time
	var totalSigned float64
	var inventoryPortion float64
	var consumedPortion float64
	if err := s.db.QueryRow(`
		SELECT
			pca.adjustment_date,
			COALESCE(SUM(pcai.signed_amount), 0)::float8 AS total_signed,
			COALESCE(SUM(
				CASE
					WHEN pcai.stock_action = 'REDUCE_STOCK' THEN pcai.signed_amount
					WHEN COALESCE(lot.remaining_qty, 0) > 0 AND COALESCE(base.received_stock_qty, 0) > 0
						THEN pcai.signed_amount * (lot.remaining_qty / base.received_stock_qty)
					ELSE 0
				END
			), 0)::float8 AS inventory_portion
		FROM purchase_cost_adjustments pca
		JOIN purchase_cost_adjustment_items pcai ON pcai.adjustment_id = pca.adjustment_id
		LEFT JOIN (
			SELECT
				pcai_inner.adjustment_item_id,
				COALESCE(SUM(sl.remaining_quantity), 0)::float8 AS remaining_qty
			FROM purchase_cost_adjustment_items pcai_inner
			LEFT JOIN stock_lots sl
			  ON sl.lot_id IN (
			    SELECT DISTINCT im.stock_lot_id
			    FROM inventory_movements im
			    WHERE im.source_type = 'purchase_detail'
			      AND im.source_line_id = pcai_inner.purchase_detail_id
			      AND im.movement_type = 'PURCHASE_RECEIPT'
			      AND im.stock_lot_id IS NOT NULL
			  )
			 AND (
			   pcai_inner.goods_receipt_item_id IS NULL
			   OR sl.goods_receipt_id = (
			     SELECT goods_receipt_id
			     FROM goods_receipt_items
			     WHERE goods_receipt_item_id = pcai_inner.goods_receipt_item_id
			   )
			 )
			 AND sl.remaining_quantity > 0
			GROUP BY pcai_inner.adjustment_item_id
		) lot ON lot.adjustment_item_id = pcai.adjustment_item_id
		LEFT JOIN (
			SELECT
				pcai_inner.adjustment_item_id,
				COALESCE((
					SELECT SUM(im.quantity)::float8
					FROM inventory_movements im
					WHERE im.source_type = 'purchase_detail'
					  AND im.source_line_id = pcai_inner.purchase_detail_id
					  AND im.movement_type = 'PURCHASE_RECEIPT'
				), 0)::float8 AS received_stock_qty
			FROM purchase_cost_adjustment_items pcai_inner
		) base ON base.adjustment_item_id = pcai.adjustment_item_id
		WHERE pca.adjustment_id = $1
		  AND pca.is_deleted = FALSE
		GROUP BY pca.adjustment_date
	`, adjustmentID).Scan(&adjustmentDate, &totalSigned, &inventoryPortion); err != nil {
		return fmt.Errorf("failed to load purchase cost adjustment for ledger posting: %w", err)
	}
	consumedPortion = totalSigned - inventoryPortion
	if math.Abs(totalSigned) < 0.0001 {
		return nil
	}

	apID, err := s.ensureDefaultAccountID(companyID, accountCodeAP)
	if err != nil {
		return err
	}
	inventoryID, err := s.ensureDefaultAccountID(companyID, accountCodeInventory)
	if err != nil {
		return err
	}
	cogsID, err := s.ensureDefaultAccountID(companyID, accountCodeCOGS)
	if err != nil {
		return err
	}

	if totalSigned > 0 {
		ref := fmt.Sprintf("purchase_adjustment:%d:%s", adjustmentID, accountCodeAP)
		if err := s.insertEntryIfMissing(companyID, ref, apID, adjustmentDate, 0, round2(totalSigned), "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
			return err
		}
	} else {
		ref := fmt.Sprintf("purchase_adjustment:%d:%s", adjustmentID, accountCodeAP)
		if err := s.insertEntryIfMissing(companyID, ref, apID, adjustmentDate, round2(-totalSigned), 0, "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
			return err
		}
	}

	if math.Abs(inventoryPortion) > 0.0001 {
		ref := fmt.Sprintf("purchase_adjustment:%d:%s", adjustmentID, accountCodeInventory)
		if inventoryPortion > 0 {
			if err := s.insertEntryIfMissing(companyID, ref, inventoryID, adjustmentDate, round2(inventoryPortion), 0, "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
				return err
			}
		} else {
			if err := s.insertEntryIfMissing(companyID, ref, inventoryID, adjustmentDate, 0, round2(-inventoryPortion), "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
				return err
			}
		}
	}

	if math.Abs(consumedPortion) > 0.0001 {
		ref := fmt.Sprintf("purchase_adjustment:%d:%s", adjustmentID, accountCodeCOGS)
		if consumedPortion > 0 {
			if err := s.insertEntryIfMissing(companyID, ref, cogsID, adjustmentDate, round2(consumedPortion), 0, "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
				return err
			}
		} else {
			if err := s.insertEntryIfMissing(companyID, ref, cogsID, adjustmentDate, 0, round2(-consumedPortion), "purchase_cost_adjustment", adjustmentID, nil, nil, userID); err != nil {
				return err
			}
		}
	}
	return nil
}

// RecordSaleReturn posts a credit-note style reversal for a completed sale return.
// Debit: Sales revenue + tax payable + inventory
// Credit: Accounts receivable + cost of goods sold reversal
func (s *LedgerService) RecordSaleReturn(companyID, returnID, userID int) error {
	totalAmount, taxAmount, cogsAmount, returnDate, err := s.saleReturnAmounts(companyID, returnID)
	if err != nil {
		return err
	}
	if totalAmount <= 0 {
		return nil
	}
	netRevenue := totalAmount - taxAmount
	if netRevenue < 0 {
		netRevenue = 0
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
	inventoryID, err := s.ensureDefaultAccountID(companyID, accountCodeInventory)
	if err != nil {
		return err
	}
	cogsID, err := s.ensureDefaultAccountID(companyID, accountCodeCOGS)
	if err != nil {
		return err
	}

	if netRevenue > 0 {
		ref := fmt.Sprintf("sale_return:%d:%s", returnID, accountCodeSalesRevenue)
		if err := s.insertEntryIfMissing(companyID, ref, salesID, returnDate, netRevenue, 0, "sale_return", returnID, nil, nil, userID); err != nil {
			return err
		}
	}
	if taxAmount > 0 {
		ref := fmt.Sprintf("sale_return:%d:%s", returnID, accountCodeTaxPayable)
		if err := s.insertEntryIfMissing(companyID, ref, taxPayableID, returnDate, taxAmount, 0, "sale_return", returnID, nil, nil, userID); err != nil {
			return err
		}
	}
	ref := fmt.Sprintf("sale_return:%d:%s", returnID, accountCodeAR)
	if err := s.insertEntryIfMissing(companyID, ref, arID, returnDate, 0, totalAmount, "sale_return", returnID, nil, nil, userID); err != nil {
		return err
	}
	if cogsAmount > 0 {
		ref = fmt.Sprintf("sale_return:%d:%s", returnID, accountCodeInventory)
		if err := s.insertEntryIfMissing(companyID, ref, inventoryID, returnDate, cogsAmount, 0, "sale_return", returnID, nil, nil, userID); err != nil {
			return err
		}
		ref = fmt.Sprintf("sale_return:%d:%s", returnID, accountCodeCOGS)
		if err := s.insertEntryIfMissing(companyID, ref, cogsID, returnDate, 0, cogsAmount, "sale_return", returnID, nil, nil, userID); err != nil {
			return err
		}
	}
	return nil
}

// RecordVoucher posts ledger lines for a voucher using voucher_lines.
func (s *LedgerService) RecordVoucher(companyID, voucherID, userID int) error {
	var vType string
	var vDate time.Time
	var reference sql.NullString
	var description sql.NullString
	if err := s.db.QueryRow(`
		SELECT v.type, v.date, v.reference, v.description
		FROM vouchers v
		WHERE v.voucher_id = $1 AND v.company_id = $2 AND v.is_deleted = FALSE
	`, voucherID, companyID).Scan(&vType, &vDate, &reference, &description); err != nil {
		return fmt.Errorf("failed to load voucher for ledger posting: %w", err)
	}

	var desc *string
	if description.Valid && description.String != "" {
		desc = &description.String
	} else if reference.Valid && reference.String != "" {
		desc = &reference.String
	}

	rows, err := s.db.Query(`
		SELECT line_no, account_id, debit, credit, description
		FROM voucher_lines
		WHERE company_id = $1 AND voucher_id = $2
		ORDER BY line_no
	`, companyID, voucherID)
	if err != nil {
		return fmt.Errorf("failed to load voucher lines for ledger posting: %w", err)
	}
	defer rows.Close()

	hasRows := false
	for rows.Next() {
		hasRows = true
		var lineNo int
		var accountID int
		var debit float64
		var credit float64
		var lineDescription sql.NullString
		if err := rows.Scan(&lineNo, &accountID, &debit, &credit, &lineDescription); err != nil {
			return fmt.Errorf("failed to scan voucher line for ledger posting: %w", err)
		}
		effectiveDesc := desc
		if lineDescription.Valid && strings.TrimSpace(lineDescription.String) != "" {
			effectiveDesc = &lineDescription.String
		}
		ref := fmt.Sprintf("voucher:%d:line:%d", voucherID, lineNo)
		if err := s.insertEntryIfMissing(companyID, ref, accountID, vDate, debit, credit, "voucher", voucherID, effectiveDesc, &voucherID, userID); err != nil {
			return err
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("failed to iterate voucher lines: %w", err)
	}
	if !hasRows && vType == "journal" {
		return fmt.Errorf("journal voucher has no lines to post")
	}
	return nil
}

func (s *LedgerService) RecordAssetCapitalization(companyID, assetEntryID, userID int) error {
	var amount float64
	var acquisitionDate time.Time
	var assetTag string
	var itemName string
	var sourceMode string
	var categoryAccountID sql.NullInt64
	var offsetAccountID sql.NullInt64

	err := s.db.QueryRow(`
		SELECT
			ae.total_value,
			ae.acquisition_date,
			ae.asset_tag,
			ae.item_name,
			ae.source_mode,
			ac.ledger_account_id,
			ae.offset_account_id
		FROM asset_register_entries ae
		LEFT JOIN asset_categories ac ON ac.category_id = ae.category_id
		WHERE ae.asset_entry_id = $1 AND ae.company_id = $2
	`, assetEntryID, companyID).Scan(
		&amount,
		&acquisitionDate,
		&assetTag,
		&itemName,
		&sourceMode,
		&categoryAccountID,
		&offsetAccountID,
	)
	if err != nil {
		return fmt.Errorf("failed to load asset entry for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	debitAccountID := 0
	if categoryAccountID.Valid && categoryAccountID.Int64 > 0 {
		debitAccountID = int(categoryAccountID.Int64)
	} else {
		debitAccountID, err = s.ensureDefaultAccountID(companyID, accountCodeFixedAssets)
		if err != nil {
			return err
		}
	}

	creditAccountID := 0
	if sourceMode == "STOCK" {
		creditAccountID, err = s.ensureDefaultAccountID(companyID, accountCodeInventory)
		if err != nil {
			return err
		}
	} else if offsetAccountID.Valid && offsetAccountID.Int64 > 0 {
		creditAccountID = int(offsetAccountID.Int64)
	} else {
		return fmt.Errorf("offset account is required for direct asset entries")
	}

	desc := fmt.Sprintf("Asset capitalization %s - %s", assetTag, itemName)
	ref1 := fmt.Sprintf("asset:%d:debit:%d", assetEntryID, debitAccountID)
	if err := s.insertEntryIfMissing(companyID, ref1, debitAccountID, acquisitionDate, amount, 0, "asset", assetEntryID, &desc, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("asset:%d:credit:%d", assetEntryID, creditAccountID)
	if err := s.insertEntryIfMissing(companyID, ref2, creditAccountID, acquisitionDate, 0, amount, "asset", assetEntryID, &desc, nil, userID); err != nil {
		return err
	}
	return nil
}

func (s *LedgerService) RecordConsumableUsage(companyID, consumptionID, userID int) error {
	var amount float64
	var consumedAt time.Time
	var itemName string
	var entryNumber string
	var sourceMode string
	var categoryAccountID sql.NullInt64
	var offsetAccountID sql.NullInt64

	err := s.db.QueryRow(`
		SELECT
			ce.total_cost,
			ce.consumed_at,
			ce.item_name,
			ce.entry_number,
			ce.source_mode,
			cc.ledger_account_id,
			ce.offset_account_id
		FROM consumable_entries ce
		LEFT JOIN consumable_categories cc ON cc.category_id = ce.category_id
		WHERE ce.consumption_id = $1 AND ce.company_id = $2
	`, consumptionID, companyID).Scan(
		&amount,
		&consumedAt,
		&itemName,
		&entryNumber,
		&sourceMode,
		&categoryAccountID,
		&offsetAccountID,
	)
	if err != nil {
		return fmt.Errorf("failed to load consumable entry for ledger posting: %w", err)
	}
	if amount <= 0 {
		return nil
	}

	debitAccountID := 0
	if categoryAccountID.Valid && categoryAccountID.Int64 > 0 {
		debitAccountID = int(categoryAccountID.Int64)
	} else {
		debitAccountID, err = s.ensureDefaultAccountID(companyID, accountCodeConsumables)
		if err != nil {
			return err
		}
	}

	creditAccountID := 0
	if sourceMode == "STOCK" {
		creditAccountID, err = s.ensureDefaultAccountID(companyID, accountCodeInventory)
		if err != nil {
			return err
		}
	} else if offsetAccountID.Valid && offsetAccountID.Int64 > 0 {
		creditAccountID = int(offsetAccountID.Int64)
	} else {
		return fmt.Errorf("offset account is required for direct consumable entries")
	}

	desc := fmt.Sprintf("Consumable usage %s - %s", entryNumber, itemName)
	ref1 := fmt.Sprintf("consumable:%d:debit:%d", consumptionID, debitAccountID)
	if err := s.insertEntryIfMissing(companyID, ref1, debitAccountID, consumedAt, amount, 0, "consumable", consumptionID, &desc, nil, userID); err != nil {
		return err
	}
	ref2 := fmt.Sprintf("consumable:%d:credit:%d", consumptionID, creditAccountID)
	if err := s.insertEntryIfMissing(companyID, ref2, creditAccountID, consumedAt, 0, amount, "consumable", consumptionID, &desc, nil, userID); err != nil {
		return err
	}
	return nil
}
