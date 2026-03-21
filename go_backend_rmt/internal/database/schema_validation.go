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

type uniqueIndexRequirement struct {
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
		{table: "products", columns: []string{"has_warranty", "warranty_period_months"}},
		{table: "warranty_registrations", columns: []string{"warranty_id", "company_id", "sale_id", "sale_number", "customer_name", "registered_at"}},
		{table: "warranty_items", columns: []string{"warranty_item_id", "warranty_id", "sale_detail_id", "product_id", "quantity", "warranty_end_date"}},
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

	uniqueRequirements := []uniqueIndexRequirement{
		{table: "settings", columns: []string{"company_id", "key"}},
	}

	missingUnique, err := validateUniqueIndexes(db, uniqueRequirements)
	if err != nil {
		return err
	}
	if len(missingUnique) > 0 {
		return fmt.Errorf("schema validation failed; missing unique indexes -> %s", strings.Join(missingUnique, "; "))
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

func validateUniqueIndexes(db *sql.DB, requirements []uniqueIndexRequirement) ([]string, error) {
	missing := make([]string, 0)
	for _, req := range requirements {
		ok, err := hasUniqueIndex(db, req.table, req.columns)
		if err != nil {
			return nil, err
		}
		if !ok {
			missing = append(missing, fmt.Sprintf("%s(%s)", req.table, strings.Join(req.columns, ", ")))
		}
	}
	return missing, nil
}

func hasUniqueIndex(db *sql.DB, table string, columns []string) (bool, error) {
	const query = `
		SELECT EXISTS (
			SELECT 1
			FROM pg_class t
			JOIN pg_namespace ns ON ns.oid = t.relnamespace
			JOIN pg_index i ON i.indrelid = t.oid
			JOIN LATERAL (
				SELECT string_agg(a.attname, ',' ORDER BY keys.ordinality) AS cols
				FROM unnest(i.indkey) WITH ORDINALITY AS keys(attnum, ordinality)
				JOIN pg_attribute a
					ON a.attrelid = t.oid
					AND a.attnum = keys.attnum
			) idx_cols ON TRUE
			WHERE ns.nspname = 'public'
				AND t.relname = $1
				AND i.indisunique
				AND i.indpred IS NULL
				AND idx_cols.cols = $2
		)
	`

	var exists bool
	if err := db.QueryRow(query, table, strings.Join(columns, ",")).Scan(&exists); err != nil {
		return false, fmt.Errorf("failed to inspect unique indexes for %s: %w", table, err)
	}
	return exists, nil
}
