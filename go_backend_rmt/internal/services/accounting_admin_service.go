package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type AccountingAdminService struct {
	db *sql.DB
}

func NewAccountingAdminService() *AccountingAdminService {
	return &AccountingAdminService{db: database.GetDB()}
}

func parseAccountingDate(raw string) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, fmt.Errorf("date is required")
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid date format")
}

func (s *AccountingAdminService) ensureAccountBelongsToCompany(companyID int, accountID *int) error {
	if accountID == nil || *accountID <= 0 {
		return nil
	}
	var exists bool
	if err := s.db.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM chart_of_accounts
			WHERE company_id = $1 AND account_id = $2
		)
	`, companyID, *accountID).Scan(&exists); err != nil {
		return fmt.Errorf("failed to validate account: %w", err)
	}
	if !exists {
		return fmt.Errorf("account not found")
	}
	return nil
}

func (s *AccountingAdminService) EnsurePeriodOpen(companyID int, txnDate time.Time) error {
	var exists bool
	if err := s.db.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM accounting_periods
			WHERE company_id = $1
			  AND status = 'CLOSED'
			  AND start_date <= $2
			  AND end_date >= $2
		)
	`, companyID, txnDate.Format("2006-01-02")).Scan(&exists); err != nil {
		return fmt.Errorf("failed to check accounting period status: %w", err)
	}
	if exists {
		return fmt.Errorf("the accounting period for %s is closed", txnDate.Format("2006-01-02"))
	}
	return nil
}

func (s *AccountingAdminService) ListChartOfAccounts(companyID int, includeInactive bool) ([]models.ChartOfAccount, error) {
	query := `
		SELECT
			coa.account_id,
			coa.company_id,
			coa.account_code,
			coa.name,
			coa.type,
			coa.subtype,
			coa.parent_id,
			parent.account_code,
			parent.name,
			coa.is_active,
			COALESCE(SUM(le.debit - le.credit), 0)::float8 AS current_balance
		FROM chart_of_accounts coa
		LEFT JOIN chart_of_accounts parent ON parent.account_id = coa.parent_id
		LEFT JOIN ledger_entries le ON le.company_id = coa.company_id AND le.account_id = coa.account_id
		WHERE coa.company_id = $1
	`
	if !includeInactive {
		query += " AND coa.is_active = TRUE"
	}
	query += `
		GROUP BY coa.account_id, coa.company_id, coa.account_code, coa.name, coa.type, coa.subtype, coa.parent_id,
		         parent.account_code, parent.name, coa.is_active
		ORDER BY coa.account_code NULLS LAST, coa.name
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to list chart of accounts: %w", err)
	}
	defer rows.Close()

	items := make([]models.ChartOfAccount, 0)
	for rows.Next() {
		var item models.ChartOfAccount
		var balance sql.NullFloat64
		if err := rows.Scan(
			&item.AccountID,
			&item.CompanyID,
			&item.AccountCode,
			&item.Name,
			&item.Type,
			&item.Subtype,
			&item.ParentID,
			&item.ParentCode,
			&item.ParentName,
			&item.IsActive,
			&balance,
		); err != nil {
			return nil, fmt.Errorf("failed to scan chart of accounts row: %w", err)
		}
		if balance.Valid {
			item.CurrentBalance = &balance.Float64
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *AccountingAdminService) CreateChartOfAccount(companyID, userID int, req *models.CreateChartOfAccountRequest) (*models.ChartOfAccount, error) {
	if err := s.ensureAccountBelongsToCompany(companyID, req.ParentID); err != nil {
		return nil, err
	}
	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}
	var item models.ChartOfAccount
	if err := s.db.QueryRow(`
		INSERT INTO chart_of_accounts (company_id, account_code, name, type, subtype, parent_id, is_active)
		VALUES ($1, NULLIF($2, ''), $3, $4, NULLIF($5, ''), $6, $7)
		RETURNING account_id, company_id, account_code, name, type, subtype, parent_id, is_active
	`,
		companyID,
		strings.TrimSpace(valueOrEmpty(req.AccountCode)),
		strings.TrimSpace(req.Name),
		strings.TrimSpace(req.Type),
		strings.TrimSpace(valueOrEmpty(req.Subtype)),
		req.ParentID,
		active,
	).Scan(&item.AccountID, &item.CompanyID, &item.AccountCode, &item.Name, &item.Type, &item.Subtype, &item.ParentID, &item.IsActive); err != nil {
		return nil, fmt.Errorf("failed to create chart of account: %w", err)
	}
	return s.GetChartOfAccount(companyID, item.AccountID)
}

func (s *AccountingAdminService) UpdateChartOfAccount(companyID, accountID, userID int, req *models.UpdateChartOfAccountRequest) (*models.ChartOfAccount, error) {
	if err := s.ensureAccountBelongsToCompany(companyID, req.ParentID); err != nil {
		return nil, err
	}
	if req.ParentID != nil && *req.ParentID == accountID {
		return nil, fmt.Errorf("an account cannot be its own parent")
	}
	if _, err := s.db.Exec(`
		UPDATE chart_of_accounts
		SET account_code = COALESCE(NULLIF($1, ''), account_code),
		    name = COALESCE(NULLIF($2, ''), name),
		    type = COALESCE(NULLIF($3, ''), type),
		    subtype = CASE WHEN $4::text IS NULL THEN subtype ELSE NULLIF($4, '') END,
		    parent_id = COALESCE($5, parent_id),
		    is_active = COALESCE($6, is_active)
		WHERE company_id = $7 AND account_id = $8
	`,
		trimPointer(req.AccountCode),
		trimPointer(req.Name),
		trimPointer(req.Type),
		trimPointer(req.Subtype),
		req.ParentID,
		req.IsActive,
		companyID,
		accountID,
	); err != nil {
		return nil, fmt.Errorf("failed to update chart of account: %w", err)
	}
	return s.GetChartOfAccount(companyID, accountID)
}

func (s *AccountingAdminService) GetChartOfAccount(companyID, accountID int) (*models.ChartOfAccount, error) {
	var item models.ChartOfAccount
	var balance sql.NullFloat64
	err := s.db.QueryRow(`
		SELECT
			coa.account_id,
			coa.company_id,
			coa.account_code,
			coa.name,
			coa.type,
			coa.subtype,
			coa.parent_id,
			parent.account_code,
			parent.name,
			coa.is_active,
			COALESCE(SUM(le.debit - le.credit), 0)::float8 AS current_balance
		FROM chart_of_accounts coa
		LEFT JOIN chart_of_accounts parent ON parent.account_id = coa.parent_id
		LEFT JOIN ledger_entries le ON le.company_id = coa.company_id AND le.account_id = coa.account_id
		WHERE coa.company_id = $1 AND coa.account_id = $2
		GROUP BY coa.account_id, coa.company_id, coa.account_code, coa.name, coa.type, coa.subtype, coa.parent_id,
		         parent.account_code, parent.name, coa.is_active
	`, companyID, accountID).Scan(
		&item.AccountID,
		&item.CompanyID,
		&item.AccountCode,
		&item.Name,
		&item.Type,
		&item.Subtype,
		&item.ParentID,
		&item.ParentCode,
		&item.ParentName,
		&item.IsActive,
		&balance,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("chart of account not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load chart of account: %w", err)
	}
	if balance.Valid {
		item.CurrentBalance = &balance.Float64
	}
	return &item, nil
}

func (s *AccountingAdminService) ListAccountingPeriods(companyID int) ([]models.AccountingPeriod, error) {
	rows, err := s.db.Query(`
		SELECT period_id, company_id, period_name, start_date, end_date, status, checklist, notes,
		       closed_at, closed_by, reopened_at, reopened_by, created_at
		FROM accounting_periods
		WHERE company_id = $1
		ORDER BY start_date DESC, period_id DESC
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to list accounting periods: %w", err)
	}
	defer rows.Close()

	items := make([]models.AccountingPeriod, 0)
	for rows.Next() {
		var item models.AccountingPeriod
		var rawChecklist []byte
		if err := rows.Scan(
			&item.PeriodID,
			&item.CompanyID,
			&item.PeriodName,
			&item.StartDate,
			&item.EndDate,
			&item.Status,
			&rawChecklist,
			&item.Notes,
			&item.ClosedAt,
			&item.ClosedBy,
			&item.ReopenedAt,
			&item.ReopenedBy,
			&item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan accounting period: %w", err)
		}
		item.Checklist = decodeChecklist(rawChecklist)
		items = append(items, item)
	}
	return items, nil
}

func (s *AccountingAdminService) CreateAccountingPeriod(companyID, userID int, req *models.CreateAccountingPeriodRequest) (*models.AccountingPeriod, error) {
	startDate, err := parseAccountingDate(req.StartDate)
	if err != nil {
		return nil, err
	}
	endDate, err := parseAccountingDate(req.EndDate)
	if err != nil {
		return nil, err
	}
	if endDate.Before(startDate) {
		return nil, fmt.Errorf("end_date must be on or after start_date")
	}
	var periodID int
	if err := s.db.QueryRow(`
		INSERT INTO accounting_periods (company_id, period_name, start_date, end_date, notes, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, $6, $6)
		RETURNING period_id
	`, companyID, strings.TrimSpace(req.PeriodName), startDate, endDate, req.Notes, userID).Scan(&periodID); err != nil {
		return nil, fmt.Errorf("failed to create accounting period: %w", err)
	}
	return s.GetAccountingPeriod(companyID, periodID)
}

func (s *AccountingAdminService) CloseAccountingPeriod(companyID, periodID, userID int, req *models.UpdateAccountingPeriodStatusRequest) (*models.AccountingPeriod, error) {
	period, err := s.GetAccountingPeriod(companyID, periodID)
	if err != nil {
		return nil, err
	}
	if period.Status == "CLOSED" {
		return period, nil
	}
	checklist, canClose, err := s.buildChecklist(companyID, period.StartDate, period.EndDate)
	if err != nil {
		return nil, err
	}
	if !canClose {
		return nil, fmt.Errorf("period close checklist is not satisfied")
	}
	rawChecklist, err := json.Marshal(checklist)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal checklist: %w", err)
	}
	if _, err := s.db.Exec(`
		UPDATE accounting_periods
		SET status = 'CLOSED',
		    checklist = $1,
		    notes = COALESCE($2, notes),
		    closed_at = CURRENT_TIMESTAMP,
		    closed_by = $3,
		    updated_at = CURRENT_TIMESTAMP,
		    updated_by = $3
		WHERE company_id = $4 AND period_id = $5
	`, rawChecklist, req.Notes, userID, companyID, periodID); err != nil {
		return nil, fmt.Errorf("failed to close accounting period: %w", err)
	}
	return s.GetAccountingPeriod(companyID, periodID)
}

func (s *AccountingAdminService) ReopenAccountingPeriod(companyID, periodID, userID int, req *models.UpdateAccountingPeriodStatusRequest) (*models.AccountingPeriod, error) {
	if _, err := s.db.Exec(`
		UPDATE accounting_periods
		SET status = 'OPEN',
		    notes = COALESCE($1, notes),
		    reopened_at = CURRENT_TIMESTAMP,
		    reopened_by = $2,
		    updated_at = CURRENT_TIMESTAMP,
		    updated_by = $2
		WHERE company_id = $3 AND period_id = $4
	`, req.Notes, userID, companyID, periodID); err != nil {
		return nil, fmt.Errorf("failed to reopen accounting period: %w", err)
	}
	return s.GetAccountingPeriod(companyID, periodID)
}

func (s *AccountingAdminService) GetAccountingPeriod(companyID, periodID int) (*models.AccountingPeriod, error) {
	var item models.AccountingPeriod
	var rawChecklist []byte
	err := s.db.QueryRow(`
		SELECT period_id, company_id, period_name, start_date, end_date, status, checklist, notes,
		       closed_at, closed_by, reopened_at, reopened_by, created_at
		FROM accounting_periods
		WHERE company_id = $1 AND period_id = $2
	`, companyID, periodID).Scan(
		&item.PeriodID,
		&item.CompanyID,
		&item.PeriodName,
		&item.StartDate,
		&item.EndDate,
		&item.Status,
		&rawChecklist,
		&item.Notes,
		&item.ClosedAt,
		&item.ClosedBy,
		&item.ReopenedAt,
		&item.ReopenedBy,
		&item.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("accounting period not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load accounting period: %w", err)
	}
	item.Checklist = decodeChecklist(rawChecklist)
	return &item, nil
}

func (s *AccountingAdminService) buildChecklist(companyID int, startDate, endDate time.Time) (map[string]interface{}, bool, error) {
	checklist := map[string]interface{}{}

	var trialBalanceDiff float64
	if err := s.db.QueryRow(`
		SELECT COALESCE(ABS(SUM(debit) - SUM(credit)), 0)::float8
		FROM ledger_entries
		WHERE company_id = $1
		  AND date >= $2
		  AND date <= $3
	`, companyID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02")).Scan(&trialBalanceDiff); err != nil {
		return nil, false, fmt.Errorf("failed to compute trial balance difference: %w", err)
	}
	checklist["trial_balance_balanced"] = map[string]interface{}{
		"passed":     trialBalanceDiff < 0.01,
		"difference": trialBalanceDiff,
	}

	var openFinanceItems int
	if err := s.db.QueryRow(`
		SELECT COUNT(*)
		FROM finance_integrity_outbox
		WHERE company_id = $1
		  AND status IN ('PENDING', 'FAILED', 'PROCESSING')
		  AND created_at::date <= $2
	`, companyID, endDate.Format("2006-01-02")).Scan(&openFinanceItems); err != nil {
		return nil, false, fmt.Errorf("failed to compute finance outbox checklist: %w", err)
	}
	checklist["finance_integrity_clear"] = map[string]interface{}{
		"passed": openFinanceItems == 0,
		"count":  openFinanceItems,
	}

	var unreconciled int
	if err := s.db.QueryRow(`
		SELECT COUNT(*)
		FROM bank_statement_entries
		WHERE company_id = $1
		  AND is_deleted = FALSE
		  AND entry_date >= $2
		  AND entry_date <= $3
		  AND status <> 'MATCHED'
	`, companyID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02")).Scan(&unreconciled); err != nil {
		return nil, false, fmt.Errorf("failed to compute bank reconciliation checklist: %w", err)
	}
	checklist["bank_reconciliation_complete"] = map[string]interface{}{
		"passed": unreconciled == 0,
		"count":  unreconciled,
	}

	canClose := trialBalanceDiff < 0.01 && openFinanceItems == 0 && unreconciled == 0
	return checklist, canClose, nil
}

func decodeChecklist(raw []byte) map[string]interface{} {
	if len(raw) == 0 {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal(raw, &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

func valueOrEmpty(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func trimPointer(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	return &trimmed
}
