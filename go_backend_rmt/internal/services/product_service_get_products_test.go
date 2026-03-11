package services

import (
	"database/sql/driver"
	"testing"
	"time"
)

func productRowWithID(id int, name string) []driver.Value {
	return []driver.Value{
		id, 1, nil, nil, nil, nil, nil, "LOOSE", "LOOSE", 1.0, 1.0, false, name, nil, nil, nil, nil, 0, nil, nil, false, true, 1, nil, 1, time.Now(), time.Now(), false,
	}
}

func TestGetProducts_BatchedBarcodesAndAttributes(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM products": {
			columns: []string{"product_id", "company_id", "category_id", "brand_id", "unit_id", "purchase_unit_id", "selling_unit_id", "purchase_uom_mode", "selling_uom_mode", "purchase_to_stock_factor", "selling_to_stock_factor", "is_weighable", "name", "sku", "description", "cost_price", "selling_price", "reorder_level", "weight", "dimensions", "is_serialized", "is_active", "created_by", "updated_by", "sync_status", "created_at", "updated_at", "is_deleted"},
			rows: [][]driver.Value{
				productRowWithID(1, "First"),
				productRowWithID(2, "Second"),
			},
		},
		"FROM product_barcodes": {
			columns: []string{"barcode_id", "product_id", "barcode", "pack_size", "cost_price", "selling_price", "is_primary"},
			rows: [][]driver.Value{
				{1, 1, "ABC", 1, 10.0, 12.0, true},
				{2, 1, "ABC-2", 2, 9.5, 11.5, false},
				{3, 2, "DEF", 1, 20.0, 25.0, true},
			},
		},
		"FROM product_attribute_values": {
			columns: []string{"attribute_id", "product_id", "value", "company_id", "name", "type", "is_required", "options"},
			rows: [][]driver.Value{
				{1, 1, "Red", 1, "Color", "TEXT", false, nil},
				{2, 2, "Large", 1, "Size", "TEXT", false, nil},
			},
		},
	})

	svc := &ProductService{db: db}
	products, err := svc.GetProducts(1, map[string]string{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(products) != 2 {
		t.Fatalf("expected 2 products, got %d", len(products))
	}

	byID := make(map[int]struct {
		barcodes   int
		attributes int
	})
	for _, p := range products {
		byID[p.ProductID] = struct {
			barcodes   int
			attributes int
		}{
			barcodes:   len(p.Barcodes),
			attributes: len(p.Attributes),
		}
	}

	if got := byID[1]; got.barcodes != 2 || got.attributes != 1 {
		t.Fatalf("unexpected product 1 counts: %+v", got)
	}
	if got := byID[2]; got.barcodes != 1 || got.attributes != 1 {
		t.Fatalf("unexpected product 2 counts: %+v", got)
	}
}
