package models

type LedgerEntry struct {
	EntryID     int     `json:"entry_id" db:"entry_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	AccountID   int     `json:"account_id" db:"account_id"`
	Debit       float64 `json:"debit" db:"debit"`
	Credit      float64 `json:"credit" db:"credit"`
	Reference   string  `json:"reference" db:"reference"`
	Description *string `json:"description,omitempty" db:"description"`
	SyncModel
}

type AccountBalance struct {
	AccountID int     `json:"account_id" db:"account_id"`
	Balance   float64 `json:"balance" db:"balance"`
}
