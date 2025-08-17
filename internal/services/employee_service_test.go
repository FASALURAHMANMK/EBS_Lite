package services

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"io"
	"strings"
	"testing"
	"time"

	"erp-backend/internal/models"
)

var empLastQuery string
var empLastArgs []driver.NamedValue

type empMockDriver struct{}

func (d *empMockDriver) Open(name string) (driver.Conn, error) {
	return &empMockConn{}, nil
}

type empMockConn struct{}

func (c *empMockConn) Prepare(query string) (driver.Stmt, error) {
	return nil, errors.New("not implemented")
}
func (c *empMockConn) Close() error              { return nil }
func (c *empMockConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }
func (c *empMockConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	empLastQuery = query
	empLastArgs = append([]driver.NamedValue(nil), args...)
	return &empMockRows{}, nil
}

type empMockRows struct{ returned bool }

func (r *empMockRows) Columns() []string { return []string{"employee_id", "created_at", "updated_at"} }
func (r *empMockRows) Close() error      { return nil }
func (r *empMockRows) Next(dest []driver.Value) error {
	if r.returned {
		return io.EOF
	}
	dest[0] = int64(1)
	dest[1] = time.Now()
	dest[2] = time.Now()
	r.returned = true
	return nil
}

func TestCreateEmployee_IncludesAuditFields(t *testing.T) {
	sql.Register("mockEmployee", &empMockDriver{})
	db, err := sql.Open("mockEmployee", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	svc := &EmployeeService{db: db}

	req := &models.CreateEmployeeRequest{Name: "John Doe"}
	userID := 42
	empLastQuery = ""
	empLastArgs = nil

	emp, err := svc.CreateEmployee(1, userID, req)
	if err != nil {
		t.Fatalf("CreateEmployee returned error: %v", err)
	}

	if !strings.Contains(empLastQuery, "created_by, updated_by") {
		t.Fatalf("query does not include audit fields: %s", empLastQuery)
	}
	if len(empLastArgs) < 14 {
		t.Fatalf("expected at least 14 args, got %d", len(empLastArgs))
	}
	if empLastArgs[13].Value != int64(userID) {
		t.Fatalf("expected userID %d in args, got %#v", userID, empLastArgs)
	}
	if emp.CreatedBy != userID {
		t.Fatalf("expected CreatedBy %d, got %d", userID, emp.CreatedBy)
	}
	if emp.UpdatedBy == nil || *emp.UpdatedBy != userID {
		t.Fatalf("expected UpdatedBy %d, got %v", userID, emp.UpdatedBy)
	}
}
