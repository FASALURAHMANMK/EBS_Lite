package models

import "time"

type Voucher struct {
	VoucherID           int           `json:"voucher_id" db:"voucher_id"`
	CompanyID           int           `json:"company_id" db:"company_id"`
	Type                string        `json:"type" db:"type"`
	Amount              float64       `json:"amount" db:"amount"`
	Date                time.Time     `json:"date" db:"date"`
	AccountID           int           `json:"account_id" db:"account_id"`
	SettlementAccountID *int          `json:"settlement_account_id,omitempty" db:"settlement_account_id"`
	BankAccountID       *int          `json:"bank_account_id,omitempty" db:"bank_account_id"`
	Reference           string        `json:"reference" db:"reference"`
	Description         *string       `json:"description,omitempty" db:"description"`
	Lines               []VoucherLine `json:"lines,omitempty"`
	SyncModel
}

type CreateVoucherRequest struct {
	AccountID           int                        `json:"account_id"`
	Amount              float64                    `json:"amount"`
	SettlementAccountID *int                       `json:"settlement_account_id,omitempty"`
	BankAccountID       *int                       `json:"bank_account_id,omitempty"`
	Reference           string                     `json:"reference" validate:"required"`
	Date                *string                    `json:"date,omitempty"`
	Description         *string                    `json:"description,omitempty"`
	Lines               []CreateVoucherLineRequest `json:"lines,omitempty"`
	IdempotencyKey      *string                    `json:"idempotency_key,omitempty"`
}

type VoucherLine struct {
	LineID      int       `json:"line_id" db:"line_id"`
	VoucherID   int       `json:"voucher_id" db:"voucher_id"`
	CompanyID   int       `json:"company_id" db:"company_id"`
	AccountID   int       `json:"account_id" db:"account_id"`
	AccountCode *string   `json:"account_code,omitempty"`
	AccountName *string   `json:"account_name,omitempty"`
	LineNo      int       `json:"line_no" db:"line_no"`
	Debit       float64   `json:"debit" db:"debit"`
	Credit      float64   `json:"credit" db:"credit"`
	Description *string   `json:"description,omitempty" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type CreateVoucherLineRequest struct {
	AccountID   int     `json:"account_id" validate:"required"`
	Debit       float64 `json:"debit"`
	Credit      float64 `json:"credit"`
	Description *string `json:"description,omitempty"`
}
