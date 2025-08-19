package services

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"erp-backend/internal/models"
)

type barcodeMockAttrProvider struct{}

func (m *barcodeMockAttrProvider) GetAttributeDefinitions(companyID int) ([]models.ProductAttributeDefinition, error) {
	return nil, nil
}

type barcodeMockDB struct {
	queryResults []int
	queries      []string
	txQueries    []string
	inTx         bool
	committed    bool
}

type barcodeMockDriver struct{ db *barcodeMockDB }

func (d *barcodeMockDriver) Open(name string) (driver.Conn, error) {
	return &barcodeMockConn{db: d.db}, nil
}

type barcodeMockConn struct{ db *barcodeMockDB }

func (c *barcodeMockConn) Prepare(query string) (driver.Stmt, error) {
	return nil, errors.New("not implemented")
}
func (c *barcodeMockConn) Close() error { return nil }
func (c *barcodeMockConn) Begin() (driver.Tx, error) {
	c.db.inTx = true
	return &barcodeMockTx{db: c.db}, nil
}

func (c *barcodeMockConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	if c.db.inTx {
		c.db.txQueries = append(c.db.txQueries, query)
	} else {
		c.db.queries = append(c.db.queries, query)
	}
	return barcodeMockResult{1}, nil
}

func (c *barcodeMockConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	if c.db.inTx {
		c.db.txQueries = append(c.db.txQueries, query)
		if strings.HasPrefix(strings.ToUpper(strings.TrimSpace(query)), "INSERT INTO PRODUCTS") {
			return &barcodeMockRows{cols: []string{"product_id", "created_at"}, vals: [][]driver.Value{{int64(1), time.Now()}}}, nil
		}
		return &barcodeMockRows{cols: []string{"id"}, vals: [][]driver.Value{{int64(1)}}}, nil
	}
	c.db.queries = append(c.db.queries, query)
	var res int
	if len(c.db.queryResults) > 0 {
		res = c.db.queryResults[0]
		c.db.queryResults = c.db.queryResults[1:]
	}
	return &barcodeMockRows{cols: []string{"count"}, vals: [][]driver.Value{{int64(res)}}}, nil
}

func (c *barcodeMockConn) CheckNamedValue(*driver.NamedValue) error { return nil }

func (c *barcodeMockConn) ResetSession(ctx context.Context) error { return nil }

func (c *barcodeMockConn) Ping(ctx context.Context) error { return nil }

type barcodeMockTx struct{ db *barcodeMockDB }

func (tx *barcodeMockTx) Commit() error {
	tx.db.inTx = false
	tx.db.committed = true
	return nil
}
func (tx *barcodeMockTx) Rollback() error {
	tx.db.inTx = false
	return nil
}

type barcodeMockResult struct{ rows int64 }

func (r barcodeMockResult) LastInsertId() (int64, error) { return 0, nil }
func (r barcodeMockResult) RowsAffected() (int64, error) { return r.rows, nil }

type barcodeMockRows struct {
	cols []string
	vals [][]driver.Value
	idx  int
}

func (r *barcodeMockRows) Columns() []string { return r.cols }
func (r *barcodeMockRows) Close() error      { return nil }
func (r *barcodeMockRows) Next(dest []driver.Value) error {
	if r.idx >= len(r.vals) {
		return io.EOF
	}
	copy(dest, r.vals[r.idx])
	r.idx++
	return nil
}

var drvCount int64

func newBarcodeMockDB(results []int) (*sql.DB, *barcodeMockDB, error) {
	m := &barcodeMockDB{queryResults: results}
	name := fmt.Sprintf("mockdrv_%d", atomic.AddInt64(&drvCount, 1))
	sql.Register(name, &barcodeMockDriver{db: m})
	db, err := sql.Open(name, "")
	if err != nil {
		return nil, nil, err
	}
	return db, m, nil
}

func contains(qs []string, sub string) bool {
	for _, q := range qs {
		if strings.Contains(strings.ToLower(q), strings.ToLower(sub)) {
			return true
		}
	}
	return false
}

func countContains(qs []string, sub string) int {
	n := 0
	for _, q := range qs {
		if strings.Contains(strings.ToLower(q), strings.ToLower(sub)) {
			n++
		}
	}
	return n
}

func TestCreateProduct_InsertsMultipleBarcodes(t *testing.T) {
	db, mock, err := newBarcodeMockDB([]int{0, 0})
	if err != nil {
		t.Fatalf("mock db: %v", err)
	}
	svc := &ProductService{db: db, attributeService: &barcodeMockAttrProvider{}}
	req := &models.CreateProductRequest{
		Name: "Test",
		Barcodes: []models.ProductBarcode{
			{Barcode: "111", IsPrimary: true},
			{Barcode: "222", IsPrimary: false},
		},
		Attributes: map[int]string{},
	}
	if _, err := svc.CreateProduct(1, 1, req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if countContains(mock.queries, "select count(*)") != 2 {
		t.Fatalf("expected 2 existence checks, got %v", mock.queries)
	}
	if !contains(mock.txQueries, "insert into products") {
		t.Fatalf("missing product insert: %v", mock.txQueries)
	}
	if countContains(mock.txQueries, "insert into product_barcodes") != 2 {
		t.Fatalf("expected 2 barcode inserts, got %v", mock.txQueries)
	}
	if !contains(mock.txQueries, "delete from product_attribute_values") {
		t.Fatalf("missing attribute cleanup: %v", mock.txQueries)
	}
	if !mock.committed {
		t.Fatalf("expected commit")
	}
}

func TestUpdateProduct_UpdatesBarcodes(t *testing.T) {
	db, mock, err := newBarcodeMockDB([]int{0, 0})
	if err != nil {
		t.Fatalf("mock db: %v", err)
	}
	svc := &ProductService{db: db}
	name := "Updated"
	req := &models.UpdateProductRequest{
		Name: &name,
		Barcodes: []models.ProductBarcode{
			{Barcode: "111", IsPrimary: true},
			{Barcode: "222", IsPrimary: false},
		},
	}
	if err := svc.UpdateProduct(1, 1, 1, req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(mock.queries) != 2 {
		t.Fatalf("expected 2 pre-update queries, got %d", len(mock.queries))
	}
	if !contains(mock.txQueries, "update products set") {
		t.Fatalf("missing product update: %v", mock.txQueries)
	}
	if !contains(mock.txQueries, "delete from product_barcodes") {
		t.Fatalf("missing barcode delete: %v", mock.txQueries)
	}
	if countContains(mock.txQueries, "insert into product_barcodes") != 2 {
		t.Fatalf("expected 2 barcode inserts, got %v", mock.txQueries)
	}
}

func TestCreateProduct_DuplicateBarcode(t *testing.T) {
	db, _, err := newBarcodeMockDB([]int{0, 1})
	if err != nil {
		t.Fatalf("mock db: %v", err)
	}
	svc := &ProductService{db: db}
	req := &models.CreateProductRequest{
		Name: "Test",
		Barcodes: []models.ProductBarcode{
			{Barcode: "111", IsPrimary: true},
			{Barcode: "222", IsPrimary: false},
		},
	}
	if _, err := svc.CreateProduct(1, 1, req); err == nil {
		t.Fatalf("expected duplicate barcode error")
	}
}

func TestUpdateProduct_DuplicateBarcode(t *testing.T) {
	db, _, err := newBarcodeMockDB([]int{0, 1})
	if err != nil {
		t.Fatalf("mock db: %v", err)
	}
	svc := &ProductService{db: db}
	name := "Updated"
	req := &models.UpdateProductRequest{
		Name: &name,
		Barcodes: []models.ProductBarcode{
			{Barcode: "111", IsPrimary: true},
			{Barcode: "222", IsPrimary: false},
		},
	}
	if err := svc.UpdateProduct(1, 1, 1, req); err == nil {
		t.Fatalf("expected duplicate barcode error")
	}
}
