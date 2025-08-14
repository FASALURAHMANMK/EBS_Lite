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
	err := s.db.QueryRow(`INSERT INTO expenses (category_id, location_id, amount, notes, expense_date, created_by)
                VALUES ($1,$2,$3,$4,$5,$6) RETURNING expense_id`,
		req.CategoryID, locationID, req.Amount, req.Notes, req.ExpenseDate, userID).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create expense: %w", err)
	}
	ledger := NewLedgerService()
	_ = ledger.RecordExpense(companyID, id, req.Amount)
	return id, nil
}

func (s *ExpenseService) GetCategories(companyID int) ([]models.ExpenseCategory, error) {
	rows, err := s.db.Query(`SELECT category_id, name FROM expense_categories WHERE company_id=$1 AND is_deleted=FALSE`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get categories: %w", err)
	}
	defer rows.Close()
	var cats []models.ExpenseCategory
	for rows.Next() {
		var c models.ExpenseCategory
		if err := rows.Scan(&c.CategoryID, &c.Name); err != nil {
			return nil, fmt.Errorf("failed to scan category: %w", err)
		}
		cats = append(cats, c)
	}
	return cats, nil
}

func (s *ExpenseService) CreateCategory(companyID int, name string) (int, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO expense_categories (company_id, name) VALUES ($1,$2) RETURNING category_id`, companyID, name).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create category: %w", err)
	}
	return id, nil
}
