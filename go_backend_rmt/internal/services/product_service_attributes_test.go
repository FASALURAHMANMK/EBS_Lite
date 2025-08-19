package services

import (
	"database/sql"
	"testing"

	"erp-backend/internal/models"
)

type mockExec struct{ queries []string }

func (m *mockExec) Exec(query string, args ...interface{}) (sql.Result, error) {
	m.queries = append(m.queries, query)
	return paMockResult{}, nil
}

type paMockResult struct{}

func (paMockResult) LastInsertId() (int64, error) { return 0, nil }
func (paMockResult) RowsAffected() (int64, error) { return 0, nil }

type mockAttrProvider struct {
	defs []models.ProductAttributeDefinition
}

func (m *mockAttrProvider) GetAttributeDefinitions(companyID int) ([]models.ProductAttributeDefinition, error) {
	return m.defs, nil
}

func TestValidateAndSaveAttributes_Success(t *testing.T) {
	svc := &ProductService{attributeService: &mockAttrProvider{defs: []models.ProductAttributeDefinition{{AttributeID: 1, Name: "Color", Type: "TEXT", IsRequired: true}}}}
	exec := &mockExec{}
	attrs := map[int]string{1: "Red"}
	if err := svc.validateAndSaveAttributes(exec, 1, 1, attrs); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(exec.queries) < 2 { // delete + insert
		t.Fatalf("expected queries to be executed, got %v", exec.queries)
	}
}

func TestValidateAndSaveAttributes_MissingRequired(t *testing.T) {
	svc := &ProductService{attributeService: &mockAttrProvider{defs: []models.ProductAttributeDefinition{{AttributeID: 1, Name: "Color", Type: "TEXT", IsRequired: true}}}}
	exec := &mockExec{}
	err := svc.validateAndSaveAttributes(exec, 1, 1, map[int]string{})
	if err == nil {
		t.Fatalf("expected error for missing required attribute")
	}
}
