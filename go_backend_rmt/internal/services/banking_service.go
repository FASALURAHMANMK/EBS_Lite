package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/lib/pq"
)

type BankingService struct {
	db             *sql.DB
	voucherService *VoucherService
}

func NewBankingService() *BankingService {
	return &BankingService{
		db:             database.GetDB(),
		voucherService: NewVoucherService(),
	}
}

func (s *BankingService) ListBankAccounts(companyID int) ([]models.BankAccount, error) {
	rows, err := s.db.Query(`
		SELECT
			ba.bank_account_id,
			ba.company_id,
			ba.ledger_account_id,
			coa.account_code,
			coa.name,
			ba.default_location_id,
			ba.account_name,
			ba.bank_name,
			ba.account_number_masked,
			ba.branch_name,
			ba.currency_code,
			ba.statement_import_hint,
			ba.opening_balance::float8,
			ba.is_active,
			COALESCE(SUM(CASE WHEN bse.status = 'UNMATCHED' AND bse.is_deleted = FALSE THEN 1 ELSE 0 END), 0)::int AS unmatched_entries,
			COALESCE(SUM(CASE WHEN bse.status = 'REVIEW' AND bse.is_deleted = FALSE THEN 1 ELSE 0 END), 0)::int AS review_entries,
			MAX(CASE WHEN bse.is_deleted = FALSE THEN bse.entry_date END) AS last_statement_date
		FROM bank_accounts ba
		JOIN chart_of_accounts coa ON coa.account_id = ba.ledger_account_id
		LEFT JOIN bank_statement_entries bse ON bse.bank_account_id = ba.bank_account_id
		WHERE ba.company_id = $1
		GROUP BY ba.bank_account_id, ba.company_id, ba.ledger_account_id, coa.account_code, coa.name,
		         ba.default_location_id, ba.account_name, ba.bank_name, ba.account_number_masked,
		         ba.branch_name, ba.currency_code, ba.statement_import_hint, ba.opening_balance, ba.is_active
		ORDER BY ba.bank_name, ba.account_name
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to list bank accounts: %w", err)
	}
	defer rows.Close()

	items := make([]models.BankAccount, 0)
	for rows.Next() {
		var item models.BankAccount
		if err := rows.Scan(
			&item.BankAccountID,
			&item.CompanyID,
			&item.LedgerAccountID,
			&item.LedgerAccountCode,
			&item.LedgerAccountName,
			&item.DefaultLocationID,
			&item.AccountName,
			&item.BankName,
			&item.AccountNumberMasked,
			&item.BranchName,
			&item.CurrencyCode,
			&item.StatementImportHint,
			&item.OpeningBalance,
			&item.IsActive,
			&item.UnmatchedEntries,
			&item.ReviewEntries,
			&item.LastStatementDate,
		); err != nil {
			return nil, fmt.Errorf("failed to scan bank account: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *BankingService) CreateBankAccount(companyID, userID int, req *models.CreateBankAccountRequest) (*models.BankAccount, error) {
	if err := (&AccountingAdminService{db: s.db}).ensureAccountBelongsToCompany(companyID, &req.LedgerAccountID); err != nil {
		return nil, err
	}
	openingBalance := 0.0
	if req.OpeningBalance != nil {
		openingBalance = *req.OpeningBalance
	}
	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}

	var id int
	if err := s.db.QueryRow(`
		INSERT INTO bank_accounts (
			company_id, ledger_account_id, default_location_id, account_name, bank_name,
			account_number_masked, branch_name, currency_code, statement_import_hint,
			opening_balance, is_active, created_by, updated_by
		)
		VALUES ($1,$2,$3,$4,$5,NULLIF($6,''),NULLIF($7,''),NULLIF($8,''),NULLIF($9,''),$10,$11,$12,$12)
		RETURNING bank_account_id
	`,
		companyID,
		req.LedgerAccountID,
		req.DefaultLocationID,
		strings.TrimSpace(req.AccountName),
		strings.TrimSpace(req.BankName),
		trimOrEmpty(req.AccountNumberMasked),
		trimOrEmpty(req.BranchName),
		trimOrEmpty(req.CurrencyCode),
		trimOrEmpty(req.StatementImportHint),
		openingBalance,
		active,
		userID,
	).Scan(&id); err != nil {
		return nil, fmt.Errorf("failed to create bank account: %w", err)
	}
	return s.GetBankAccount(companyID, id)
}

func (s *BankingService) UpdateBankAccount(companyID, bankAccountID, userID int, req *models.UpdateBankAccountRequest) (*models.BankAccount, error) {
	if err := (&AccountingAdminService{db: s.db}).ensureAccountBelongsToCompany(companyID, req.LedgerAccountID); err != nil {
		return nil, err
	}
	if _, err := s.db.Exec(`
		UPDATE bank_accounts
		SET ledger_account_id = COALESCE($1, ledger_account_id),
		    default_location_id = COALESCE($2, default_location_id),
		    account_name = COALESCE(NULLIF($3, ''), account_name),
		    bank_name = COALESCE(NULLIF($4, ''), bank_name),
		    account_number_masked = CASE WHEN $5::text IS NULL THEN account_number_masked ELSE NULLIF($5, '') END,
		    branch_name = CASE WHEN $6::text IS NULL THEN branch_name ELSE NULLIF($6, '') END,
		    currency_code = CASE WHEN $7::text IS NULL THEN currency_code ELSE NULLIF($7, '') END,
		    statement_import_hint = CASE WHEN $8::text IS NULL THEN statement_import_hint ELSE NULLIF($8, '') END,
		    opening_balance = COALESCE($9, opening_balance),
		    is_active = COALESCE($10, is_active),
		    updated_by = $11,
		    updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $12 AND bank_account_id = $13
	`,
		req.LedgerAccountID,
		req.DefaultLocationID,
		trimPointer(req.AccountName),
		trimPointer(req.BankName),
		trimPointer(req.AccountNumberMasked),
		trimPointer(req.BranchName),
		trimPointer(req.CurrencyCode),
		trimPointer(req.StatementImportHint),
		req.OpeningBalance,
		req.IsActive,
		userID,
		companyID,
		bankAccountID,
	); err != nil {
		return nil, fmt.Errorf("failed to update bank account: %w", err)
	}
	return s.GetBankAccount(companyID, bankAccountID)
}

func (s *BankingService) GetBankAccount(companyID, bankAccountID int) (*models.BankAccount, error) {
	items, err := s.ListBankAccounts(companyID)
	if err != nil {
		return nil, err
	}
	for _, item := range items {
		if item.BankAccountID == bankAccountID {
			return &item, nil
		}
	}
	return nil, fmt.Errorf("bank account not found")
}

func (s *BankingService) ListStatementEntries(companyID, bankAccountID int, filters map[string]string, limit int) ([]models.BankStatementEntry, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	query := `
		SELECT
			bse.statement_entry_id,
			bse.company_id,
			bse.bank_account_id,
			bse.entry_date,
			bse.value_date,
			bse.description,
			bse.reference,
			bse.external_ref,
			bse.source_type,
			bse.deposit_amount::float8,
			bse.withdrawal_amount::float8,
			bse.running_balance::float8,
			bse.status,
			bse.review_reason,
			COALESCE(SUM(brm.matched_amount), 0)::float8 AS matched_amount,
			bse.created_at
		FROM bank_statement_entries bse
		LEFT JOIN bank_reconciliation_matches brm
		  ON brm.statement_entry_id = bse.statement_entry_id
		 AND brm.is_deleted = FALSE
		WHERE bse.company_id = $1
		  AND bse.bank_account_id = $2
		  AND bse.is_deleted = FALSE
	`
	args := []interface{}{companyID, bankAccountID}
	argPos := 2
	if v := strings.TrimSpace(filters["status"]); v != "" {
		argPos++
		query += fmt.Sprintf(" AND bse.status = $%d", argPos)
		args = append(args, strings.ToUpper(v))
	}
	if v := strings.TrimSpace(filters["date_from"]); v != "" {
		argPos++
		query += fmt.Sprintf(" AND bse.entry_date >= $%d", argPos)
		args = append(args, v)
	}
	if v := strings.TrimSpace(filters["date_to"]); v != "" {
		argPos++
		query += fmt.Sprintf(" AND bse.entry_date <= $%d", argPos)
		args = append(args, v)
	}
	query += `
		GROUP BY bse.statement_entry_id, bse.company_id, bse.bank_account_id, bse.entry_date, bse.value_date,
		         bse.description, bse.reference, bse.external_ref, bse.source_type, bse.deposit_amount,
		         bse.withdrawal_amount, bse.running_balance, bse.status, bse.review_reason, bse.created_at
		ORDER BY bse.entry_date DESC, bse.statement_entry_id DESC
	`
	argPos++
	query += fmt.Sprintf(" LIMIT $%d", argPos)
	args = append(args, limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list statement entries: %w", err)
	}
	defer rows.Close()

	items := make([]models.BankStatementEntry, 0)
	statementIDs := make([]int, 0)
	for rows.Next() {
		var item models.BankStatementEntry
		if err := rows.Scan(
			&item.StatementEntryID,
			&item.CompanyID,
			&item.BankAccountID,
			&item.EntryDate,
			&item.ValueDate,
			&item.Description,
			&item.Reference,
			&item.ExternalRef,
			&item.SourceType,
			&item.DepositAmount,
			&item.WithdrawalAmount,
			&item.RunningBalance,
			&item.Status,
			&item.ReviewReason,
			&item.MatchedAmount,
			&item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan statement entry: %w", err)
		}
		item.AvailableAmount = math.Max(statementEntryAmount(item)-item.MatchedAmount, 0)
		items = append(items, item)
		statementIDs = append(statementIDs, item.StatementEntryID)
	}

	matchMap, err := s.loadMatchesForStatements(companyID, bankAccountID, statementIDs)
	if err != nil {
		return nil, err
	}
	for idx := range items {
		items[idx].Matches = matchMap[items[idx].StatementEntryID]
	}
	return items, nil
}

func (s *BankingService) CreateStatementEntry(companyID, bankAccountID, userID int, req *models.CreateBankStatementEntryRequest) (*models.BankStatementEntry, error) {
	account, err := s.GetBankAccount(companyID, bankAccountID)
	if err != nil {
		return nil, err
	}
	_ = account
	entryDate, err := parseAccountingDate(req.EntryDate)
	if err != nil {
		return nil, err
	}
	if err := (&AccountingAdminService{db: s.db}).EnsurePeriodOpen(companyID, entryDate); err != nil {
		return nil, err
	}
	if req.DepositAmount <= 0 && req.WithdrawalAmount <= 0 {
		return nil, fmt.Errorf("either deposit_amount or withdrawal_amount is required")
	}
	if req.DepositAmount > 0 && req.WithdrawalAmount > 0 {
		return nil, fmt.Errorf("statement entry cannot have both deposit and withdrawal amounts")
	}
	status := "UNMATCHED"
	if req.ReviewReason != nil && strings.TrimSpace(*req.ReviewReason) != "" {
		status = "REVIEW"
	}
	sourceType := "MANUAL"
	if req.SourceType != nil && strings.TrimSpace(*req.SourceType) != "" {
		sourceType = strings.ToUpper(strings.TrimSpace(*req.SourceType))
	}

	idemKey := trimOrEmpty(req.IdempotencyKey)
	if idemKey != "" {
		var existingID int
		err := s.db.QueryRow(`
			SELECT statement_entry_id
			FROM bank_statement_entries
			WHERE company_id = $1 AND bank_account_id = $2 AND idempotency_key = $3 AND is_deleted = FALSE
			LIMIT 1
		`, companyID, bankAccountID, idemKey).Scan(&existingID)
		if err == nil {
			return s.GetStatementEntry(companyID, bankAccountID, existingID)
		}
		if err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to lookup statement idempotency key: %w", err)
		}
	}

	var valueDate *time.Time
	if req.ValueDate != nil && strings.TrimSpace(*req.ValueDate) != "" {
		parsed, err := parseAccountingDate(*req.ValueDate)
		if err != nil {
			return nil, err
		}
		valueDate = &parsed
	}

	var id int
	if err := s.db.QueryRow(`
		INSERT INTO bank_statement_entries (
			company_id, bank_account_id, entry_date, value_date, description, reference, external_ref,
			source_type, deposit_amount, withdrawal_amount, running_balance, status, review_reason,
			idempotency_key, created_by, updated_by
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NULLIF($14,''),$15,$15)
		RETURNING statement_entry_id
	`,
		companyID,
		bankAccountID,
		entryDate,
		valueDate,
		req.Description,
		req.Reference,
		req.ExternalRef,
		sourceType,
		req.DepositAmount,
		req.WithdrawalAmount,
		req.RunningBalance,
		status,
		req.ReviewReason,
		idemKey,
		userID,
	).Scan(&id); err != nil {
		return nil, fmt.Errorf("failed to create statement entry: %w", err)
	}
	return s.GetStatementEntry(companyID, bankAccountID, id)
}

func (s *BankingService) MatchStatement(companyID, bankAccountID, userID int, req *models.MatchBankStatementRequest) (*models.BankStatementEntry, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start bank reconciliation transaction: %w", err)
	}
	defer tx.Rollback()

	statement, ledgerAmount, err := s.loadStatementAndLedgerForMatchTx(tx, companyID, bankAccountID, req.StatementEntryID, req.LedgerEntryID)
	if err != nil {
		return nil, err
	}
	if req.MatchedAmount > statement.AvailableAmount+0.01 {
		return nil, fmt.Errorf("matched amount exceeds available statement amount")
	}
	ledgerAvailable, err := s.availableLedgerAmountTx(tx, companyID, req.LedgerEntryID, ledgerAmount)
	if err != nil {
		return nil, err
	}
	if req.MatchedAmount > ledgerAvailable+0.01 {
		return nil, fmt.Errorf("matched amount exceeds available ledger amount")
	}
	if _, err := tx.Exec(`
		INSERT INTO bank_reconciliation_matches (
			company_id, bank_account_id, statement_entry_id, ledger_entry_id, matched_amount, match_kind, notes, created_by
		)
		VALUES ($1,$2,$3,$4,$5,'MANUAL',$6,$7)
	`, companyID, bankAccountID, req.StatementEntryID, req.LedgerEntryID, req.MatchedAmount, req.Notes, userID); err != nil {
		return nil, fmt.Errorf("failed to create reconciliation match: %w", err)
	}
	if err := s.refreshStatementStatusTx(tx, companyID, req.StatementEntryID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit reconciliation match: %w", err)
	}
	return s.GetStatementEntry(companyID, bankAccountID, req.StatementEntryID)
}

func (s *BankingService) UnmatchStatement(companyID, bankAccountID int, req *models.UnmatchBankStatementRequest) (*models.BankStatementEntry, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start unmatch transaction: %w", err)
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`
		UPDATE bank_reconciliation_matches
		SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $1 AND bank_account_id = $2 AND statement_entry_id = $3 AND match_id = $4
	`, companyID, bankAccountID, req.StatementEntryID, req.MatchID); err != nil {
		return nil, fmt.Errorf("failed to remove reconciliation match: %w", err)
	}
	if err := s.refreshStatementStatusTx(tx, companyID, req.StatementEntryID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit reconciliation unmatch: %w", err)
	}
	return s.GetStatementEntry(companyID, bankAccountID, req.StatementEntryID)
}

func (s *BankingService) MarkStatementReview(companyID, bankAccountID int, req *models.ReviewBankStatementRequest) (*models.BankStatementEntry, error) {
	status := "REVIEW"
	reason := req.ReviewReason
	if reason == nil || strings.TrimSpace(*reason) == "" {
		status = "UNMATCHED"
		reason = nil
	}
	if _, err := s.db.Exec(`
		UPDATE bank_statement_entries
		SET status = $1, review_reason = $2, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $3 AND bank_account_id = $4 AND statement_entry_id = $5
	`, status, reason, companyID, bankAccountID, req.StatementEntryID); err != nil {
		return nil, fmt.Errorf("failed to update statement review status: %w", err)
	}
	return s.GetStatementEntry(companyID, bankAccountID, req.StatementEntryID)
}

func (s *BankingService) CreateAdjustment(companyID, bankAccountID, userID int, req *models.CreateBankAdjustmentRequest) (*models.BankStatementEntry, error) {
	statement, err := s.GetStatementEntry(companyID, bankAccountID, req.StatementEntryID)
	if err != nil {
		return nil, err
	}
	amount := statement.AvailableAmount
	if amount <= 0 {
		return nil, fmt.Errorf("statement entry is already fully matched")
	}

	account, err := s.GetBankAccount(companyID, bankAccountID)
	if err != nil {
		return nil, err
	}

	lines := req.Lines
	if len(lines) == 0 {
		lines = []models.CreateVoucherLineRequest{
			{AccountID: account.LedgerAccountID},
			{AccountID: req.OffsetAccountID},
		}
		if statement.DepositAmount > 0 {
			lines[0].Debit = amount
			lines[1].Credit = amount
		} else {
			lines[0].Credit = amount
			lines[1].Debit = amount
		}
	}

	voucherReq := &models.CreateVoucherRequest{
		Reference:      reqReferenceOrFallback(req.Reference, fmt.Sprintf("BANK-%d-%d", bankAccountID, statement.StatementEntryID)),
		Description:    req.Description,
		Date:           req.Date,
		Lines:          lines,
		IdempotencyKey: req.IdempotencyKey,
	}
	voucherID, err := s.voucherService.CreateVoucher(companyID, userID, "journal", voucherReq)
	if err != nil {
		return nil, err
	}

	var ledgerEntryID int
	if err := s.db.QueryRow(`
		SELECT entry_id
		FROM ledger_entries
		WHERE company_id = $1 AND voucher_id = $2 AND account_id = $3
		ORDER BY entry_id DESC
		LIMIT 1
	`, companyID, voucherID, account.LedgerAccountID).Scan(&ledgerEntryID); err != nil {
		return nil, fmt.Errorf("failed to resolve adjustment ledger entry: %w", err)
	}

	_, err = s.MatchStatement(companyID, bankAccountID, userID, &models.MatchBankStatementRequest{
		StatementEntryID: req.StatementEntryID,
		LedgerEntryID:    ledgerEntryID,
		MatchedAmount:    amount,
		Notes:            req.Description,
	})
	if err != nil {
		return nil, err
	}
	return s.GetStatementEntry(companyID, bankAccountID, req.StatementEntryID)
}

func (s *BankingService) GetStatementEntry(companyID, bankAccountID, statementEntryID int) (*models.BankStatementEntry, error) {
	items, err := s.ListStatementEntries(companyID, bankAccountID, map[string]string{}, 500)
	if err != nil {
		return nil, err
	}
	for _, item := range items {
		if item.StatementEntryID == statementEntryID {
			return &item, nil
		}
	}
	return nil, fmt.Errorf("statement entry not found")
}

func (s *BankingService) loadStatementAndLedgerForMatchTx(
	tx *sql.Tx,
	companyID, bankAccountID, statementEntryID, ledgerEntryID int,
) (*models.BankStatementEntry, float64, error) {
	var ledgerAccountID int
	if err := tx.QueryRow(`
		SELECT ledger_account_id
		FROM bank_accounts
		WHERE company_id = $1 AND bank_account_id = $2
	`, companyID, bankAccountID).Scan(&ledgerAccountID); err != nil {
		return nil, 0, fmt.Errorf("failed to load bank account ledger account: %w", err)
	}

	statement, err := s.GetStatementEntry(companyID, bankAccountID, statementEntryID)
	if err != nil {
		return nil, 0, err
	}

	var debit float64
	var credit float64
	if err := tx.QueryRow(`
		SELECT debit::float8, credit::float8
		FROM ledger_entries
		WHERE company_id = $1 AND entry_id = $2 AND account_id = $3
	`, companyID, ledgerEntryID, ledgerAccountID).Scan(&debit, &credit); err != nil {
		if err == sql.ErrNoRows {
			return nil, 0, fmt.Errorf("ledger entry does not belong to the bank account ledger")
		}
		return nil, 0, fmt.Errorf("failed to load ledger entry: %w", err)
	}
	ledgerAmount := math.Abs(debit - credit)
	if ledgerAmount <= 0 {
		return nil, 0, fmt.Errorf("ledger entry amount is not reconcilable")
	}
	statementAmount := statementEntryAmount(*statement)
	if statement.DepositAmount > 0 && debit <= credit {
		return nil, 0, fmt.Errorf("deposit statement entries can only match debit bank ledger entries")
	}
	if statement.WithdrawalAmount > 0 && credit <= debit {
		return nil, 0, fmt.Errorf("withdrawal statement entries can only match credit bank ledger entries")
	}
	if statementAmount <= 0 {
		return nil, 0, fmt.Errorf("statement entry amount is not reconcilable")
	}
	return statement, ledgerAmount, nil
}

func (s *BankingService) availableLedgerAmountTx(tx *sql.Tx, companyID, ledgerEntryID int, ledgerAmount float64) (float64, error) {
	var matched float64
	if err := tx.QueryRow(`
		SELECT COALESCE(SUM(matched_amount), 0)::float8
		FROM bank_reconciliation_matches
		WHERE company_id = $1 AND ledger_entry_id = $2 AND is_deleted = FALSE
	`, companyID, ledgerEntryID).Scan(&matched); err != nil {
		return 0, fmt.Errorf("failed to compute available ledger amount: %w", err)
	}
	return math.Max(ledgerAmount-matched, 0), nil
}

func (s *BankingService) refreshStatementStatusTx(tx *sql.Tx, companyID, statementEntryID int) error {
	var deposit float64
	var withdrawal float64
	var reviewReason sql.NullString
	if err := tx.QueryRow(`
		SELECT deposit_amount::float8, withdrawal_amount::float8, review_reason
		FROM bank_statement_entries
		WHERE company_id = $1 AND statement_entry_id = $2 AND is_deleted = FALSE
	`, companyID, statementEntryID).Scan(&deposit, &withdrawal, &reviewReason); err != nil {
		return fmt.Errorf("failed to reload statement entry status: %w", err)
	}

	var matched float64
	if err := tx.QueryRow(`
		SELECT COALESCE(SUM(matched_amount), 0)::float8
		FROM bank_reconciliation_matches
		WHERE company_id = $1 AND statement_entry_id = $2 AND is_deleted = FALSE
	`, companyID, statementEntryID).Scan(&matched); err != nil {
		return fmt.Errorf("failed to compute statement matched amount: %w", err)
	}

	status := "UNMATCHED"
	amount := math.Abs(deposit - withdrawal)
	if reviewReason.Valid && strings.TrimSpace(reviewReason.String) != "" {
		status = "REVIEW"
	} else if matched >= amount-0.01 {
		status = "MATCHED"
	} else if matched > 0 {
		status = "REVIEW"
	}

	if _, err := tx.Exec(`
		UPDATE bank_statement_entries
		SET status = $1, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $2 AND statement_entry_id = $3
	`, status, companyID, statementEntryID); err != nil {
		return fmt.Errorf("failed to refresh statement status: %w", err)
	}
	return nil
}

func (s *BankingService) loadMatchesForStatements(companyID, bankAccountID int, statementIDs []int) (map[int][]models.BankReconciliationMatch, error) {
	result := map[int][]models.BankReconciliationMatch{}
	if len(statementIDs) == 0 {
		return result, nil
	}
	rows, err := s.db.Query(`
		SELECT
			brm.match_id,
			brm.company_id,
			brm.bank_account_id,
			brm.statement_entry_id,
			brm.ledger_entry_id,
			brm.matched_amount::float8,
			brm.match_kind,
			brm.notes,
			brm.created_by,
			brm.created_at,
			le.date,
			le.reference,
			le.description
		FROM bank_reconciliation_matches brm
		JOIN ledger_entries le ON le.entry_id = brm.ledger_entry_id
		WHERE brm.company_id = $1
		  AND brm.bank_account_id = $2
		  AND brm.statement_entry_id = ANY($3)
		  AND brm.is_deleted = FALSE
		ORDER BY brm.created_at DESC, brm.match_id DESC
	`, companyID, bankAccountID, pq.Array(statementIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to load reconciliation matches: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item models.BankReconciliationMatch
		if err := rows.Scan(
			&item.MatchID,
			&item.CompanyID,
			&item.BankAccountID,
			&item.StatementEntryID,
			&item.LedgerEntryID,
			&item.MatchedAmount,
			&item.MatchKind,
			&item.Notes,
			&item.CreatedBy,
			&item.CreatedAt,
			&item.LedgerDate,
			&item.LedgerReference,
			&item.LedgerDescription,
		); err != nil {
			return nil, fmt.Errorf("failed to scan reconciliation match: %w", err)
		}
		result[item.StatementEntryID] = append(result[item.StatementEntryID], item)
	}
	return result, nil
}

func statementEntryAmount(item models.BankStatementEntry) float64 {
	return math.Abs(item.DepositAmount - item.WithdrawalAmount)
}

func trimOrEmpty(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func reqReferenceOrFallback(value *string, fallback string) string {
	if value == nil || strings.TrimSpace(*value) == "" {
		return fallback
	}
	return strings.TrimSpace(*value)
}
