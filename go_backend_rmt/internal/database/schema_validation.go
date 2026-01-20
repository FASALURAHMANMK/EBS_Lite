package database

import (
	"database/sql"
	"fmt"
	"sort"
	"strings"
)

type schemaRequirement struct {
	table   string
	columns []string
}

// ValidateSchema checks for required tables/columns and returns a descriptive error
// if the deployed schema is missing anything the backend relies on.
func ValidateSchema(db *sql.DB) error {
	if db == nil {
		db = DB
	}
	if db == nil {
		return fmt.Errorf("database connection is nil")
	}

	requirements := []schemaRequirement{
		{table: "stock_adjustment_documents", columns: []string{"document_id", "document_number", "location_id", "reason", "created_by", "created_at"}},
		{table: "stock_adjustment_document_items", columns: []string{"item_id", "document_id", "product_id", "adjustment"}},
		{table: "attendance", columns: []string{"attendance_id", "employee_id", "check_in", "check_out", "is_deleted"}},
		{table: "employees", columns: []string{"last_check_in", "last_check_out", "leave_balance"}},
		{table: "leaves", columns: []string{"leave_id", "employee_id", "start_date", "end_date", "reason", "status"}},
		{table: "holidays", columns: []string{"name"}},
		{table: "expenses", columns: []string{"notes"}},
		{table: "vouchers", columns: []string{"company_id", "account_id"}},
		{table: "ledger_entries", columns: []string{"company_id", "reference"}},
		{table: "promotions", columns: []string{"updated_at"}},
		{table: "settings", columns: []string{"value"}},
		{table: "customer_credit_transactions", columns: []string{"transaction_id", "customer_id", "company_id", "amount", "type", "created_by"}},
		{table: "password_reset_tokens", columns: []string{"user_id", "token", "expires_at"}},
		{table: "cash_register_tally", columns: []string{"location_id", "count", "recorded_by"}},
		{table: "salary_components", columns: []string{"payroll_id", "type", "amount"}},
		{table: "payroll_advances", columns: []string{"payroll_id", "amount", "date"}},
		{table: "payroll_deductions", columns: []string{"payroll_id", "type", "amount", "date"}},
	}

	missing := make([]string, 0)
	for _, req := range requirements {
		columnSet, err := fetchTableColumns(db, req.table)
		if err != nil {
			return err
		}
		missingCols := make([]string, 0)
		for _, col := range req.columns {
			if _, ok := columnSet[col]; !ok {
				missingCols = append(missingCols, col)
			}
		}
		if len(missingCols) > 0 {
			sort.Strings(missingCols)
			missing = append(missing, fmt.Sprintf("%s: %s", req.table, strings.Join(missingCols, ", ")))
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("schema validation failed; missing columns -> %s", strings.Join(missing, "; "))
	}

	return nil
}

func fetchTableColumns(db *sql.DB, table string) (map[string]struct{}, error) {
	rows, err := db.Query(
		`SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1`,
		table,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to read columns for %s: %w", table, err)
	}
	defer rows.Close()

	cols := make(map[string]struct{})
	for rows.Next() {
		var col string
		if err := rows.Scan(&col); err != nil {
			return nil, fmt.Errorf("failed to scan columns for %s: %w", table, err)
		}
		cols[col] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read columns for %s: %w", table, err)
	}
	return cols, nil
}
