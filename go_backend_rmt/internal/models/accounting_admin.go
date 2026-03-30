package models

import "time"

type ChartOfAccount struct {
	AccountID      int      `json:"account_id" db:"account_id"`
	CompanyID      int      `json:"company_id" db:"company_id"`
	AccountCode    *string  `json:"account_code,omitempty" db:"account_code"`
	Name           string   `json:"name" db:"name"`
	Type           string   `json:"type" db:"type"`
	Subtype        *string  `json:"subtype,omitempty" db:"subtype"`
	ParentID       *int     `json:"parent_id,omitempty" db:"parent_id"`
	ParentCode     *string  `json:"parent_code,omitempty"`
	ParentName     *string  `json:"parent_name,omitempty"`
	IsActive       bool     `json:"is_active" db:"is_active"`
	CurrentBalance *float64 `json:"current_balance,omitempty"`
}

type CreateChartOfAccountRequest struct {
	AccountCode *string `json:"account_code,omitempty"`
	Name        string  `json:"name" validate:"required,min=2,max=255"`
	Type        string  `json:"type" validate:"required,oneof=ASSET LIABILITY EQUITY REVENUE EXPENSE"`
	Subtype     *string `json:"subtype,omitempty"`
	ParentID    *int    `json:"parent_id,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

type UpdateChartOfAccountRequest struct {
	AccountCode *string `json:"account_code,omitempty"`
	Name        *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Type        *string `json:"type,omitempty" validate:"omitempty,oneof=ASSET LIABILITY EQUITY REVENUE EXPENSE"`
	Subtype     *string `json:"subtype,omitempty"`
	ParentID    *int    `json:"parent_id,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

type BankAccount struct {
	BankAccountID       int        `json:"bank_account_id" db:"bank_account_id"`
	CompanyID           int        `json:"company_id" db:"company_id"`
	LedgerAccountID     int        `json:"ledger_account_id" db:"ledger_account_id"`
	LedgerAccountCode   *string    `json:"ledger_account_code,omitempty"`
	LedgerAccountName   *string    `json:"ledger_account_name,omitempty"`
	DefaultLocationID   *int       `json:"default_location_id,omitempty" db:"default_location_id"`
	AccountName         string     `json:"account_name" db:"account_name"`
	BankName            string     `json:"bank_name" db:"bank_name"`
	AccountNumberMasked *string    `json:"account_number_masked,omitempty" db:"account_number_masked"`
	BranchName          *string    `json:"branch_name,omitempty" db:"branch_name"`
	CurrencyCode        *string    `json:"currency_code,omitempty" db:"currency_code"`
	StatementImportHint *string    `json:"statement_import_hint,omitempty" db:"statement_import_hint"`
	OpeningBalance      float64    `json:"opening_balance" db:"opening_balance"`
	IsActive            bool       `json:"is_active" db:"is_active"`
	UnmatchedEntries    int        `json:"unmatched_entries,omitempty"`
	ReviewEntries       int        `json:"review_entries,omitempty"`
	LastStatementDate   *time.Time `json:"last_statement_date,omitempty"`
}

type CreateBankAccountRequest struct {
	LedgerAccountID     int      `json:"ledger_account_id" validate:"required"`
	DefaultLocationID   *int     `json:"default_location_id,omitempty"`
	AccountName         string   `json:"account_name" validate:"required,min=2,max=255"`
	BankName            string   `json:"bank_name" validate:"required,min=2,max=255"`
	AccountNumberMasked *string  `json:"account_number_masked,omitempty"`
	BranchName          *string  `json:"branch_name,omitempty"`
	CurrencyCode        *string  `json:"currency_code,omitempty"`
	StatementImportHint *string  `json:"statement_import_hint,omitempty"`
	OpeningBalance      *float64 `json:"opening_balance,omitempty"`
	IsActive            *bool    `json:"is_active,omitempty"`
}

type UpdateBankAccountRequest struct {
	LedgerAccountID     *int     `json:"ledger_account_id,omitempty"`
	DefaultLocationID   *int     `json:"default_location_id,omitempty"`
	AccountName         *string  `json:"account_name,omitempty" validate:"omitempty,min=2,max=255"`
	BankName            *string  `json:"bank_name,omitempty" validate:"omitempty,min=2,max=255"`
	AccountNumberMasked *string  `json:"account_number_masked,omitempty"`
	BranchName          *string  `json:"branch_name,omitempty"`
	CurrencyCode        *string  `json:"currency_code,omitempty"`
	StatementImportHint *string  `json:"statement_import_hint,omitempty"`
	OpeningBalance      *float64 `json:"opening_balance,omitempty"`
	IsActive            *bool    `json:"is_active,omitempty"`
}

type BankStatementEntry struct {
	StatementEntryID int                       `json:"statement_entry_id" db:"statement_entry_id"`
	CompanyID        int                       `json:"company_id" db:"company_id"`
	BankAccountID    int                       `json:"bank_account_id" db:"bank_account_id"`
	EntryDate        time.Time                 `json:"entry_date" db:"entry_date"`
	ValueDate        *time.Time                `json:"value_date,omitempty" db:"value_date"`
	Description      *string                   `json:"description,omitempty" db:"description"`
	Reference        *string                   `json:"reference,omitempty" db:"reference"`
	ExternalRef      *string                   `json:"external_ref,omitempty" db:"external_ref"`
	SourceType       string                    `json:"source_type" db:"source_type"`
	DepositAmount    float64                   `json:"deposit_amount" db:"deposit_amount"`
	WithdrawalAmount float64                   `json:"withdrawal_amount" db:"withdrawal_amount"`
	RunningBalance   *float64                  `json:"running_balance,omitempty" db:"running_balance"`
	Status           string                    `json:"status" db:"status"`
	ReviewReason     *string                   `json:"review_reason,omitempty" db:"review_reason"`
	MatchedAmount    float64                   `json:"matched_amount"`
	AvailableAmount  float64                   `json:"available_amount"`
	CreatedAt        time.Time                 `json:"created_at" db:"created_at"`
	Matches          []BankReconciliationMatch `json:"matches,omitempty"`
}

type CreateBankStatementEntryRequest struct {
	EntryDate        string   `json:"entry_date" validate:"required"`
	ValueDate        *string  `json:"value_date,omitempty"`
	Description      *string  `json:"description,omitempty"`
	Reference        *string  `json:"reference,omitempty"`
	ExternalRef      *string  `json:"external_ref,omitempty"`
	SourceType       *string  `json:"source_type,omitempty"`
	DepositAmount    float64  `json:"deposit_amount"`
	WithdrawalAmount float64  `json:"withdrawal_amount"`
	RunningBalance   *float64 `json:"running_balance,omitempty"`
	ReviewReason     *string  `json:"review_reason,omitempty"`
	IdempotencyKey   *string  `json:"idempotency_key,omitempty"`
}

type BankReconciliationMatch struct {
	MatchID           int        `json:"match_id" db:"match_id"`
	CompanyID         int        `json:"company_id" db:"company_id"`
	BankAccountID     int        `json:"bank_account_id" db:"bank_account_id"`
	StatementEntryID  int        `json:"statement_entry_id" db:"statement_entry_id"`
	LedgerEntryID     int        `json:"ledger_entry_id" db:"ledger_entry_id"`
	MatchedAmount     float64    `json:"matched_amount" db:"matched_amount"`
	MatchKind         string     `json:"match_kind" db:"match_kind"`
	Notes             *string    `json:"notes,omitempty" db:"notes"`
	CreatedBy         int        `json:"created_by" db:"created_by"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	LedgerDate        *time.Time `json:"ledger_date,omitempty"`
	LedgerReference   *string    `json:"ledger_reference,omitempty"`
	LedgerDescription *string    `json:"ledger_description,omitempty"`
}

type MatchBankStatementRequest struct {
	StatementEntryID int     `json:"statement_entry_id" validate:"required"`
	LedgerEntryID    int     `json:"ledger_entry_id" validate:"required"`
	MatchedAmount    float64 `json:"matched_amount" validate:"required,gt=0"`
	Notes            *string `json:"notes,omitempty"`
}

type UnmatchBankStatementRequest struct {
	StatementEntryID int `json:"statement_entry_id" validate:"required"`
	MatchID          int `json:"match_id" validate:"required"`
}

type ReviewBankStatementRequest struct {
	StatementEntryID int     `json:"statement_entry_id" validate:"required"`
	ReviewReason     *string `json:"review_reason,omitempty"`
}

type CreateBankAdjustmentRequest struct {
	StatementEntryID int                        `json:"statement_entry_id" validate:"required"`
	AdjustmentType   string                     `json:"adjustment_type" validate:"required,oneof=BANK_CHARGE ADJUSTMENT"`
	OffsetAccountID  int                        `json:"offset_account_id" validate:"required"`
	Reference        *string                    `json:"reference,omitempty"`
	Description      *string                    `json:"description,omitempty"`
	Date             *string                    `json:"date,omitempty"`
	IdempotencyKey   *string                    `json:"idempotency_key,omitempty"`
	Lines            []CreateVoucherLineRequest `json:"lines,omitempty"`
}

type AccountingPeriod struct {
	PeriodID   int                    `json:"period_id" db:"period_id"`
	CompanyID  int                    `json:"company_id" db:"company_id"`
	PeriodName string                 `json:"period_name" db:"period_name"`
	StartDate  time.Time              `json:"start_date" db:"start_date"`
	EndDate    time.Time              `json:"end_date" db:"end_date"`
	Status     string                 `json:"status" db:"status"`
	Checklist  map[string]interface{} `json:"checklist"`
	Notes      *string                `json:"notes,omitempty" db:"notes"`
	ClosedAt   *time.Time             `json:"closed_at,omitempty" db:"closed_at"`
	ClosedBy   *int                   `json:"closed_by,omitempty" db:"closed_by"`
	ReopenedAt *time.Time             `json:"reopened_at,omitempty" db:"reopened_at"`
	ReopenedBy *int                   `json:"reopened_by,omitempty" db:"reopened_by"`
	CreatedAt  time.Time              `json:"created_at" db:"created_at"`
}

type CreateAccountingPeriodRequest struct {
	PeriodName string  `json:"period_name" validate:"required,min=3,max=20"`
	StartDate  string  `json:"start_date" validate:"required"`
	EndDate    string  `json:"end_date" validate:"required"`
	Notes      *string `json:"notes,omitempty"`
}

type UpdateAccountingPeriodStatusRequest struct {
	Notes *string `json:"notes,omitempty"`
}
