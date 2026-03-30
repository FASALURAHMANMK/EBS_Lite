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

type VoucherService struct {
	db *sql.DB
}

func NewVoucherService() *VoucherService {
	return &VoucherService{db: database.GetDB()}
}

func (s *VoucherService) CreateVoucher(companyID, userID int, vType string, req *models.CreateVoucherRequest) (int, error) {
	normalizedType := strings.ToLower(strings.TrimSpace(vType))
	if normalizedType != "payment" && normalizedType != "receipt" && normalizedType != "journal" {
		return 0, fmt.Errorf("invalid voucher type")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to start voucher transaction: %w", err)
	}
	defer tx.Rollback()

	voucherID, err := s.createVoucherTx(tx, companyID, userID, normalizedType, req)
	if err != nil {
		return 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit voucher: %w", err)
	}
	return voucherID, nil
}

func (s *VoucherService) createVoucherTx(tx *sql.Tx, companyID, userID int, vType string, req *models.CreateVoucherRequest) (int, error) {
	if strings.TrimSpace(req.Reference) == "" {
		return 0, fmt.Errorf("reference is required")
	}

	var voucherDate time.Time
	if req.Date != nil && strings.TrimSpace(*req.Date) != "" {
		parsed, err := parseAccountingDate(*req.Date)
		if err != nil {
			return 0, err
		}
		voucherDate = parsed
	} else {
		voucherDate = time.Now().UTC()
	}
	if err := (&AccountingAdminService{db: s.db}).EnsurePeriodOpen(companyID, voucherDate); err != nil {
		return 0, err
	}

	idemKey := ""
	if req.IdempotencyKey != nil {
		idemKey = strings.TrimSpace(*req.IdempotencyKey)
	}
	if idemKey != "" {
		var existingID int
		err := tx.QueryRow(`
			SELECT voucher_id
			FROM vouchers
			WHERE company_id = $1
			  AND idempotency_key = $2
			  AND is_deleted = FALSE
			LIMIT 1
		`, companyID, idemKey).Scan(&existingID)
		if err == nil {
			return existingID, nil
		}
		if err != nil && err != sql.ErrNoRows {
			return 0, fmt.Errorf("failed to lookup voucher idempotency key: %w", err)
		}
	}

	lines, headerAccountID, settlementAccountID, bankAccountID, amount, err := s.buildVoucherLinesTx(tx, companyID, vType, req)
	if err != nil {
		return 0, err
	}

	var voucherID int
	err = tx.QueryRow(`
		INSERT INTO vouchers (
			company_id, type, date, amount, account_id, settlement_account_id, bank_account_id,
			reference, description, created_by, updated_by, idempotency_key
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10,NULLIF($11,''))
		RETURNING voucher_id
	`,
		companyID,
		vType,
		voucherDate,
		amount,
		headerAccountID,
		settlementAccountID,
		bankAccountID,
		strings.TrimSpace(req.Reference),
		req.Description,
		userID,
		idemKey,
	).Scan(&voucherID)
	if err != nil {
		if idemKey != "" && isUniqueViolation(err) {
			var existingID int
			if lookupErr := tx.QueryRow(`
				SELECT voucher_id
				FROM vouchers
				WHERE company_id = $1
				  AND idempotency_key = $2
				  AND is_deleted = FALSE
				LIMIT 1
			`, companyID, idemKey).Scan(&existingID); lookupErr == nil {
				return existingID, nil
			}
		}
		return 0, fmt.Errorf("failed to create voucher: %w", err)
	}

	for idx, line := range lines {
		if _, err := tx.Exec(`
			INSERT INTO voucher_lines (
				voucher_id, company_id, account_id, line_no, debit, credit, description, created_by, updated_by
			)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
		`, voucherID, companyID, line.AccountID, idx+1, line.Debit, line.Credit, line.Description, userID); err != nil {
			return 0, fmt.Errorf("failed to create voucher line: %w", err)
		}
	}

	if err := s.recordVoucherEntriesTx(tx, companyID, voucherID, voucherDate, lines, req.Description, userID); err != nil {
		return 0, err
	}
	return voucherID, nil
}

func (s *VoucherService) buildVoucherLinesTx(
	tx *sql.Tx,
	companyID int,
	vType string,
	req *models.CreateVoucherRequest,
) ([]models.CreateVoucherLineRequest, int, *int, *int, float64, error) {
	switch vType {
	case "payment", "receipt":
		if req.AccountID <= 0 {
			return nil, 0, nil, nil, 0, fmt.Errorf("account_id is required")
		}
		if req.Amount <= 0 {
			return nil, 0, nil, nil, 0, fmt.Errorf("amount must be greater than zero")
		}
		if err := s.ensureAccountInCompanyTx(tx, companyID, req.AccountID); err != nil {
			return nil, 0, nil, nil, 0, err
		}
		settlementAccountID, bankAccountID, err := s.resolveSettlementAccountTx(tx, companyID, req)
		if err != nil {
			return nil, 0, nil, nil, 0, err
		}
		if *settlementAccountID == req.AccountID {
			return nil, 0, nil, nil, 0, fmt.Errorf("settlement account must differ from account_id")
		}
		lines := []models.CreateVoucherLineRequest{
			{AccountID: req.AccountID},
			{AccountID: *settlementAccountID},
		}
		if vType == "payment" {
			lines[0].Debit = req.Amount
			lines[1].Credit = req.Amount
		} else {
			lines[0].Credit = req.Amount
			lines[1].Debit = req.Amount
		}
		return lines, req.AccountID, settlementAccountID, bankAccountID, req.Amount, nil
	case "journal":
		if len(req.Lines) < 2 {
			return nil, 0, nil, nil, 0, fmt.Errorf("journal vouchers require at least two lines")
		}
		debitTotal := 0.0
		creditTotal := 0.0
		for _, line := range req.Lines {
			if line.AccountID <= 0 {
				return nil, 0, nil, nil, 0, fmt.Errorf("each journal line requires account_id")
			}
			if err := s.ensureAccountInCompanyTx(tx, companyID, line.AccountID); err != nil {
				return nil, 0, nil, nil, 0, err
			}
			if (line.Debit > 0 && line.Credit > 0) || (line.Debit <= 0 && line.Credit <= 0) {
				return nil, 0, nil, nil, 0, fmt.Errorf("each journal line must have either debit or credit")
			}
			debitTotal += line.Debit
			creditTotal += line.Credit
		}
		if math.Abs(debitTotal-creditTotal) > 0.01 {
			return nil, 0, nil, nil, 0, fmt.Errorf("journal voucher lines must balance")
		}
		headerAccountID := req.Lines[0].AccountID
		amount := debitTotal
		lines := make([]models.CreateVoucherLineRequest, len(req.Lines))
		copy(lines, req.Lines)
		return lines, headerAccountID, nil, nil, amount, nil
	default:
		return nil, 0, nil, nil, 0, fmt.Errorf("invalid voucher type")
	}
}

func (s *VoucherService) ensureAccountInCompanyTx(tx *sql.Tx, companyID, accountID int) error {
	var exists bool
	if err := tx.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM chart_of_accounts
			WHERE company_id = $1 AND account_id = $2
		)
	`, companyID, accountID).Scan(&exists); err != nil {
		return fmt.Errorf("failed to validate account: %w", err)
	}
	if !exists {
		return fmt.Errorf("account not found")
	}
	return nil
}

func (s *VoucherService) resolveSettlementAccountTx(tx *sql.Tx, companyID int, req *models.CreateVoucherRequest) (*int, *int, error) {
	if req.BankAccountID != nil && *req.BankAccountID > 0 {
		var ledgerAccountID int
		if err := tx.QueryRow(`
			SELECT ledger_account_id
			FROM bank_accounts
			WHERE company_id = $1 AND bank_account_id = $2 AND is_active = TRUE
		`, companyID, *req.BankAccountID).Scan(&ledgerAccountID); err != nil {
			if err == sql.ErrNoRows {
				return nil, nil, fmt.Errorf("bank account not found")
			}
			return nil, nil, fmt.Errorf("failed to load bank account: %w", err)
		}
		return &ledgerAccountID, req.BankAccountID, nil
	}
	if req.SettlementAccountID != nil && *req.SettlementAccountID > 0 {
		if err := s.ensureAccountInCompanyTx(tx, companyID, *req.SettlementAccountID); err != nil {
			return nil, nil, err
		}
		return req.SettlementAccountID, nil, nil
	}
	var cashID int
	if err := tx.QueryRow(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`, companyID, accountCodeCash).Scan(&cashID); err != nil {
		return nil, nil, fmt.Errorf("failed to resolve cash settlement account: %w", err)
	}
	return &cashID, nil, nil
}

func (s *VoucherService) recordVoucherEntriesTx(
	tx *sql.Tx,
	companyID, voucherID int,
	voucherDate time.Time,
	lines []models.CreateVoucherLineRequest,
	description *string,
	userID int,
) error {
	for idx, line := range lines {
		ref := fmt.Sprintf("voucher:%d:line:%d", voucherID, idx+1)
		_, err := tx.Exec(`
			INSERT INTO ledger_entries (
				company_id, account_id, voucher_id, date, debit, credit, balance,
				transaction_type, transaction_id, description, reference,
				created_by, updated_by
			)
			SELECT $1,$2,$3,$4,$5,$6,0,'voucher',$3,$7,$8,$9,$9
			WHERE NOT EXISTS (
				SELECT 1 FROM ledger_entries WHERE company_id = $1 AND reference = $8
			)
		`, companyID, line.AccountID, voucherID, voucherDate, line.Debit, line.Credit, coalesceDescription(line.Description, description), ref, userID)
		if err != nil {
			return fmt.Errorf("failed to record voucher ledger entry: %w", err)
		}
	}
	return nil
}

func coalesceDescription(lineDescription, fallback *string) *string {
	if lineDescription != nil && strings.TrimSpace(*lineDescription) != "" {
		trimmed := strings.TrimSpace(*lineDescription)
		return &trimmed
	}
	if fallback != nil && strings.TrimSpace(*fallback) != "" {
		trimmed := strings.TrimSpace(*fallback)
		return &trimmed
	}
	return nil
}

// ListVouchers retrieves vouchers for a company with optional type and date filters.
// Supports pagination via page and pageSize parameters.
func (s *VoucherService) ListVouchers(companyID int, filters map[string]string, page, pageSize int) ([]models.Voucher, int, error) {
	baseQuery := `SELECT voucher_id, company_id, type, date, amount, account_id, settlement_account_id, bank_account_id, reference, description, sync_status, created_at, updated_at
                FROM vouchers WHERE company_id = $1 AND is_deleted = FALSE`
	countQuery := `SELECT COUNT(*) FROM vouchers WHERE company_id = $1 AND is_deleted = FALSE`

	args := []interface{}{companyID}
	countArgs := []interface{}{companyID}
	argPos := 1

	if v, ok := filters["type"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND type = $%d", argPos)
		countQuery += fmt.Sprintf(" AND type = $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}
	if v, ok := filters["date_from"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND date >= $%d", argPos)
		countQuery += fmt.Sprintf(" AND date >= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND date <= $%d", argPos)
		countQuery += fmt.Sprintf(" AND date <= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}

	var total int
	if err := s.db.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("failed to count vouchers: %w", err)
	}

	if pageSize <= 0 {
		pageSize = 20
	}
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * pageSize
	baseQuery += fmt.Sprintf(" ORDER BY date DESC, voucher_id DESC LIMIT $%d OFFSET $%d", argPos+1, argPos+2)
	args = append(args, pageSize, offset)

	rows, err := s.db.Query(baseQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list vouchers: %w", err)
	}
	defer rows.Close()

	var vouchers []models.Voucher
	for rows.Next() {
		var v models.Voucher
		if err := rows.Scan(&v.VoucherID, &v.CompanyID, &v.Type, &v.Date, &v.Amount, &v.AccountID, &v.SettlementAccountID, &v.BankAccountID, &v.Reference, &v.Description, &v.SyncStatus, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("failed to scan voucher: %w", err)
		}
		vouchers = append(vouchers, v)
	}

	return vouchers, total, nil
}

// GetVoucher retrieves a single voucher by ID for a company.
func (s *VoucherService) GetVoucher(companyID, voucherID int) (*models.Voucher, error) {
	query := `SELECT voucher_id, company_id, type, date, amount, account_id, settlement_account_id, bank_account_id, reference, description, sync_status, created_at, updated_at
                FROM vouchers WHERE voucher_id = $1 AND company_id = $2 AND is_deleted = FALSE`

	var v models.Voucher
	err := s.db.QueryRow(query, voucherID, companyID).Scan(&v.VoucherID, &v.CompanyID, &v.Type, &v.Date, &v.Amount, &v.AccountID, &v.SettlementAccountID, &v.BankAccountID, &v.Reference, &v.Description, &v.SyncStatus, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("voucher not found")
		}
		return nil, fmt.Errorf("failed to get voucher: %w", err)
	}

	lines, err := s.getVoucherLines(companyID, voucherID)
	if err != nil {
		return nil, err
	}
	v.Lines = lines
	return &v, nil
}

func (s *VoucherService) getVoucherLines(companyID, voucherID int) ([]models.VoucherLine, error) {
	rows, err := s.db.Query(`
		SELECT vl.line_id, vl.voucher_id, vl.company_id, vl.account_id, coa.account_code, coa.name,
		       vl.line_no, vl.debit, vl.credit, vl.description, vl.created_at
		FROM voucher_lines vl
		JOIN chart_of_accounts coa ON coa.account_id = vl.account_id
		WHERE vl.company_id = $1 AND vl.voucher_id = $2
		ORDER BY vl.line_no
	`, companyID, voucherID)
	if err != nil {
		return nil, fmt.Errorf("failed to load voucher lines: %w", err)
	}
	defer rows.Close()

	lines := make([]models.VoucherLine, 0)
	for rows.Next() {
		var line models.VoucherLine
		if err := rows.Scan(
			&line.LineID,
			&line.VoucherID,
			&line.CompanyID,
			&line.AccountID,
			&line.AccountCode,
			&line.AccountName,
			&line.LineNo,
			&line.Debit,
			&line.Credit,
			&line.Description,
			&line.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan voucher line: %w", err)
		}
		lines = append(lines, line)
	}
	return lines, nil
}
