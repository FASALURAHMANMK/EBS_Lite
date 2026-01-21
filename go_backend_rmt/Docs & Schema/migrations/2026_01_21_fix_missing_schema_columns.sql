-- Fix missing columns required by backend schema validator.
-- Safe to run multiple times (uses IF EXISTS / IF NOT EXISTS).
-- Run in pgAdmin Query Tool against your target database.

BEGIN;

-- attendance
ALTER TABLE IF EXISTS attendance
    ADD COLUMN IF NOT EXISTS check_in TIMESTAMP,
    ADD COLUMN IF NOT EXISTS check_out TIMESTAMP,
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;

-- employees
ALTER TABLE IF EXISTS employees
    ADD COLUMN IF NOT EXISTS last_check_in TIMESTAMP,
    ADD COLUMN IF NOT EXISTS last_check_out TIMESTAMP,
    ADD COLUMN IF NOT EXISTS leave_balance NUMERIC(12,2) NOT NULL DEFAULT 0;

-- leaves
ALTER TABLE IF EXISTS leaves
    ADD COLUMN IF NOT EXISTS leave_id SERIAL,
    ADD COLUMN IF NOT EXISTS employee_id INTEGER,
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE,
    ADD COLUMN IF NOT EXISTS reason TEXT,
    ADD COLUMN IF NOT EXISTS status VARCHAR(50);

-- Backfill IDs when leave_id was newly added.
UPDATE leaves
SET leave_id = nextval(pg_get_serial_sequence('leaves', 'leave_id'))
WHERE leave_id IS NULL;

-- holidays
ALTER TABLE IF EXISTS holidays
    ADD COLUMN IF NOT EXISTS name VARCHAR(255) NOT NULL DEFAULT '';

-- expenses
ALTER TABLE IF EXISTS expenses
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- vouchers
ALTER TABLE IF EXISTS vouchers
    ADD COLUMN IF NOT EXISTS company_id INTEGER,
    ADD COLUMN IF NOT EXISTS account_id INTEGER;

-- Best-effort backfill company_id from chart_of_accounts when possible.
UPDATE vouchers v
SET company_id = coa.company_id
FROM chart_of_accounts coa
WHERE v.company_id IS NULL
  AND v.account_id = coa.account_id;

-- ledger_entries
ALTER TABLE IF EXISTS ledger_entries
    ADD COLUMN IF NOT EXISTS company_id INTEGER,
    ADD COLUMN IF NOT EXISTS reference VARCHAR(100);

-- Best-effort backfill company_id from chart_of_accounts when possible.
UPDATE ledger_entries le
SET company_id = coa.company_id
FROM chart_of_accounts coa
WHERE le.company_id IS NULL
  AND le.account_id = coa.account_id;

-- promotions
ALTER TABLE IF EXISTS promotions
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- customer_credit_transactions
ALTER TABLE IF EXISTS customer_credit_transactions
    ADD COLUMN IF NOT EXISTS transaction_id SERIAL,
    ADD COLUMN IF NOT EXISTS customer_id INTEGER,
    ADD COLUMN IF NOT EXISTS company_id INTEGER,
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS type VARCHAR(20),
    ADD COLUMN IF NOT EXISTS created_by INTEGER;

-- Backfill IDs when transaction_id was newly added.
UPDATE customer_credit_transactions
SET transaction_id = nextval(pg_get_serial_sequence('customer_credit_transactions', 'transaction_id'))
WHERE transaction_id IS NULL;

-- Best-effort backfill company_id from customers when possible.
UPDATE customer_credit_transactions cct
SET company_id = c.company_id
FROM customers c
WHERE cct.company_id IS NULL
  AND cct.customer_id = c.customer_id;

-- password_reset_tokens
ALTER TABLE IF EXISTS password_reset_tokens
    ADD COLUMN IF NOT EXISTS user_id INTEGER,
    ADD COLUMN IF NOT EXISTS token VARCHAR(255),
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP;

-- cash_register_tally
ALTER TABLE IF EXISTS cash_register_tally
    ADD COLUMN IF NOT EXISTS location_id INTEGER,
    ADD COLUMN IF NOT EXISTS count NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS recorded_by INTEGER;

-- salary_components
ALTER TABLE IF EXISTS salary_components
    ADD COLUMN IF NOT EXISTS payroll_id INTEGER,
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2);

-- payroll_advances
ALTER TABLE IF EXISTS payroll_advances
    ADD COLUMN IF NOT EXISTS payroll_id INTEGER,
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS date DATE;

-- payroll_deductions
ALTER TABLE IF EXISTS payroll_deductions
    ADD COLUMN IF NOT EXISTS payroll_id INTEGER,
    ADD COLUMN IF NOT EXISTS type VARCHAR(100),
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS date DATE;

COMMIT;

