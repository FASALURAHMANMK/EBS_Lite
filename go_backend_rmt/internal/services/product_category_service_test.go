package services

import (
	"regexp"
	"testing"
	"time"

	"erp-backend/internal/models"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestProductService_UpdateCategory(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &ProductService{db: db}

	name := "Updated"
	desc := "Desc"
	req := &models.UpdateCategoryRequest{Name: &name, Description: &desc}

	rows := sqlmock.NewRows([]string{"category_id", "company_id", "name", "description", "parent_id", "is_active", "created_by", "updated_by", "created_at", "updated_at"}).
		AddRow(1, 1, name, desc, nil, true, 1, 2, time.Now(), time.Now())

	mock.ExpectQuery(regexp.QuoteMeta("UPDATE categories SET name = $1, description = $2, updated_by = $3, updated_at = CURRENT_TIMESTAMP WHERE category_id = $4 AND company_id = $5 RETURNING category_id, company_id, name, description, parent_id, is_active, created_by, updated_by, created_at, updated_at")).
		WithArgs(name, desc, 2, 1, 1).WillReturnRows(rows)

	cat, err := svc.UpdateCategory(1, 1, 2, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cat.Name != name {
		t.Fatalf("expected name %s, got %s", name, cat.Name)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestProductService_DeleteCategory(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &ProductService{db: db}

	mock.ExpectExec(regexp.QuoteMeta("UPDATE categories SET is_active = FALSE, updated_by = $3, updated_at = CURRENT_TIMESTAMP WHERE category_id = $1 AND company_id = $2 AND is_active = TRUE")).
		WithArgs(1, 1, 2).WillReturnResult(sqlmock.NewResult(0, 1))

	if err := svc.DeleteCategory(1, 1, 2); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
