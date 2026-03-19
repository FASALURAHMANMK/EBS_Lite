-- +goose Up

ALTER TABLE IF EXISTS suppliers
  ADD COLUMN IF NOT EXISTS is_mercantile BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE IF EXISTS suppliers
  ADD COLUMN IF NOT EXISTS is_non_mercantile BOOLEAN NOT NULL DEFAULT FALSE;

-- +goose StatementBegin
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_suppliers_usage_type'
  ) THEN
    ALTER TABLE suppliers
      ADD CONSTRAINT chk_suppliers_usage_type
      CHECK (is_mercantile OR is_non_mercantile);
  END IF;
END $$;
-- +goose StatementEnd

ALTER TABLE IF EXISTS asset_register_entries
  ADD COLUMN IF NOT EXISTS supplier_id INTEGER REFERENCES suppliers(supplier_id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS consumable_entries
  ADD COLUMN IF NOT EXISTS supplier_id INTEGER REFERENCES suppliers(supplier_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_asset_register_entries_supplier
  ON asset_register_entries(company_id, supplier_id);

CREATE INDEX IF NOT EXISTS idx_consumable_entries_supplier
  ON consumable_entries(company_id, supplier_id);

-- +goose Down
-- No-op.
