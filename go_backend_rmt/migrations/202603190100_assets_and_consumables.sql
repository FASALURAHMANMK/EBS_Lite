-- +goose Up

ALTER TABLE IF EXISTS products
  ADD COLUMN IF NOT EXISTS item_type VARCHAR(20) NOT NULL DEFAULT 'PRODUCT';

UPDATE products
SET item_type = 'PRODUCT'
WHERE COALESCE(TRIM(item_type), '') = '';

CREATE TABLE IF NOT EXISTS asset_categories (
  category_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  ledger_account_id INTEGER REFERENCES chart_of_accounts(account_id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_categories_company_name
  ON asset_categories(company_id, LOWER(TRIM(name)));

CREATE TABLE IF NOT EXISTS consumable_categories (
  category_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  ledger_account_id INTEGER REFERENCES chart_of_accounts(account_id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_consumable_categories_company_name
  ON consumable_categories(company_id, LOWER(TRIM(name)));

CREATE TABLE IF NOT EXISTS asset_register_entries (
  asset_entry_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
  asset_tag VARCHAR(100) NOT NULL,
  product_id INTEGER REFERENCES products(product_id) ON DELETE SET NULL,
  barcode_id INTEGER REFERENCES product_barcodes(barcode_id) ON DELETE SET NULL,
  category_id INTEGER REFERENCES asset_categories(category_id) ON DELETE SET NULL,
  item_name VARCHAR(255) NOT NULL,
  source_mode VARCHAR(20) NOT NULL,
  quantity NUMERIC(14,3) NOT NULL DEFAULT 1,
  unit_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_value NUMERIC(14,2) NOT NULL DEFAULT 0,
  acquisition_date TIMESTAMP NOT NULL,
  in_service_date TIMESTAMP,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  offset_account_id INTEGER REFERENCES chart_of_accounts(account_id) ON DELETE SET NULL,
  notes TEXT,
  serial_numbers TEXT[] NOT NULL DEFAULT '{}',
  batch_allocations JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_asset_source_mode CHECK (source_mode IN ('STOCK', 'DIRECT')),
  CONSTRAINT chk_asset_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISPOSED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_register_company_tag
  ON asset_register_entries(company_id, asset_tag);

CREATE INDEX IF NOT EXISTS idx_asset_register_company_location
  ON asset_register_entries(company_id, location_id, acquisition_date DESC);

CREATE TABLE IF NOT EXISTS consumable_entries (
  consumption_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
  entry_number VARCHAR(100) NOT NULL,
  category_id INTEGER REFERENCES consumable_categories(category_id) ON DELETE SET NULL,
  product_id INTEGER REFERENCES products(product_id) ON DELETE SET NULL,
  barcode_id INTEGER REFERENCES product_barcodes(barcode_id) ON DELETE SET NULL,
  item_name VARCHAR(255) NOT NULL,
  source_mode VARCHAR(20) NOT NULL,
  quantity NUMERIC(14,3) NOT NULL DEFAULT 1,
  unit_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
  consumed_at TIMESTAMP NOT NULL,
  offset_account_id INTEGER REFERENCES chart_of_accounts(account_id) ON DELETE SET NULL,
  notes TEXT,
  serial_numbers TEXT[] NOT NULL DEFAULT '{}',
  batch_allocations JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_consumable_source_mode CHECK (source_mode IN ('STOCK', 'DIRECT'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_consumable_entries_company_number
  ON consumable_entries(company_id, entry_number);

CREATE INDEX IF NOT EXISTS idx_consumable_entries_company_location
  ON consumable_entries(company_id, location_id, consumed_at DESC);

INSERT INTO chart_of_accounts (company_id, account_code, name, type, subtype, is_active)
SELECT c.company_id, v.account_code, v.name, v.type, v.subtype, TRUE
FROM companies c
JOIN (
  VALUES
    ('1210', 'Fixed Assets', 'ASSET', 'FIXED_ASSET'),
    ('6010', 'Consumables Expense', 'EXPENSE', 'CONSUMABLE_EXPENSE')
) AS v(account_code, name, type, subtype) ON TRUE
ON CONFLICT (company_id, account_code) DO NOTHING;

-- +goose Down
-- No-op.
