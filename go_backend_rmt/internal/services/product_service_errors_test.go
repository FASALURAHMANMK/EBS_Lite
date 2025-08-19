package services

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"strings"
	"testing"
	"time"
)

// stub implementations of sql driver to control query responses

type stubResp struct {
	columns []string
	rows    [][]driver.Value
	err     error
}

type stubConnector struct{ responses map[string]stubResp }

func (c *stubConnector) Connect(ctx context.Context) (driver.Conn, error) {
	return &stubConn{responses: c.responses}, nil
}
func (c *stubConnector) Driver() driver.Driver { return stubDriver{} }

type stubDriver struct{}

func (stubDriver) Open(name string) (driver.Conn, error) { return nil, errors.New("not implemented") }

type stubConn struct{ responses map[string]stubResp }

func (c *stubConn) Prepare(query string) (driver.Stmt, error) {
	return nil, errors.New("not implemented")
}
func (c *stubConn) Close() error              { return nil }
func (c *stubConn) Begin() (driver.Tx, error) { return nil, errors.New("not implemented") }

func (c *stubConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	for pattern, resp := range c.responses {
		if strings.Contains(query, pattern) {
			if resp.err != nil {
				return nil, resp.err
			}
			return &stubRows{columns: resp.columns, values: resp.rows}, nil
		}
	}
	return nil, fmt.Errorf("unexpected query: %s", query)
}

// implement driver.Queryer for compatibility
func (c *stubConn) Query(query string, args []driver.Value) (driver.Rows, error) {
	named := make([]driver.NamedValue, len(args))
	for i, v := range args {
		named[i] = driver.NamedValue{Ordinal: i + 1, Value: v}
	}
	return c.QueryContext(context.Background(), query, named)
}

type stubRows struct {
	columns []string
	values  [][]driver.Value
	idx     int
}

func (r *stubRows) Columns() []string { return r.columns }
func (r *stubRows) Close() error      { return nil }
func (r *stubRows) Next(dest []driver.Value) error {
	if r.idx >= len(r.values) {
		return io.EOF
	}
	row := r.values[r.idx]
	for i := range dest {
		dest[i] = row[i]
	}
	r.idx++
	return nil
}

func mockDB(responses map[string]stubResp) *sql.DB {
	return sql.OpenDB(&stubConnector{responses: responses})
}

func productRow() []driver.Value {
	return []driver.Value{1, 1, nil, nil, nil, "Test", nil, nil, nil, nil, 0, nil, nil, false, true, 1, nil, 1, time.Now(), time.Now(), false}
}

func TestGetProducts_BarcodesError(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM products": {
			columns: []string{"product_id", "company_id", "category_id", "brand_id", "unit_id", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "is_serialized", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted"},
			rows:    [][]driver.Value{productRow()},
		},
		"FROM product_barcodes": {err: errors.New("barcode failure")},
	})
	svc := &ProductService{db: db}
	if _, err := svc.GetProducts(1, map[string]string{}); err == nil || !strings.Contains(err.Error(), "failed to get product barcodes") {
		t.Fatalf("expected barcode error, got %v", err)
	}
}

func TestGetProducts_AttributesError(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM products": {
			columns: []string{"product_id", "company_id", "category_id", "brand_id", "unit_id", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "is_serialized", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted"},
			rows:    [][]driver.Value{productRow()},
		},
		"FROM product_barcodes": {
			columns: []string{"barcode_id", "product_id", "barcode", "pack_size", "cost_price", "selling_price", "is_primary"},
			rows:    [][]driver.Value{},
		},
		"FROM product_attribute_values": {err: errors.New("attr failure")},
	})
	svc := &ProductService{db: db}
	if _, err := svc.GetProducts(1, map[string]string{}); err == nil || !strings.Contains(err.Error(), "failed to get product attributes") {
		t.Fatalf("expected attribute error, got %v", err)
	}
}

func TestGetProductByID_BarcodesError(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM products": {
			columns: []string{"product_id", "company_id", "category_id", "brand_id", "unit_id", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "is_serialized", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted"},
			rows:    [][]driver.Value{productRow()},
		},
		"FROM product_barcodes": {err: errors.New("barcode failure")},
	})
	svc := &ProductService{db: db}
	if _, err := svc.GetProductByID(1, 1); err == nil || !strings.Contains(err.Error(), "failed to get product barcodes") {
		t.Fatalf("expected barcode error, got %v", err)
	}
}

func TestGetProductByID_AttributesError(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM products": {
			columns: []string{"product_id", "company_id", "category_id", "brand_id", "unit_id", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "is_serialized", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted"},
			rows:    [][]driver.Value{productRow()},
		},
		"FROM product_barcodes": {
			columns: []string{"barcode_id", "product_id", "barcode", "pack_size", "cost_price", "selling_price", "is_primary"},
			rows:    [][]driver.Value{},
		},
		"FROM product_attribute_values": {err: errors.New("attr failure")},
	})
	svc := &ProductService{db: db}
	if _, err := svc.GetProductByID(1, 1); err == nil || !strings.Contains(err.Error(), "failed to get product attributes") {
		t.Fatalf("expected attribute error, got %v", err)
	}
}
