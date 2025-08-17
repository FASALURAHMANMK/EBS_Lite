package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ExpenseService struct {
	db *sql.DB
}

func NewExpenseService() *ExpenseService {
	return &ExpenseService{db: database.GetDB()}
}

func (s *ExpenseService) CreateExpense(companyID, locationID, userID int, req *models.CreateExpenseRequest) (int, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO expenses (category_id, location_id, amount, notes, expense_date, created_by, updated_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING expense_id`,
		req.CategoryID, locationID, req.Amount, req.Notes, req.ExpenseDate, userID, userID).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create expense: %w", err)
	}
	ledger := NewLedgerService()
	_ = ledger.RecordExpense(companyID, id, req.Amount, userID)
	return id, nil
}

func (s *ExpenseService) GetCategories(companyID int) ([]models.ExpenseCategory, error) {
	rows, err := s.db.Query(`SELECT category_id, name, created_by, updated_by FROM expense_categories WHERE company_id=$1 AND is_deleted=FALSE`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get categories: %w", err)
	}
	defer rows.Close()
	var cats []models.ExpenseCategory
	for rows.Next() {
		var c models.ExpenseCategory
		if err := rows.Scan(&c.CategoryID, &c.Name, &c.CreatedBy, &c.UpdatedBy); err != nil {
			return nil, fmt.Errorf("failed to scan category: %w", err)
		}
		cats = append(cats, c)
	}
	return cats, nil
}

func (s *ExpenseService) CreateCategory(companyID, userID int, name string) (int, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO expense_categories (company_id, name, created_by, updated_by) VALUES ($1,$2,$3,$3) RETURNING category_id`, companyID, name, userID).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create category: %w", err)
	}
	return id, nil
}

// ListExpenses retrieves expenses with optional filters for category, date range and location.
func (s *ExpenseService) ListExpenses(companyID int, filters map[string]string) ([]models.ExpenseWithDetails, error) {
	query := `
                SELECT e.expense_id, e.category_id, e.location_id, e.amount, e.notes, e.expense_date, e.created_by,
                       e.sync_status, e.created_at, e.updated_at,
                       c.name as category_name, l.name as location_name,
                       v.voucher_id, v.type, v.account_id, v.amount, v.reference, v.description
                FROM expenses e
                JOIN expense_categories c ON e.category_id = c.category_id
                JOIN locations l ON e.location_id = l.location_id
                LEFT JOIN vouchers v ON v.reference = CAST(e.expense_id AS TEXT) AND v.is_deleted = FALSE
                WHERE c.company_id = $1 AND e.is_deleted = FALSE`

	args := []interface{}{companyID}
	argCount := 1

	if v, ok := filters["category_id"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND e.category_id = $%d", argCount)
		args = append(args, v)
	}
	if v, ok := filters["location_id"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND e.location_id = $%d", argCount)
		args = append(args, v)
	}
	if v, ok := filters["date_from"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND e.expense_date >= $%d", argCount)
		args = append(args, v)
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND e.expense_date <= $%d", argCount)
		args = append(args, v)
	}

	query += " ORDER BY e.expense_date DESC, e.expense_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.ExpenseWithDetails
	for rows.Next() {
		var e models.ExpenseWithDetails
		var categoryName, locationName sql.NullString
		var voucherID sql.NullInt64
		var voucherType, voucherRef, voucherDesc sql.NullString
		var voucherAccountID sql.NullInt64
		var voucherAmount sql.NullFloat64

		if err := rows.Scan(
			&e.ExpenseID, &e.CategoryID, &e.LocationID, &e.Amount, &e.Notes, &e.ExpenseDate, &e.CreatedBy,
			&e.SyncStatus, &e.CreatedAt, &e.UpdatedAt,
			&categoryName, &locationName,
			&voucherID, &voucherType, &voucherAccountID, &voucherAmount, &voucherRef, &voucherDesc,
		); err != nil {
			return nil, fmt.Errorf("failed to scan expense: %w", err)
		}

		if categoryName.Valid {
			e.Category = &models.ExpenseCategory{CategoryID: e.CategoryID, Name: categoryName.String}
		}
		if locationName.Valid {
			e.Location = &models.Location{LocationID: e.LocationID, Name: locationName.String}
		}
		if voucherID.Valid {
			e.Voucher = &models.Voucher{
				VoucherID:   int(voucherID.Int64),
				Type:        voucherType.String,
				AccountID:   int(voucherAccountID.Int64),
				Amount:      voucherAmount.Float64,
				Reference:   voucherRef.String,
				Description: nullStringToStringPtr(voucherDesc),
			}
		}

		expenses = append(expenses, e)
	}

	return expenses, nil
}

// GetExpense retrieves a single expense by ID including related voucher/payment data.
func (s *ExpenseService) GetExpense(companyID, expenseID int) (*models.ExpenseWithDetails, error) {
	query := `
                SELECT e.expense_id, e.category_id, e.location_id, e.amount, e.notes, e.expense_date, e.created_by,
                       e.sync_status, e.created_at, e.updated_at,
                       c.name as category_name, l.name as location_name,
                       v.voucher_id, v.type, v.account_id, v.amount, v.reference, v.description
                FROM expenses e
                JOIN expense_categories c ON e.category_id = c.category_id
                JOIN locations l ON e.location_id = l.location_id
                LEFT JOIN vouchers v ON v.reference = CAST(e.expense_id AS TEXT) AND v.is_deleted = FALSE
                WHERE e.expense_id = $1 AND c.company_id = $2 AND e.is_deleted = FALSE`

	var e models.ExpenseWithDetails
	var categoryName, locationName sql.NullString
	var voucherID sql.NullInt64
	var voucherType, voucherRef, voucherDesc sql.NullString
	var voucherAccountID sql.NullInt64
	var voucherAmount sql.NullFloat64

	err := s.db.QueryRow(query, expenseID, companyID).Scan(
		&e.ExpenseID, &e.CategoryID, &e.LocationID, &e.Amount, &e.Notes, &e.ExpenseDate, &e.CreatedBy,
		&e.SyncStatus, &e.CreatedAt, &e.UpdatedAt,
		&categoryName, &locationName,
		&voucherID, &voucherType, &voucherAccountID, &voucherAmount, &voucherRef, &voucherDesc,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("expense not found")
		}
		return nil, fmt.Errorf("failed to get expense: %w", err)
	}

	if categoryName.Valid {
		e.Category = &models.ExpenseCategory{CategoryID: e.CategoryID, Name: categoryName.String}
	}
	if locationName.Valid {
		e.Location = &models.Location{LocationID: e.LocationID, Name: locationName.String}
	}
	if voucherID.Valid {
		e.Voucher = &models.Voucher{
			VoucherID:   int(voucherID.Int64),
			Type:        voucherType.String,
			AccountID:   int(voucherAccountID.Int64),
			Amount:      voucherAmount.Float64,
			Reference:   voucherRef.String,
			Description: nullStringToStringPtr(voucherDesc),
		}
	}

	return &e, nil
}
