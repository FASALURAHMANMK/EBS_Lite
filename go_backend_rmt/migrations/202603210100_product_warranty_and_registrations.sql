-- +goose Up
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS has_warranty BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS warranty_period_months INTEGER;

UPDATE products
SET warranty_period_months = NULL
WHERE COALESCE(has_warranty, FALSE) = FALSE;

ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_warranty_config;
ALTER TABLE products
  ADD CONSTRAINT chk_products_warranty_config
  CHECK (
    (has_warranty = FALSE AND warranty_period_months IS NULL) OR
    (has_warranty = TRUE AND warranty_period_months IS NOT NULL AND warranty_period_months > 0)
  );

CREATE TABLE IF NOT EXISTS warranty_registrations (
  warranty_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
  sale_number VARCHAR(100) NOT NULL,
  customer_id INTEGER REFERENCES customers(customer_id) ON DELETE SET NULL,
  customer_name VARCHAR(255) NOT NULL,
  customer_phone VARCHAR(50),
  customer_email VARCHAR(255),
  customer_address TEXT,
  notes TEXT,
  registered_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by INTEGER REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS warranty_items (
  warranty_item_id SERIAL PRIMARY KEY,
  warranty_id INTEGER NOT NULL REFERENCES warranty_registrations(warranty_id) ON DELETE CASCADE,
  sale_detail_id INTEGER NOT NULL REFERENCES sale_details(sale_detail_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  barcode_id INTEGER REFERENCES product_barcodes(barcode_id) ON DELETE SET NULL,
  product_name VARCHAR(255) NOT NULL,
  barcode VARCHAR(100),
  variant_name VARCHAR(255),
  tracking_type VARCHAR(20) NOT NULL DEFAULT 'VARIANT',
  is_serialized BOOLEAN NOT NULL DEFAULT FALSE,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  serial_number VARCHAR(255),
  stock_lot_id INTEGER REFERENCES stock_lots(lot_id) ON DELETE SET NULL,
  batch_number VARCHAR(100),
  batch_expiry_date DATE,
  warranty_period_months INTEGER NOT NULL,
  warranty_start_date DATE NOT NULL,
  warranty_end_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE warranty_items DROP CONSTRAINT IF EXISTS chk_warranty_items_tracking_type;
ALTER TABLE warranty_items
  ADD CONSTRAINT chk_warranty_items_tracking_type
  CHECK (tracking_type IN ('VARIANT', 'SERIAL', 'BATCH'));

CREATE INDEX IF NOT EXISTS idx_products_has_warranty
  ON products(company_id, has_warranty)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_warranty_registrations_company_invoice
  ON warranty_registrations(company_id, sale_number)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_warranty_registrations_company_phone
  ON warranty_registrations(company_id, customer_phone)
  WHERE is_deleted = FALSE AND customer_phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_warranty_items_warranty
  ON warranty_items(warranty_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_warranty_items_serial
  ON warranty_items(sale_detail_id, serial_number)
  WHERE serial_number IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_warranty_items_batch
  ON warranty_items(sale_detail_id, stock_lot_id)
  WHERE stock_lot_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_warranty_items_line
  ON warranty_items(sale_detail_id)
  WHERE serial_number IS NULL AND stock_lot_id IS NULL;

DROP TRIGGER IF EXISTS update_warranty_registrations_updated_at ON warranty_registrations;
CREATE TRIGGER update_warranty_registrations_updated_at
BEFORE UPDATE ON warranty_registrations
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_warranty_items_updated_at ON warranty_items;
CREATE TRIGGER update_warranty_items_updated_at
BEFORE UPDATE ON warranty_items
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- +goose Down
DROP TRIGGER IF EXISTS update_warranty_items_updated_at ON warranty_items;
DROP TRIGGER IF EXISTS update_warranty_registrations_updated_at ON warranty_registrations;

DROP INDEX IF EXISTS ux_warranty_items_line;
DROP INDEX IF EXISTS ux_warranty_items_batch;
DROP INDEX IF EXISTS ux_warranty_items_serial;
DROP INDEX IF EXISTS idx_warranty_items_warranty;
DROP INDEX IF EXISTS idx_warranty_registrations_company_phone;
DROP INDEX IF EXISTS idx_warranty_registrations_company_invoice;
DROP INDEX IF EXISTS idx_products_has_warranty;

ALTER TABLE warranty_items DROP CONSTRAINT IF EXISTS chk_warranty_items_tracking_type;
DROP TABLE IF EXISTS warranty_items;
DROP TABLE IF EXISTS warranty_registrations;

ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_warranty_config;
ALTER TABLE products
  DROP COLUMN IF EXISTS warranty_period_months,
  DROP COLUMN IF EXISTS has_warranty;
