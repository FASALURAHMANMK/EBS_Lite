-- +goose Up
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS tracking_type VARCHAR(20) NOT NULL DEFAULT 'VARIANT';

ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_tracking_type;
ALTER TABLE products
  ADD CONSTRAINT chk_products_tracking_type
  CHECK (tracking_type IN ('VARIANT', 'SERIAL', 'BATCH'));

UPDATE products
SET tracking_type = CASE
  WHEN COALESCE(is_serialized, FALSE) THEN 'SERIAL'
  ELSE 'VARIANT'
END
WHERE tracking_type IS NULL
   OR BTRIM(tracking_type) = ''
   OR tracking_type NOT IN ('VARIANT', 'SERIAL', 'BATCH');

ALTER TABLE product_barcodes
  ADD COLUMN IF NOT EXISTS variant_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS variant_attributes JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE purchase_details
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE purchase_return_details
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE sale_return_details
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE stock_transfer_details
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE stock_adjustment_document_items
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

ALTER TABLE stock_lots
  ADD COLUMN IF NOT EXISTS company_id INTEGER REFERENCES companies(company_id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

UPDATE purchase_details pd
SET barcode_id = src.barcode_id
FROM (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
WHERE pd.product_id = src.product_id
  AND pd.barcode_id IS NULL;

UPDATE sale_details sd
SET barcode_id = src.barcode_id
FROM (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
WHERE sd.product_id = src.product_id
  AND sd.barcode_id IS NULL;

UPDATE purchase_return_details prd
SET barcode_id = COALESCE(prd.barcode_id, pd.barcode_id, src.barcode_id)
FROM purchase_details pd
LEFT JOIN (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
  ON src.product_id = pd.product_id
WHERE prd.purchase_detail_id = pd.purchase_detail_id
  AND prd.barcode_id IS NULL;

UPDATE sale_return_details srd
SET barcode_id = COALESCE(srd.barcode_id, sd.barcode_id, src.barcode_id)
FROM sale_details sd
LEFT JOIN (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
  ON src.product_id = sd.product_id
WHERE srd.sale_detail_id = sd.sale_detail_id
  AND srd.barcode_id IS NULL;

UPDATE stock_transfer_details std
SET barcode_id = src.barcode_id
FROM (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
WHERE std.product_id = src.product_id
  AND std.barcode_id IS NULL;

UPDATE stock_adjustment_document_items sadi
SET barcode_id = src.barcode_id
FROM (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
WHERE sadi.product_id = src.product_id
  AND sadi.barcode_id IS NULL;

UPDATE stock_lots sl
SET company_id = p.company_id,
    barcode_id = COALESCE(sl.barcode_id, src.barcode_id)
FROM products p
LEFT JOIN (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src
  ON src.product_id = p.product_id
WHERE p.product_id = sl.product_id
  AND (sl.company_id IS NULL OR sl.barcode_id IS NULL);

CREATE TABLE IF NOT EXISTS stock_variants (
  stock_variant_id SERIAL PRIMARY KEY,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id) ON DELETE CASCADE,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  reserved_quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  average_cost NUMERIC(12,4) NOT NULL DEFAULT 0,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (location_id, barcode_id)
);

INSERT INTO stock_variants (location_id, product_id, barcode_id, quantity, reserved_quantity, average_cost, last_updated)
SELECT
  s.location_id,
  s.product_id,
  src.barcode_id,
  s.quantity,
  COALESCE(s.reserved_quantity, 0),
  COALESCE(p.cost_price, 0),
  COALESCE(s.last_updated, CURRENT_TIMESTAMP)
FROM stock s
JOIN products p ON p.product_id = s.product_id
JOIN (
  SELECT DISTINCT ON (pb.product_id)
    pb.product_id,
    pb.barcode_id
  FROM product_barcodes pb
  WHERE pb.is_primary = TRUE
  ORDER BY pb.product_id, pb.barcode_id
) AS src ON src.product_id = s.product_id
ON CONFLICT (location_id, barcode_id) DO UPDATE
SET quantity = EXCLUDED.quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    average_cost = EXCLUDED.average_cost,
    last_updated = EXCLUDED.last_updated;

CREATE TABLE IF NOT EXISTS product_serials (
  product_serial_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id) ON DELETE CASCADE,
  stock_lot_id INTEGER REFERENCES stock_lots(lot_id) ON DELETE SET NULL,
  serial_number VARCHAR(255) NOT NULL,
  location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'IN_STOCK',
  cost_price NUMERIC(12,4) NOT NULL DEFAULT 0,
  received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sold_at TIMESTAMP,
  last_movement_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (company_id, serial_number)
);

ALTER TABLE product_serials DROP CONSTRAINT IF EXISTS chk_product_serials_status;
ALTER TABLE product_serials
  ADD CONSTRAINT chk_product_serials_status
  CHECK (status IN ('IN_STOCK', 'SOLD', 'RETURNED', 'TRANSFER_IN_TRANSIT', 'ADJUSTED_OUT', 'VOID'));

CREATE TABLE IF NOT EXISTS inventory_movements (
  movement_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  barcode_id INTEGER NOT NULL REFERENCES product_barcodes(barcode_id) ON DELETE CASCADE,
  stock_lot_id INTEGER REFERENCES stock_lots(lot_id) ON DELETE SET NULL,
  product_serial_id INTEGER REFERENCES product_serials(product_serial_id) ON DELETE SET NULL,
  movement_type VARCHAR(40) NOT NULL,
  source_type VARCHAR(40) NOT NULL,
  source_line_id INTEGER,
  source_ref VARCHAR(100),
  quantity NUMERIC(12,3) NOT NULL,
  unit_cost NUMERIC(12,4) NOT NULL DEFAULT 0,
  total_cost NUMERIC(14,4) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by INTEGER REFERENCES users(user_id),
  occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_stock_variants_location_product ON stock_variants(location_id, product_id);
CREATE INDEX IF NOT EXISTS idx_stock_variants_location_barcode ON stock_variants(location_id, barcode_id);
CREATE INDEX IF NOT EXISTS idx_stock_lots_company_barcode ON stock_lots(company_id, location_id, product_id, barcode_id);
CREATE INDEX IF NOT EXISTS idx_product_serials_company_barcode_status ON product_serials(company_id, barcode_id, status);
CREATE INDEX IF NOT EXISTS idx_product_serials_company_product_status ON product_serials(company_id, product_id, status);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_company_product_time ON inventory_movements(company_id, product_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_source ON inventory_movements(source_type, source_line_id);

-- +goose Down
DROP INDEX IF EXISTS idx_inventory_movements_source;
DROP INDEX IF EXISTS idx_inventory_movements_company_product_time;
DROP INDEX IF EXISTS idx_product_serials_company_product_status;
DROP INDEX IF EXISTS idx_product_serials_company_barcode_status;
DROP INDEX IF EXISTS idx_stock_lots_company_barcode;
DROP INDEX IF EXISTS idx_stock_variants_location_barcode;
DROP INDEX IF EXISTS idx_stock_variants_location_product;

DROP TABLE IF EXISTS inventory_movements;
ALTER TABLE product_serials DROP CONSTRAINT IF EXISTS chk_product_serials_status;
DROP TABLE IF EXISTS product_serials;
DROP TABLE IF EXISTS stock_variants;

ALTER TABLE stock_lots
  DROP COLUMN IF EXISTS barcode_id,
  DROP COLUMN IF EXISTS company_id;

ALTER TABLE stock_adjustment_document_items
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE stock_transfer_details
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE sale_return_details
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE purchase_return_details
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE sale_details
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE purchase_details
  DROP COLUMN IF EXISTS barcode_id;

ALTER TABLE product_barcodes
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS variant_attributes,
  DROP COLUMN IF EXISTS variant_name;

ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_tracking_type;
ALTER TABLE products
  DROP COLUMN IF EXISTS tracking_type;
