-- +goose Up
CREATE TABLE IF NOT EXISTS combo_products (
  combo_product_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  sku VARCHAR(100),
  barcode VARCHAR(100) NOT NULL,
  selling_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_id INTEGER NOT NULL REFERENCES taxes(tax_id),
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  sync_status VARCHAR(20) DEFAULT 'synced',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_combo_products_company_barcode
  ON combo_products(company_id, barcode)
  WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS ux_combo_products_company_sku
  ON combo_products(company_id, sku)
  WHERE sku IS NOT NULL AND is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS combo_product_items (
  combo_product_item_id SERIAL PRIMARY KEY,
  combo_product_id INTEGER NOT NULL REFERENCES combo_products(combo_product_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id),
  quantity NUMERIC(12,3) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_combo_product_items_combo_barcode
  ON combo_product_items(combo_product_id, barcode_id);

CREATE TABLE IF NOT EXISTS product_storage_assignments (
  storage_assignment_id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id) ON DELETE CASCADE,
  storage_type VARCHAR(50) NOT NULL,
  storage_label VARCHAR(100) NOT NULL,
  notes TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_product_storage_assignments_primary
  ON product_storage_assignments(location_id, barcode_id)
  WHERE is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_product_storage_assignments_product_location
  ON product_storage_assignments(product_id, location_id, barcode_id);

ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS combo_product_id INTEGER REFERENCES combo_products(combo_product_id);

ALTER TABLE quote_items
  ADD COLUMN IF NOT EXISTS combo_product_id INTEGER REFERENCES combo_products(combo_product_id);

CREATE TABLE IF NOT EXISTS sale_detail_combo_components (
  sale_detail_combo_component_id SERIAL PRIMARY KEY,
  sale_detail_id INTEGER NOT NULL REFERENCES sale_details(sale_detail_id) ON DELETE CASCADE,
  combo_product_id INTEGER NOT NULL REFERENCES combo_products(combo_product_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id),
  quantity NUMERIC(12,3) NOT NULL,
  unit_cost NUMERIC(12,4) NOT NULL DEFAULT 0,
  total_cost NUMERIC(12,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sale_detail_combo_components_sale_detail
  ON sale_detail_combo_components(sale_detail_id);

-- +goose Down
DROP INDEX IF EXISTS idx_sale_detail_combo_components_sale_detail;
DROP TABLE IF EXISTS sale_detail_combo_components;

ALTER TABLE quote_items
  DROP COLUMN IF EXISTS combo_product_id;

ALTER TABLE sale_details
  DROP COLUMN IF EXISTS combo_product_id;

DROP INDEX IF EXISTS idx_product_storage_assignments_product_location;
DROP INDEX IF EXISTS ux_product_storage_assignments_primary;
DROP TABLE IF EXISTS product_storage_assignments;

DROP INDEX IF EXISTS ux_combo_product_items_combo_barcode;
DROP TABLE IF EXISTS combo_product_items;

DROP INDEX IF EXISTS ux_combo_products_company_sku;
DROP INDEX IF EXISTS ux_combo_products_company_barcode;
DROP TABLE IF EXISTS combo_products;
