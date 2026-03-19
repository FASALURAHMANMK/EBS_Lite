package services

import (
	"database/sql"
	"fmt"
)

type defaultAccount struct {
	Code    string
	Name    string
	Type    string
	Subtype string
}

var minimalDefaultChartOfAccounts = []defaultAccount{
	{Code: "1000", Name: "Cash", Type: "ASSET", Subtype: "CASH"},
	{Code: "1010", Name: "Bank", Type: "ASSET", Subtype: "BANK"},
	{Code: "1100", Name: "Accounts Receivable", Type: "ASSET", Subtype: "AR"},
	{Code: "1200", Name: "Inventory", Type: "ASSET", Subtype: "INVENTORY"},
	{Code: "1210", Name: "Fixed Assets", Type: "ASSET", Subtype: "FIXED_ASSET"},
	{Code: "2000", Name: "Accounts Payable", Type: "LIABILITY", Subtype: "AP"},
	{Code: "2100", Name: "Tax Payable", Type: "LIABILITY", Subtype: "TAX_PAYABLE"},
	{Code: "2200", Name: "Tax Receivable", Type: "ASSET", Subtype: "TAX_RECEIVABLE"},
	{Code: "4000", Name: "Sales Revenue", Type: "REVENUE", Subtype: "SALES"},
	{Code: "5000", Name: "Cost of Goods Sold", Type: "EXPENSE", Subtype: "COGS"},
	{Code: "6000", Name: "Expenses", Type: "EXPENSE", Subtype: "EXPENSES"},
	{Code: "6010", Name: "Consumables Expense", Type: "EXPENSE", Subtype: "CONSUMABLE_EXPENSE"},
}

func seedMinimalChartOfAccountsTx(tx *sql.Tx, companyID int) error {
	for _, a := range minimalDefaultChartOfAccounts {
		// Use NOT EXISTS to remain safe even when unique indexes are not present.
		if _, err := tx.Exec(`
			INSERT INTO chart_of_accounts (company_id, account_code, name, type, subtype, is_active)
			SELECT $1,$2,$3,$4,$5,TRUE
			WHERE NOT EXISTS (
				SELECT 1 FROM chart_of_accounts
				WHERE company_id = $1 AND account_code = $2
			)
		`, companyID, a.Code, a.Name, a.Type, a.Subtype); err != nil {
			return fmt.Errorf("failed to seed chart of accounts (%s): %w", a.Code, err)
		}
	}
	return nil
}
