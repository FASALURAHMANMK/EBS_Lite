package models

import "time"

type Expense struct {
	ExpenseID   int       `json:"expense_id" db:"expense_id"`
	CategoryID  int       `json:"category_id" db:"category_id"`
	LocationID  int       `json:"location_id" db:"location_id"`
	Amount      float64   `json:"amount" db:"amount"`
	Notes       *string   `json:"notes,omitempty" db:"notes"`
	ExpenseDate time.Time `json:"expense_date" db:"expense_date"`
	CreatedBy   int       `json:"created_by" db:"created_by"`
	SyncModel
}

type ExpenseCategory struct {
	CategoryID int    `json:"category_id" db:"category_id"`
	Name       string `json:"name" db:"name"`
	SyncModel
}

type CreateExpenseRequest struct {
	CategoryID  int       `json:"category_id" validate:"required"`
	Amount      float64   `json:"amount" validate:"required,gt=0"`
	Notes       *string   `json:"notes,omitempty"`
	ExpenseDate time.Time `json:"expense_date"`
}

type CreateExpenseCategoryRequest struct {
	Name string `json:"name" validate:"required"`
}
