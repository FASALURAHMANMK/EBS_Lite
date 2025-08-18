package services

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"testing"

	"erp-backend/internal/models"
)

var lastExec struct {
	query string
	args  []driver.NamedValue
}

type mockDriver struct{}

func (d *mockDriver) Open(name string) (driver.Conn, error) {
	return &mockConn{}, nil
}

type mockConn struct{}

func (c *mockConn) Prepare(query string) (driver.Stmt, error) {
	return nil, errors.New("not implemented")
}
func (c *mockConn) Close() error              { return nil }
func (c *mockConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }

func (c *mockConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	lastExec.query = query
	lastExec.args = append([]driver.NamedValue(nil), args...)
	return mockResult{}, nil
}

type mockResult struct{}

func (r mockResult) LastInsertId() (int64, error) { return 0, nil }
func (r mockResult) RowsAffected() (int64, error) { return 1, nil }

func TestUpdateLocationMultipleFields(t *testing.T) {
	sql.Register("mock", &mockDriver{})
	db, err := sql.Open("mock", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	svc := &LocationService{db: db}

	name := "New Name"
	phone := "123456"
	req := &models.UpdateLocationRequest{
		Name:  &name,
		Phone: &phone,
	}

	lastExec.query = ""
	lastExec.args = nil

	err = svc.UpdateLocation(1, req)
	if err != nil {
		t.Fatalf("UpdateLocation returned error: %v", err)
	}

	expectedQuery := "UPDATE locations SET name = $1, phone = $2, updated_at = CURRENT_TIMESTAMP WHERE location_id = $3"
	if lastExec.query != expectedQuery {
		t.Fatalf("unexpected query: got %q, want %q", lastExec.query, expectedQuery)
	}

	if len(lastExec.args) != 3 ||
		lastExec.args[0].Value != name ||
		lastExec.args[1].Value != phone ||
		lastExec.args[2].Value != int64(1) && lastExec.args[2].Value != 1 {
		t.Fatalf("unexpected args: %#v", lastExec.args)
	}
}
