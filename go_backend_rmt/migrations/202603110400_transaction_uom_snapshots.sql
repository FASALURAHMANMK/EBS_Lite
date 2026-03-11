-- +goose Up
ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS stock_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS selling_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS selling_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE',
  ADD COLUMN IF NOT EXISTS selling_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0;

ALTER TABLE purchase_details
  ADD COLUMN IF NOT EXISTS stock_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS purchase_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS purchase_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE',
  ADD COLUMN IF NOT EXISTS purchase_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0;

ALTER TABLE sale_return_details
  ADD COLUMN IF NOT EXISTS stock_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS selling_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS selling_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE',
  ADD COLUMN IF NOT EXISTS selling_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0;

ALTER TABLE purchase_return_details
  ADD COLUMN IF NOT EXISTS stock_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS purchase_unit_id INTEGER REFERENCES units(unit_id),
  ADD COLUMN IF NOT EXISTS purchase_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE',
  ADD COLUMN IF NOT EXISTS purchase_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0;

UPDATE sale_details sd
SET stock_unit_id = COALESCE(sd.stock_unit_id, p.unit_id),
    selling_unit_id = COALESCE(sd.selling_unit_id, p.selling_unit_id, p.unit_id),
    selling_uom_mode = COALESCE(NULLIF(BTRIM(sd.selling_uom_mode), ''), NULLIF(BTRIM(p.selling_uom_mode), ''), 'LOOSE'),
    selling_to_stock_factor = COALESCE(NULLIF(sd.selling_to_stock_factor, 0), p.selling_to_stock_factor, 1.0),
    stock_quantity = CASE
      WHEN COALESCE(sd.stock_quantity, 0) = 0 THEN COALESCE(sd.quantity, 0) * COALESCE(NULLIF(sd.selling_to_stock_factor, 0), p.selling_to_stock_factor, 1.0)
      ELSE sd.stock_quantity
    END
FROM products p
WHERE p.product_id = sd.product_id;

UPDATE purchase_details pd
SET stock_unit_id = COALESCE(pd.stock_unit_id, p.unit_id),
    purchase_unit_id = COALESCE(pd.purchase_unit_id, p.purchase_unit_id, p.unit_id),
    purchase_uom_mode = COALESCE(NULLIF(BTRIM(pd.purchase_uom_mode), ''), NULLIF(BTRIM(p.purchase_uom_mode), ''), 'LOOSE'),
    purchase_to_stock_factor = COALESCE(NULLIF(pd.purchase_to_stock_factor, 0), p.purchase_to_stock_factor, 1.0),
    stock_quantity = CASE
      WHEN COALESCE(pd.stock_quantity, 0) = 0 THEN COALESCE(pd.quantity, 0) * COALESCE(NULLIF(pd.purchase_to_stock_factor, 0), p.purchase_to_stock_factor, 1.0)
      ELSE pd.stock_quantity
    END
FROM products p
WHERE p.product_id = pd.product_id;

WITH sale_return_snapshot_src AS (
  SELECT
    srd.return_detail_id,
    COALESCE(srd.stock_unit_id, sd.stock_unit_id, p.unit_id) AS stock_unit_id,
    COALESCE(srd.selling_unit_id, sd.selling_unit_id, p.selling_unit_id, p.unit_id) AS selling_unit_id,
    COALESCE(NULLIF(BTRIM(srd.selling_uom_mode), ''), NULLIF(BTRIM(sd.selling_uom_mode), ''), NULLIF(BTRIM(p.selling_uom_mode), ''), 'LOOSE') AS selling_uom_mode,
    COALESCE(NULLIF(srd.selling_to_stock_factor, 0), NULLIF(sd.selling_to_stock_factor, 0), p.selling_to_stock_factor, 1.0) AS selling_to_stock_factor,
    CASE
      WHEN COALESCE(srd.stock_quantity, 0) = 0 THEN COALESCE(srd.quantity, 0) * COALESCE(NULLIF(srd.selling_to_stock_factor, 0), NULLIF(sd.selling_to_stock_factor, 0), p.selling_to_stock_factor, 1.0)
      ELSE srd.stock_quantity
    END AS stock_quantity
  FROM sale_return_details srd
  JOIN sale_returns sr ON sr.return_id = srd.return_id
  LEFT JOIN sale_details sd ON sd.sale_detail_id = srd.sale_detail_id
  LEFT JOIN products p ON p.product_id = srd.product_id
)
UPDATE sale_return_details srd
SET stock_unit_id = src.stock_unit_id,
    selling_unit_id = src.selling_unit_id,
    selling_uom_mode = src.selling_uom_mode,
    selling_to_stock_factor = src.selling_to_stock_factor,
    stock_quantity = src.stock_quantity
FROM sale_return_snapshot_src src
WHERE src.return_detail_id = srd.return_detail_id;

WITH purchase_return_snapshot_src AS (
  SELECT
    prd.return_detail_id,
    COALESCE(prd.stock_unit_id, pd.stock_unit_id, p.unit_id) AS stock_unit_id,
    COALESCE(prd.purchase_unit_id, pd.purchase_unit_id, p.purchase_unit_id, p.unit_id) AS purchase_unit_id,
    COALESCE(NULLIF(BTRIM(prd.purchase_uom_mode), ''), NULLIF(BTRIM(pd.purchase_uom_mode), ''), NULLIF(BTRIM(p.purchase_uom_mode), ''), 'LOOSE') AS purchase_uom_mode,
    COALESCE(NULLIF(prd.purchase_to_stock_factor, 0), NULLIF(pd.purchase_to_stock_factor, 0), p.purchase_to_stock_factor, 1.0) AS purchase_to_stock_factor,
    CASE
      WHEN COALESCE(prd.stock_quantity, 0) = 0 THEN COALESCE(prd.quantity, 0) * COALESCE(NULLIF(prd.purchase_to_stock_factor, 0), NULLIF(pd.purchase_to_stock_factor, 0), p.purchase_to_stock_factor, 1.0)
      ELSE prd.stock_quantity
    END AS stock_quantity
  FROM purchase_return_details prd
  JOIN purchase_returns pr ON pr.return_id = prd.return_id
  LEFT JOIN purchase_details pd ON pd.purchase_detail_id = prd.purchase_detail_id
  LEFT JOIN products p ON p.product_id = prd.product_id
)
UPDATE purchase_return_details prd
SET stock_unit_id = src.stock_unit_id,
    purchase_unit_id = src.purchase_unit_id,
    purchase_uom_mode = src.purchase_uom_mode,
    purchase_to_stock_factor = src.purchase_to_stock_factor,
    stock_quantity = src.stock_quantity
FROM purchase_return_snapshot_src src
WHERE src.return_detail_id = prd.return_detail_id;

ALTER TABLE sale_details DROP CONSTRAINT IF EXISTS chk_sale_details_selling_uom_mode;
ALTER TABLE sale_details
  ADD CONSTRAINT chk_sale_details_selling_uom_mode
  CHECK (selling_uom_mode IN ('PACK', 'LOOSE'));

ALTER TABLE purchase_details DROP CONSTRAINT IF EXISTS chk_purchase_details_purchase_uom_mode;
ALTER TABLE purchase_details
  ADD CONSTRAINT chk_purchase_details_purchase_uom_mode
  CHECK (purchase_uom_mode IN ('PACK', 'LOOSE'));

ALTER TABLE sale_return_details DROP CONSTRAINT IF EXISTS chk_sale_return_details_selling_uom_mode;
ALTER TABLE sale_return_details
  ADD CONSTRAINT chk_sale_return_details_selling_uom_mode
  CHECK (selling_uom_mode IN ('PACK', 'LOOSE'));

ALTER TABLE purchase_return_details DROP CONSTRAINT IF EXISTS chk_purchase_return_details_purchase_uom_mode;
ALTER TABLE purchase_return_details
  ADD CONSTRAINT chk_purchase_return_details_purchase_uom_mode
  CHECK (purchase_uom_mode IN ('PACK', 'LOOSE'));

-- +goose Down
ALTER TABLE purchase_return_details DROP CONSTRAINT IF EXISTS chk_purchase_return_details_purchase_uom_mode;
ALTER TABLE sale_return_details DROP CONSTRAINT IF EXISTS chk_sale_return_details_selling_uom_mode;
ALTER TABLE purchase_details DROP CONSTRAINT IF EXISTS chk_purchase_details_purchase_uom_mode;
ALTER TABLE sale_details DROP CONSTRAINT IF EXISTS chk_sale_details_selling_uom_mode;

ALTER TABLE purchase_return_details
  DROP COLUMN IF EXISTS stock_quantity,
  DROP COLUMN IF EXISTS purchase_to_stock_factor,
  DROP COLUMN IF EXISTS purchase_uom_mode,
  DROP COLUMN IF EXISTS purchase_unit_id,
  DROP COLUMN IF EXISTS stock_unit_id;

ALTER TABLE sale_return_details
  DROP COLUMN IF EXISTS stock_quantity,
  DROP COLUMN IF EXISTS selling_to_stock_factor,
  DROP COLUMN IF EXISTS selling_uom_mode,
  DROP COLUMN IF EXISTS selling_unit_id,
  DROP COLUMN IF EXISTS stock_unit_id;

ALTER TABLE purchase_details
  DROP COLUMN IF EXISTS stock_quantity,
  DROP COLUMN IF EXISTS purchase_to_stock_factor,
  DROP COLUMN IF EXISTS purchase_uom_mode,
  DROP COLUMN IF EXISTS purchase_unit_id,
  DROP COLUMN IF EXISTS stock_unit_id;

ALTER TABLE sale_details
  DROP COLUMN IF EXISTS stock_quantity,
  DROP COLUMN IF EXISTS selling_to_stock_factor,
  DROP COLUMN IF EXISTS selling_uom_mode,
  DROP COLUMN IF EXISTS selling_unit_id,
  DROP COLUMN IF EXISTS stock_unit_id;
