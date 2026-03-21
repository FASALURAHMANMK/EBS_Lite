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
	queryResults         []int
	queries              []string
	txQueries            []string
	inTx                 bool
	committed            bool
	txBarcodeRows        [][]driver.Value
	referencedBarcodeIDs map[int]bool
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
		lower := strings.ToLower(query)
		if strings.HasPrefix(strings.ToUpper(strings.TrimSpace(query)), "INSERT INTO PRODUCTS") {
			return &barcodeMockRows{cols: []string{"product_id", "created_at"}, vals: [][]driver.Value{{int64(1), time.Now()}}}, nil
		}
		if strings.Contains(lower, "from product_barcodes") {
			rows := c.db.txBarcodeRows
			if len(rows) == 0 {
				rows = [][]driver.Value{
					{int64(1), "111", int64(1), float64(0), float64(0), true, "Base", []byte(`{}`), true},
				}
			}
			return &barcodeMockRows{
				cols: []string{"barcode_id", "barcode", "pack_size", "cost_price", "selling_price", "is_primary", "variant_name", "variant_attributes", "is_active"},
				vals: rows,
			}, nil
		}
		if strings.Contains(lower, "select exists") {
			referenced := false
			if len(args) > 0 {
				switch id := args[0].Value.(type) {
				case int64:
					referenced = c.db.referencedBarcodeIDs[int(id)]
				case int:
					referenced = c.db.referencedBarcodeIDs[id]
				}
			}
			return &barcodeMockRows{cols: []string{"exists"}, vals: [][]driver.Value{{referenced}}}, nil
		}
		return &barcodeMockRows{cols: []string{"id"}, vals: [][]driver.Value{{int64(1)}}}, nil
	}
	c.db.queries = append(c.db.queries, query)
	lower := strings.ToLower(query)
	if strings.HasPrefix(strings.TrimSpace(lower), "select count") {
		var res int
		if len(c.db.queryResults) > 0 {
			res = c.db.queryResults[0]
			c.db.queryResults = c.db.queryResults[1:]
		}
		return &barcodeMockRows{cols: []string{"count"}, vals: [][]driver.Value{{int64(res)}}}, nil
	}
	if strings.Contains(lower, "from products") {
		if strings.Contains(lower, "default_supplier_id") || strings.Contains(lower, "tax_id") {
			cols := []string{"product_id", "company_id", "item_type", "category_id", "brand_id", "unit_id", "purchase_unit_id", "selling_unit_id", "purchase_uom_mode", "selling_uom_mode", "purchase_to_stock_factor", "selling_to_stock_factor", "is_weighable", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "has_warranty", "warranty_period_months", "is_serialized", "tracking_type", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted", "default_supplier_id", "tax_id"}
			vals := []driver.Value{int64(1), int64(1), "PRODUCT", nil, nil, nil, nil, nil, "LOOSE", "LOOSE", float64(1), float64(1), false, "name", "sku", "desc", float64(0), float64(0), int64(0), nil, nil, false, nil, false, "VARIANT", true, int64(1), nil, "synced", time.Now(), time.Now(), false, nil, int64(1)}
			return &barcodeMockRows{cols: cols, vals: [][]driver.Value{vals}}, nil
		}

		cols := []string{"product_id", "company_id", "item_type", "category_id", "brand_id", "unit_id", "purchase_unit_id", "selling_unit_id", "purchase_uom_mode", "selling_uom_mode", "purchase_to_stock_factor", "selling_to_stock_factor", "is_weighable", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "has_warranty", "warranty_period_months", "is_serialized", "tracking_type", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted", "default_supplier_id", "tax_id"}
		vals := []driver.Value{int64(1), int64(1), "PRODUCT", nil, nil, nil, nil, nil, "LOOSE", "LOOSE", float64(1), float64(1), false, "name", "sku", "desc", float64(0), float64(0), int64(0), nil, nil, false, nil, false, "VARIANT", true, int64(1), nil, "synced", time.Now(), time.Now(), false, nil, int64(1)}
		return &barcodeMockRows{cols: cols, vals: [][]driver.Value{vals}}, nil
	}
	if strings.Contains(lower, "from product_barcodes") {
		cols := []string{"barcode_id", "product_id", "barcode", "pack_size", "cost_price", "selling_price", "is_primary", "variant_name", "variant_attributes", "is_active"}
		vals := []driver.Value{int64(1), int64(1), "111", int64(1), float64(0), float64(0), true, "Base", []byte(`{}`), true}
		return &barcodeMockRows{cols: cols, vals: [][]driver.Value{vals}}, nil
	}
	if strings.Contains(lower, "from product_attribute_values") {
		cols := []string{"attribute_id", "product_id", "value", "company_id", "name", "type", "is_required", "options"}
		vals := []driver.Value{int64(1), int64(1), "val", int64(1), "attr", "TEXT", true, nil}
		return &barcodeMockRows{cols: cols, vals: [][]driver.Value{vals}}, nil
	}
	return &barcodeMockRows{cols: []string{"count"}, vals: [][]driver.Value{{int64(0)}}}, nil
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
	m := &barcodeMockDB{
		queryResults:         results,
		referencedBarcodeIDs: map[int]bool{},
	}
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
			{BarcodeID: 1, Barcode: "111", IsPrimary: true, IsActive: true},
			{Barcode: "222", IsPrimary: false, IsActive: true},
		},
	}
	if _, err := svc.UpdateProduct(1, 1, 1, req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(mock.queries) != 5 {
		t.Fatalf("expected 5 pre-update queries, got %d", len(mock.queries))
	}
	if !contains(mock.txQueries, "update products set") {
		t.Fatalf("missing product update: %v", mock.txQueries)
	}
	if countContains(mock.txQueries, "update product_barcodes") < 2 {
		t.Fatalf("expected barcode updates, got %v", mock.txQueries)
	}
	if contains(mock.txQueries, "delete from product_barcodes") {
		t.Fatalf("unexpected barcode delete: %v", mock.txQueries)
	}
	if countContains(mock.txQueries, "insert into product_barcodes") != 1 {
		t.Fatalf("expected 1 barcode insert, got %v", mock.txQueries)
	}
}

func TestUpdateProduct_DeactivatesReferencedRemovedBarcode(t *testing.T) {
	db, mock, err := newBarcodeMockDB([]int{0})
	if err != nil {
		t.Fatalf("mock db: %v", err)
	}
	mock.txBarcodeRows = [][]driver.Value{
		{int64(1), "111", int64(1), float64(0), float64(0), true, "Base", []byte(`{}`), true},
		{int64(2), "222", int64(1), float64(0), float64(0), false, "Promo", []byte(`{}`), true},
	}
	mock.referencedBarcodeIDs[1] = true

	svc := &ProductService{db: db}
	name := "Updated"
	req := &models.UpdateProductRequest{
		Name: &name,
		Barcodes: []models.ProductBarcode{
			{BarcodeID: 2, Barcode: "222", IsPrimary: true, IsActive: true},
		},
	}
	if _, err := svc.UpdateProduct(1, 1, 1, req); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !contains(mock.txQueries, "select exists") {
		t.Fatalf("missing barcode reference check: %v", mock.txQueries)
	}
	if contains(mock.txQueries, "delete from product_barcodes where barcode_id = $1 and product_id = $2") {
		t.Fatalf("referenced barcode should not be deleted: %v", mock.txQueries)
	}
	if !contains(mock.txQueries, "is_active = false") {
		t.Fatalf("missing referenced barcode deactivation: %v", mock.txQueries)
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
	if _, err := svc.UpdateProduct(1, 1, 1, req); err == nil {
		t.Fatalf("expected duplicate barcode error")
	}
}
