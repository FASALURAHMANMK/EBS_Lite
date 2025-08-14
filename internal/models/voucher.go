package models

type Voucher struct {
	VoucherID   int     `json:"voucher_id" db:"voucher_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	Type        string  `json:"type" db:"type"`
	Amount      float64 `json:"amount" db:"amount"`
	AccountID   int     `json:"account_id" db:"account_id"`
	Reference   string  `json:"reference" db:"reference"`
	Description *string `json:"description,omitempty" db:"description"`
	SyncModel
}

type CreateVoucherRequest struct {
	AccountID   int     `json:"account_id" validate:"required"`
	Amount      float64 `json:"amount" validate:"required,gt=0"`
	Reference   string  `json:"reference" validate:"required"`
	Description *string `json:"description,omitempty"`
}
