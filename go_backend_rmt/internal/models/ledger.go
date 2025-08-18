package models

import "time"

type LedgerEntry struct {
	EntryID         int       `json:"entry_id" db:"entry_id"`
	CompanyID       int       `json:"company_id" db:"company_id"`
	AccountID       int       `json:"account_id" db:"account_id"`
	VoucherID       *int      `json:"voucher_id,omitempty" db:"voucher_id"`
	Date            time.Time `json:"date" db:"date"`
	Debit           float64   `json:"debit" db:"debit"`
	Credit          float64   `json:"credit" db:"credit"`
	Balance         float64   `json:"balance" db:"balance"`
	TransactionType *string   `json:"transaction_type,omitempty" db:"transaction_type"`
	TransactionID   *int      `json:"transaction_id,omitempty" db:"transaction_id"`
	Description     *string   `json:"description,omitempty" db:"description"`
	CreatedBy       int       `json:"created_by" db:"created_by"`
	UpdatedBy       *int      `json:"updated_by,omitempty" db:"updated_by"`
	SyncModel
}

// LedgerEntryWithDetails represents a ledger entry with related transaction information
type LedgerEntryWithDetails struct {
	LedgerEntry
	Voucher  *Voucher  `json:"voucher,omitempty"`
	Sale     *Sale     `json:"sale,omitempty"`
	Purchase *Purchase `json:"purchase,omitempty"`
}

type AccountBalance struct {
	AccountID int     `json:"account_id" db:"account_id"`
	Balance   float64 `json:"balance" db:"balance"`
}
