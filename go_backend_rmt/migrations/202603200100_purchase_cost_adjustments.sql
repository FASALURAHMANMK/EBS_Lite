-- +goose Up

ALTER TABLE goods_receipt_items
  ADD COLUMN IF NOT EXISTS purchase_detail_id INTEGER REFERENCES purchase_details(purchase_detail_id),
  ADD COLUMN IF NOT EXISTS barcode_id INTEGER REFERENCES product_barcodes(barcode_id);

CREATE INDEX IF NOT EXISTS idx_goods_receipt_items_purchase_detail
  ON goods_receipt_items(purchase_detail_id);

CREATE TABLE IF NOT EXISTS purchase_cost_adjustments (
  adjustment_id SERIAL PRIMARY KEY,
  adjustment_number VARCHAR(100) NOT NULL UNIQUE,
  adjustment_type VARCHAR(40) NOT NULL CHECK (adjustment_type IN ('GRN_ADDON', 'SUPPLIER_DEBIT_NOTE')),
  goods_receipt_id INTEGER REFERENCES goods_receipts(goods_receipt_id),
  purchase_id INTEGER REFERENCES purchases(purchase_id),
  location_id INTEGER NOT NULL REFERENCES locations(location_id),
  supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
  adjustment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  reference_number VARCHAR(100),
  notes TEXT,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  sync_status VARCHAR(20) DEFAULT 'synced',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustments_type_date
  ON purchase_cost_adjustments(adjustment_type, adjustment_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustments_supplier
  ON purchase_cost_adjustments(supplier_id, adjustment_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustments_purchase
  ON purchase_cost_adjustments(purchase_id, adjustment_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustments_goods_receipt
  ON purchase_cost_adjustments(goods_receipt_id);

CREATE TABLE IF NOT EXISTS purchase_cost_adjustment_items (
  adjustment_item_id SERIAL PRIMARY KEY,
  adjustment_id INTEGER NOT NULL REFERENCES purchase_cost_adjustments(adjustment_id) ON DELETE CASCADE,
  source_scope VARCHAR(20) NOT NULL CHECK (source_scope IN ('HEADER', 'ITEM')),
  goods_receipt_item_id INTEGER REFERENCES goods_receipt_items(goods_receipt_item_id),
  purchase_detail_id INTEGER REFERENCES purchase_details(purchase_detail_id),
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  barcode_id INTEGER REFERENCES product_barcodes(barcode_id),
  adjustment_label VARCHAR(255) NOT NULL,
  stock_action VARCHAR(20) NOT NULL CHECK (stock_action IN ('COST_ONLY', 'REDUCE_STOCK')),
  signed_amount NUMERIC(12,2) NOT NULL,
  quantity NUMERIC(12,3),
  stock_quantity NUMERIC(12,3),
  serial_numbers TEXT[],
  batch_allocations JSONB DEFAULT '[]'::jsonb,
  line_note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustment_items_adjustment
  ON purchase_cost_adjustment_items(adjustment_id);
CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustment_items_purchase_detail
  ON purchase_cost_adjustment_items(purchase_detail_id);
CREATE INDEX IF NOT EXISTS idx_purchase_cost_adjustment_items_product
  ON purchase_cost_adjustment_items(product_id);

INSERT INTO numbering_sequences (company_id, location_id, name, prefix, sequence_length, current_number)
SELECT c.company_id, NULL, 'purchase_cost_adjustment', 'PCA-', 6, 0
FROM companies c
WHERE NOT EXISTS (
  SELECT 1
  FROM numbering_sequences ns
  WHERE ns.company_id = c.company_id
    AND ns.location_id IS NULL
    AND ns.name = 'purchase_cost_adjustment'
);

INSERT INTO numbering_sequences (company_id, location_id, name, prefix, sequence_length, current_number)
SELECT c.company_id, NULL, 'supplier_debit_note', 'SDN-', 6, 0
FROM companies c
WHERE NOT EXISTS (
  SELECT 1
  FROM numbering_sequences ns
  WHERE ns.company_id = c.company_id
    AND ns.location_id IS NULL
    AND ns.name = 'supplier_debit_note'
);

-- +goose Down

DELETE FROM numbering_sequences WHERE name IN ('purchase_cost_adjustment', 'supplier_debit_note');

DROP INDEX IF EXISTS idx_purchase_cost_adjustment_items_product;
DROP INDEX IF EXISTS idx_purchase_cost_adjustment_items_purchase_detail;
DROP INDEX IF EXISTS idx_purchase_cost_adjustment_items_adjustment;
DROP TABLE IF EXISTS purchase_cost_adjustment_items;

DROP INDEX IF EXISTS idx_purchase_cost_adjustments_goods_receipt;
DROP INDEX IF EXISTS idx_purchase_cost_adjustments_purchase;
DROP INDEX IF EXISTS idx_purchase_cost_adjustments_supplier;
DROP INDEX IF EXISTS idx_purchase_cost_adjustments_type_date;
DROP TABLE IF EXISTS purchase_cost_adjustments;

DROP INDEX IF EXISTS idx_goods_receipt_items_purchase_detail;
ALTER TABLE goods_receipt_items
  DROP COLUMN IF EXISTS barcode_id,
  DROP COLUMN IF EXISTS purchase_detail_id;
