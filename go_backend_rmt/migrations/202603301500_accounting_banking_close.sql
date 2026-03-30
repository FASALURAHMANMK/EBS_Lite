-- +goose Up
-- +goose StatementBegin

CREATE TABLE IF NOT EXISTS bank_accounts (
  bank_account_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  ledger_account_id INTEGER NOT NULL REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT,
  default_location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
  account_name VARCHAR(255) NOT NULL,
  bank_name VARCHAR(255) NOT NULL,
  account_number_masked VARCHAR(64),
  branch_name VARCHAR(255),
  currency_code VARCHAR(16),
  statement_import_hint VARCHAR(120),
  opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_accounts_company_name
  ON bank_accounts(company_id, LOWER(TRIM(account_name)));

CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_accounts_company_ledger
  ON bank_accounts(company_id, ledger_account_id);

CREATE TABLE IF NOT EXISTS accounting_periods (
  period_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  period_name VARCHAR(20) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
  checklist JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,
  closed_at TIMESTAMP,
  closed_by INTEGER REFERENCES users(user_id),
  reopened_at TIMESTAMP,
  reopened_by INTEGER REFERENCES users(user_id),
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_accounting_periods_company_range
  ON accounting_periods(company_id, start_date, end_date);

CREATE TABLE IF NOT EXISTS bank_statement_entries (
  statement_entry_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  bank_account_id INTEGER NOT NULL REFERENCES bank_accounts(bank_account_id) ON DELETE CASCADE,
  entry_date DATE NOT NULL,
  value_date DATE,
  description TEXT,
  reference VARCHAR(150),
  external_ref VARCHAR(150),
  source_type VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK (source_type IN ('MANUAL', 'IMPORT')),
  deposit_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  withdrawal_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  running_balance NUMERIC(14,2),
  status VARCHAR(20) NOT NULL DEFAULT 'UNMATCHED' CHECK (status IN ('UNMATCHED', 'MATCHED', 'REVIEW')),
  review_reason TEXT,
  idempotency_key VARCHAR(100),
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_statement_entries_idempotency
  ON bank_statement_entries(company_id, bank_account_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE INDEX IF NOT EXISTS idx_bank_statement_entries_lookup
  ON bank_statement_entries(company_id, bank_account_id, entry_date DESC, status)
  WHERE is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS bank_reconciliation_matches (
  match_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  bank_account_id INTEGER NOT NULL REFERENCES bank_accounts(bank_account_id) ON DELETE CASCADE,
  statement_entry_id INTEGER NOT NULL REFERENCES bank_statement_entries(statement_entry_id) ON DELETE CASCADE,
  ledger_entry_id INTEGER NOT NULL REFERENCES ledger_entries(entry_id) ON DELETE CASCADE,
  matched_amount NUMERIC(14,2) NOT NULL CHECK (matched_amount > 0),
  match_kind VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK (match_kind IN ('MANUAL', 'ADJUSTMENT')),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_reconciliation_unique_pair
  ON bank_reconciliation_matches(statement_entry_id, ledger_entry_id)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_bank_reconciliation_statement
  ON bank_reconciliation_matches(company_id, bank_account_id, statement_entry_id)
  WHERE is_deleted = FALSE;

ALTER TABLE IF EXISTS vouchers
  ADD COLUMN IF NOT EXISTS settlement_account_id INTEGER REFERENCES chart_of_accounts(account_id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS vouchers
  ADD COLUMN IF NOT EXISTS bank_account_id INTEGER REFERENCES bank_accounts(bank_account_id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS vouchers
  ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_vouchers_company_idempotency
  ON vouchers(company_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE TABLE IF NOT EXISTS voucher_lines (
  line_id SERIAL PRIMARY KEY,
  voucher_id INTEGER NOT NULL REFERENCES vouchers(voucher_id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  account_id INTEGER NOT NULL REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT,
  line_no INTEGER NOT NULL,
  debit NUMERIC(14,2) NOT NULL DEFAULT 0,
  credit NUMERIC(14,2) NOT NULL DEFAULT 0,
  description TEXT,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  updated_by INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_voucher_lines_amounts CHECK (
    (CASE WHEN debit > 0 THEN 1 ELSE 0 END) +
    (CASE WHEN credit > 0 THEN 1 ELSE 0 END) = 1
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_voucher_lines_unique_no
  ON voucher_lines(voucher_id, line_no);

INSERT INTO voucher_lines (voucher_id, company_id, account_id, line_no, debit, credit, description, created_by, updated_by)
SELECT
  v.voucher_id,
  v.company_id,
  v.account_id,
  1,
  CASE WHEN LOWER(v.type) = 'payment' THEN v.amount ELSE 0 END,
  CASE WHEN LOWER(v.type) = 'receipt' THEN v.amount ELSE 0 END,
  v.description,
  v.created_by,
  v.updated_by
FROM vouchers v
WHERE LOWER(v.type) IN ('payment', 'receipt')
  AND NOT EXISTS (
    SELECT 1 FROM voucher_lines vl WHERE vl.voucher_id = v.voucher_id
  );

INSERT INTO voucher_lines (voucher_id, company_id, account_id, line_no, debit, credit, description, created_by, updated_by)
SELECT
  v.voucher_id,
  v.company_id,
  COALESCE(v.settlement_account_id, cash.account_id),
  2,
  CASE WHEN LOWER(v.type) = 'receipt' THEN v.amount ELSE 0 END,
  CASE WHEN LOWER(v.type) = 'payment' THEN v.amount ELSE 0 END,
  v.description,
  v.created_by,
  v.updated_by
FROM vouchers v
JOIN chart_of_accounts cash
  ON cash.company_id = v.company_id
 AND cash.account_code = '1000'
WHERE LOWER(v.type) IN ('payment', 'receipt')
  AND NOT EXISTS (
    SELECT 1 FROM voucher_lines vl
    WHERE vl.voucher_id = v.voucher_id AND vl.line_no = 2
  );

INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_BANK_ACCOUNTS', 'View bank accounts and statements', 'banking', 'view'),
  ('MANAGE_BANK_ACCOUNTS', 'Create and update bank accounts and statements', 'banking', 'manage'),
  ('RECONCILE_BANK_STATEMENTS', 'Match and review bank statement entries', 'banking', 'reconcile'),
  ('VIEW_ACCOUNTING_PERIODS', 'View accounting periods and close status', 'accounting_periods', 'view'),
  ('MANAGE_ACCOUNTING_PERIODS', 'Close and reopen accounting periods', 'accounting_periods', 'manage'),
  ('VIEW_CHART_OF_ACCOUNTS', 'View chart of accounts', 'chart_of_accounts', 'view'),
  ('MANAGE_CHART_OF_ACCOUNTS', 'Create and update chart of accounts', 'chart_of_accounts', 'manage')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.name IN ('Super Admin', 'Admin')
  AND p.name IN (
    'VIEW_BANK_ACCOUNTS',
    'MANAGE_BANK_ACCOUNTS',
    'RECONCILE_BANK_STATEMENTS',
    'VIEW_ACCOUNTING_PERIODS',
    'MANAGE_ACCOUNTING_PERIODS',
    'VIEW_CHART_OF_ACCOUNTS',
    'MANAGE_CHART_OF_ACCOUNTS'
  )
ON CONFLICT DO NOTHING;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_voucher_lines_unique_no;
DROP TABLE IF EXISTS voucher_lines;

DROP INDEX IF EXISTS idx_vouchers_company_idempotency;
ALTER TABLE IF EXISTS vouchers DROP COLUMN IF EXISTS idempotency_key;
ALTER TABLE IF EXISTS vouchers DROP COLUMN IF EXISTS bank_account_id;
ALTER TABLE IF EXISTS vouchers DROP COLUMN IF EXISTS settlement_account_id;

DROP INDEX IF EXISTS idx_bank_reconciliation_statement;
DROP INDEX IF EXISTS idx_bank_reconciliation_unique_pair;
DROP TABLE IF EXISTS bank_reconciliation_matches;

DROP INDEX IF EXISTS idx_bank_statement_entries_lookup;
DROP INDEX IF EXISTS idx_bank_statement_entries_idempotency;
DROP TABLE IF EXISTS bank_statement_entries;

DROP INDEX IF EXISTS idx_accounting_periods_company_range;
DROP TABLE IF EXISTS accounting_periods;

DROP INDEX IF EXISTS idx_bank_accounts_company_ledger;
DROP INDEX IF EXISTS idx_bank_accounts_company_name;
DROP TABLE IF EXISTS bank_accounts;

-- Permissions are intentionally retained on downgrade.

-- +goose StatementEnd
