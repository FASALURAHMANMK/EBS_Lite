-- +goose Up
ALTER TABLE inventory_movements
  ADD COLUMN IF NOT EXISTS combo_product_id INTEGER REFERENCES combo_products(combo_product_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_combo_product
  ON inventory_movements(combo_product_id, occurred_at DESC)
  WHERE combo_product_id IS NOT NULL;

ALTER TABLE sale_return_details
  ADD COLUMN IF NOT EXISTS combo_product_id INTEGER REFERENCES combo_products(combo_product_id);

CREATE INDEX IF NOT EXISTS idx_sale_return_details_combo_product
  ON sale_return_details(combo_product_id)
  WHERE combo_product_id IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_sale_return_details_combo_product;

ALTER TABLE sale_return_details
  DROP COLUMN IF EXISTS combo_product_id;

DROP INDEX IF EXISTS idx_inventory_movements_combo_product;

ALTER TABLE inventory_movements
  DROP COLUMN IF EXISTS combo_product_id;
