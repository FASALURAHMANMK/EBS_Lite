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

var attrLastQuery string
var attrLastArgs []driver.NamedValue

type attrMockDriver struct{}

func (d *attrMockDriver) Open(name string) (driver.Conn, error) { return &attrMockConn{}, nil }

type attrMockConn struct{}

func (c *attrMockConn) Prepare(query string) (driver.Stmt, error) {
	return nil, errors.New("not implemented")
}
func (c *attrMockConn) Close() error              { return nil }
func (c *attrMockConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }
func (c *attrMockConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	attrLastQuery = query
	attrLastArgs = append([]driver.NamedValue(nil), args...)
	return &attrMockRows{}, nil
}

type attrMockRows struct{ returned bool }

func (r *attrMockRows) Columns() []string { return []string{"attribute_id", "created_at"} }
func (r *attrMockRows) Close() error      { return nil }
func (r *attrMockRows) Next(dest []driver.Value) error {
	if r.returned {
		return io.EOF
	}
	dest[0] = int64(1)
	dest[1] = time.Now()
	r.returned = true
	return nil
}

func TestCreateAttributeDefinition_IncludesFields(t *testing.T) {
	sql.Register("attrMock", &attrMockDriver{})
	db, err := sql.Open("attrMock", "")
	if err != nil {
		t.Fatalf("open mock: %v", err)
	}
	svc := &ProductAttributeService{db: db}
	req := &models.CreateProductAttributeDefinitionRequest{Name: "Color", Type: "TEXT", IsRequired: true}
	attrLastQuery = ""
	attrLastArgs = nil
	_, err = svc.CreateAttributeDefinition(1, req)
	if err != nil {
		t.Fatalf("CreateAttributeDefinition error: %v", err)
	}
	if !strings.Contains(attrLastQuery, "name, type, is_required, options") {
		t.Fatalf("unexpected query: %s", attrLastQuery)
	}
	if len(attrLastArgs) < 5 {
		t.Fatalf("expected 5 args, got %d", len(attrLastArgs))
	}
}
