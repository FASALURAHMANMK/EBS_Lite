-- +goose Up

ALTER TABLE products
ADD COLUMN IF NOT EXISTS purchase_unit_id INTEGER REFERENCES units(unit_id);

ALTER TABLE products
ADD COLUMN IF NOT EXISTS selling_unit_id INTEGER REFERENCES units(unit_id);

ALTER TABLE products
ADD COLUMN IF NOT EXISTS purchase_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE';

ALTER TABLE products
ADD COLUMN IF NOT EXISTS selling_uom_mode VARCHAR(10) NOT NULL DEFAULT 'LOOSE';

ALTER TABLE products
ADD COLUMN IF NOT EXISTS purchase_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0;

ALTER TABLE products
ADD COLUMN IF NOT EXISTS selling_to_stock_factor NUMERIC(12,6) NOT NULL DEFAULT 1.0;

ALTER TABLE products
ADD COLUMN IF NOT EXISTS is_weighable BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE products
SET purchase_unit_id = COALESCE(purchase_unit_id, unit_id),
    selling_unit_id = COALESCE(selling_unit_id, unit_id),
    purchase_uom_mode = COALESCE(NULLIF(BTRIM(purchase_uom_mode), ''), 'LOOSE'),
    selling_uom_mode = COALESCE(NULLIF(BTRIM(selling_uom_mode), ''), 'LOOSE'),
    purchase_to_stock_factor = COALESCE(purchase_to_stock_factor, 1.0),
    selling_to_stock_factor = COALESCE(selling_to_stock_factor, 1.0)
WHERE TRUE;

-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_purchase_uom_mode') THEN
        ALTER TABLE products
            ADD CONSTRAINT chk_products_purchase_uom_mode
            CHECK (purchase_uom_mode IN ('PACK', 'LOOSE'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_selling_uom_mode') THEN
        ALTER TABLE products
            ADD CONSTRAINT chk_products_selling_uom_mode
            CHECK (selling_uom_mode IN ('PACK', 'LOOSE'));
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down

ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_purchase_uom_mode;
ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_selling_uom_mode;
ALTER TABLE products DROP COLUMN IF EXISTS is_weighable;
ALTER TABLE products DROP COLUMN IF EXISTS selling_to_stock_factor;
ALTER TABLE products DROP COLUMN IF EXISTS purchase_to_stock_factor;
ALTER TABLE products DROP COLUMN IF EXISTS selling_uom_mode;
ALTER TABLE products DROP COLUMN IF EXISTS purchase_uom_mode;
ALTER TABLE products DROP COLUMN IF EXISTS selling_unit_id;
ALTER TABLE products DROP COLUMN IF EXISTS purchase_unit_id;
