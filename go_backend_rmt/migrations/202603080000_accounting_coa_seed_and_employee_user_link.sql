-- +goose Up
-- Seed minimal Chart of Accounts for each company and link employees to app users.

-- employees: optional link to an app user (all app users must be employees, but not vice-versa)
ALTER TABLE IF EXISTS employees
  ADD COLUMN IF NOT EXISTS user_id INTEGER;

-- FK is best-effort (in case users table doesn't exist yet in some environments)
-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    BEGIN
      ALTER TABLE employees
        ADD CONSTRAINT employees_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL;
    EXCEPTION
      WHEN duplicate_object THEN
        -- constraint already exists
        NULL;
    END;
  END IF;
END;
$$;
-- +goose StatementEnd

-- Ensure one employee per user (when linked)
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_user_id_unique
  ON employees(user_id)
  WHERE user_id IS NOT NULL;

-- Backfill employees for existing app users (idempotent).
INSERT INTO employees (
  company_id, location_id, user_id, employee_code, name, phone, email,
  is_active, created_by, updated_by
)
SELECT
  u.company_id,
  u.location_id,
  u.user_id,
  NULL,
  COALESCE(
    NULLIF(TRIM(COALESCE(u.first_name,'') || ' ' || COALESCE(u.last_name,'')), ''),
    u.username
  ) AS name,
  u.phone,
  u.email,
  COALESCE(u.is_active, TRUE),
  u.user_id,
  u.user_id
FROM users u
WHERE u.is_deleted = FALSE AND u.company_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM employees e
    WHERE e.company_id = u.company_id AND e.user_id = u.user_id AND e.is_deleted = FALSE
  );

-- Chart of accounts: prevent duplicate codes per company
CREATE UNIQUE INDEX IF NOT EXISTS idx_chart_of_accounts_company_code
  ON chart_of_accounts(company_id, account_code);

-- Seed a minimal, practical COA per company (used for ledger posting + reports)
-- Codes are intentionally stable so app can rely on them.
INSERT INTO chart_of_accounts (company_id, account_code, name, type, subtype, is_active)
SELECT c.company_id, v.account_code, v.name, v.type, v.subtype, TRUE
FROM companies c
JOIN (
  VALUES
    ('1000', 'Cash',                 'ASSET',    'CASH'),
    ('1010', 'Bank',                 'ASSET',    'BANK'),
    ('1100', 'Accounts Receivable',  'ASSET',    'AR'),
    ('1200', 'Inventory',            'ASSET',    'INVENTORY'),
    ('2000', 'Accounts Payable',     'LIABILITY','AP'),
    ('2100', 'Tax Payable',          'LIABILITY','TAX_PAYABLE'),
    ('2200', 'Tax Receivable',       'ASSET',    'TAX_RECEIVABLE'),
    ('4000', 'Sales Revenue',        'REVENUE',  'SALES'),
    ('5000', 'Cost of Goods Sold',   'EXPENSE',  'COGS'),
    ('6000', 'Expenses',             'EXPENSE',  'EXPENSES')
) AS v(account_code, name, type, subtype) ON TRUE
ON CONFLICT (company_id, account_code) DO NOTHING;

-- Backfill ledger entries for existing transactions (idempotent by company_id + reference).
-- SALES
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_cash.account_id,
  s.sale_date,
  COALESCE(s.paid_amount,0),
  0,
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':1000',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = l.company_id AND coa_cash.account_code = '1000'
WHERE s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
  AND COALESCE(s.paid_amount,0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':1000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_ar.account_id,
  s.sale_date,
  GREATEST(COALESCE(s.total_amount,0) - COALESCE(s.paid_amount,0), 0),
  0,
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':1100',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_ar ON coa_ar.company_id = l.company_id AND coa_ar.account_code = '1100'
WHERE s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
  AND GREATEST(COALESCE(s.total_amount,0) - COALESCE(s.paid_amount,0), 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':1100'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_sales.account_id,
  s.sale_date,
  0,
  GREATEST(COALESCE(s.total_amount,0) - COALESCE(s.tax_amount,0), 0),
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':4000',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_sales ON coa_sales.company_id = l.company_id AND coa_sales.account_code = '4000'
WHERE s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
  AND GREATEST(COALESCE(s.total_amount,0) - COALESCE(s.tax_amount,0), 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':4000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_tax.account_id,
  s.sale_date,
  0,
  COALESCE(s.tax_amount,0),
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':2100',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_tax ON coa_tax.company_id = l.company_id AND coa_tax.account_code = '2100'
WHERE s.is_deleted = FALSE AND COALESCE(s.is_training, FALSE) = FALSE
  AND COALESCE(s.tax_amount,0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':2100'
  );

-- PURCHASES
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_inv.account_id,
  p.purchase_date,
  GREATEST(COALESCE(p.total_amount,0) - COALESCE(p.tax_amount,0), 0),
  0,
  'purchase',
  p.purchase_id,
  'purchase:' || p.purchase_id::text || ':1200',
  p.created_by,
  p.created_by
FROM purchases p
JOIN locations l ON l.location_id = p.location_id
JOIN chart_of_accounts coa_inv ON coa_inv.company_id = l.company_id AND coa_inv.account_code = '1200'
WHERE p.is_deleted = FALSE
  AND GREATEST(COALESCE(p.total_amount,0) - COALESCE(p.tax_amount,0), 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase:' || p.purchase_id::text || ':1200'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_taxr.account_id,
  p.purchase_date,
  COALESCE(p.tax_amount,0),
  0,
  'purchase',
  p.purchase_id,
  'purchase:' || p.purchase_id::text || ':2200',
  p.created_by,
  p.created_by
FROM purchases p
JOIN locations l ON l.location_id = p.location_id
JOIN chart_of_accounts coa_taxr ON coa_taxr.company_id = l.company_id AND coa_taxr.account_code = '2200'
WHERE p.is_deleted = FALSE
  AND COALESCE(p.tax_amount,0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase:' || p.purchase_id::text || ':2200'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_cash.account_id,
  p.purchase_date,
  0,
  COALESCE(p.paid_amount,0),
  'purchase',
  p.purchase_id,
  'purchase:' || p.purchase_id::text || ':1000',
  p.created_by,
  p.created_by
FROM purchases p
JOIN locations l ON l.location_id = p.location_id
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = l.company_id AND coa_cash.account_code = '1000'
WHERE p.is_deleted = FALSE
  AND COALESCE(p.paid_amount,0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase:' || p.purchase_id::text || ':1000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_ap.account_id,
  p.purchase_date,
  0,
  GREATEST(COALESCE(p.total_amount,0) - COALESCE(p.paid_amount,0), 0),
  'purchase',
  p.purchase_id,
  'purchase:' || p.purchase_id::text || ':2000',
  p.created_by,
  p.created_by
FROM purchases p
JOIN locations l ON l.location_id = p.location_id
JOIN chart_of_accounts coa_ap ON coa_ap.company_id = l.company_id AND coa_ap.account_code = '2000'
WHERE p.is_deleted = FALSE
  AND GREATEST(COALESCE(p.total_amount,0) - COALESCE(p.paid_amount,0), 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase:' || p.purchase_id::text || ':2000'
  );

-- EXPENSES
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  c.company_id,
  coa_exp.account_id,
  e.expense_date,
  e.amount,
  0,
  'expense',
  e.expense_id,
  'expense:' || e.expense_id::text || ':6000',
  e.created_by,
  e.created_by
FROM expenses e
JOIN expense_categories c ON c.category_id = e.category_id
JOIN chart_of_accounts coa_exp ON coa_exp.company_id = c.company_id AND coa_exp.account_code = '6000'
WHERE e.is_deleted = FALSE AND e.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = c.company_id AND le.reference = 'expense:' || e.expense_id::text || ':6000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  c.company_id,
  coa_cash.account_id,
  e.expense_date,
  0,
  e.amount,
  'expense',
  e.expense_id,
  'expense:' || e.expense_id::text || ':1000',
  e.created_by,
  e.created_by
FROM expenses e
JOIN expense_categories c ON c.category_id = e.category_id
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = c.company_id AND coa_cash.account_code = '1000'
WHERE e.is_deleted = FALSE AND e.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = c.company_id AND le.reference = 'expense:' || e.expense_id::text || ':1000'
  );

-- COLLECTIONS
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  cu.company_id,
  CASE
    WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN coa_cash.account_id
    ELSE coa_bank.account_id
  END,
  c.collection_date,
  c.amount,
  0,
  'collection',
  c.collection_id,
  'collection:' || c.collection_id::text || ':' ||
    CASE WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN '1000' ELSE '1010' END,
  c.created_by,
  c.created_by
FROM collections c
JOIN customers cu ON cu.customer_id = c.customer_id
LEFT JOIN payment_methods pm ON pm.method_id = c.payment_method_id
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = cu.company_id AND coa_cash.account_code = '1000'
JOIN chart_of_accounts coa_bank ON coa_bank.company_id = cu.company_id AND coa_bank.account_code = '1010'
WHERE c.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = cu.company_id AND le.reference =
      'collection:' || c.collection_id::text || ':' ||
      CASE WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN '1000' ELSE '1010' END
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  cu.company_id,
  coa_ar.account_id,
  c.collection_date,
  0,
  c.amount,
  'collection',
  c.collection_id,
  'collection:' || c.collection_id::text || ':1100',
  c.created_by,
  c.created_by
FROM collections c
JOIN customers cu ON cu.customer_id = c.customer_id
JOIN chart_of_accounts coa_ar ON coa_ar.company_id = cu.company_id AND coa_ar.account_code = '1100'
WHERE c.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = cu.company_id AND le.reference = 'collection:' || c.collection_id::text || ':1100'
  );

-- SUPPLIER PAYMENTS
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  sup.company_id,
  coa_ap.account_id,
  p.payment_date,
  p.amount,
  0,
  'payment',
  p.payment_id,
  'payment:' || p.payment_id::text || ':2000',
  p.created_by,
  p.created_by
FROM payments p
JOIN suppliers sup ON sup.supplier_id = p.supplier_id
JOIN chart_of_accounts coa_ap ON coa_ap.company_id = sup.company_id AND coa_ap.account_code = '2000'
WHERE (p.is_deleted IS NULL OR p.is_deleted = FALSE) AND p.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = sup.company_id AND le.reference = 'payment:' || p.payment_id::text || ':2000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  sup.company_id,
  CASE
    WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN coa_cash.account_id
    ELSE coa_bank.account_id
  END,
  p.payment_date,
  0,
  p.amount,
  'payment',
  p.payment_id,
  'payment:' || p.payment_id::text || ':' ||
    CASE WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN '1000' ELSE '1010' END,
  p.created_by,
  p.created_by
FROM payments p
JOIN suppliers sup ON sup.supplier_id = p.supplier_id
LEFT JOIN payment_methods pm ON pm.method_id = p.payment_method_id
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = sup.company_id AND coa_cash.account_code = '1000'
JOIN chart_of_accounts coa_bank ON coa_bank.company_id = sup.company_id AND coa_bank.account_code = '1010'
WHERE (p.is_deleted IS NULL OR p.is_deleted = FALSE) AND p.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = sup.company_id AND le.reference =
      'payment:' || p.payment_id::text || ':' ||
      CASE WHEN COALESCE(pm.type,'CASH') ILIKE 'CASH' THEN '1000' ELSE '1010' END
  );

-- PURCHASE RETURNS
INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_ap.account_id,
  pr.return_date,
  pr.total_amount,
  0,
  'purchase_return',
  pr.return_id,
  'purchase_return:' || pr.return_id::text || ':2000',
  pr.created_by,
  pr.created_by
FROM purchase_returns pr
JOIN locations l ON l.location_id = pr.location_id
JOIN chart_of_accounts coa_ap ON coa_ap.company_id = l.company_id AND coa_ap.account_code = '2000'
WHERE pr.is_deleted = FALSE AND pr.total_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase_return:' || pr.return_id::text || ':2000'
  );

INSERT INTO ledger_entries (company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by)
SELECT
  l.company_id,
  coa_inv.account_id,
  pr.return_date,
  0,
  pr.total_amount,
  'purchase_return',
  pr.return_id,
  'purchase_return:' || pr.return_id::text || ':1200',
  pr.created_by,
  pr.created_by
FROM purchase_returns pr
JOIN locations l ON l.location_id = pr.location_id
JOIN chart_of_accounts coa_inv ON coa_inv.company_id = l.company_id AND coa_inv.account_code = '1200'
WHERE pr.is_deleted = FALSE AND pr.total_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase_return:' || pr.return_id::text || ':1200'
  );

-- VOUCHERS (minimal cash counterpart)
INSERT INTO ledger_entries (company_id, account_id, voucher_id, date, debit, credit, transaction_type, transaction_id, reference, description, created_by, updated_by)
SELECT
  v.company_id,
  v.account_id,
  v.voucher_id,
  v.date,
  v.amount,
  0,
  'voucher',
  v.voucher_id,
  'voucher:' || v.voucher_id::text || ':acct:' || v.account_id::text || ':debit',
  v.description,
  v.created_by,
  v.created_by
FROM vouchers v
WHERE v.is_deleted = FALSE AND v.amount > 0 AND LOWER(v.type) = 'payment'
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = v.company_id AND le.reference = 'voucher:' || v.voucher_id::text || ':acct:' || v.account_id::text || ':debit'
  );

INSERT INTO ledger_entries (company_id, account_id, voucher_id, date, debit, credit, transaction_type, transaction_id, reference, description, created_by, updated_by)
SELECT
  v.company_id,
  coa_cash.account_id,
  v.voucher_id,
  v.date,
  0,
  v.amount,
  'voucher',
  v.voucher_id,
  'voucher:' || v.voucher_id::text || ':1000:credit',
  v.description,
  v.created_by,
  v.created_by
FROM vouchers v
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = v.company_id AND coa_cash.account_code = '1000'
WHERE v.is_deleted = FALSE AND v.amount > 0 AND LOWER(v.type) = 'payment'
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = v.company_id AND le.reference = 'voucher:' || v.voucher_id::text || ':1000:credit'
  );

INSERT INTO ledger_entries (company_id, account_id, voucher_id, date, debit, credit, transaction_type, transaction_id, reference, description, created_by, updated_by)
SELECT
  v.company_id,
  coa_cash.account_id,
  v.voucher_id,
  v.date,
  v.amount,
  0,
  'voucher',
  v.voucher_id,
  'voucher:' || v.voucher_id::text || ':1000:debit',
  v.description,
  v.created_by,
  v.created_by
FROM vouchers v
JOIN chart_of_accounts coa_cash ON coa_cash.company_id = v.company_id AND coa_cash.account_code = '1000'
WHERE v.is_deleted = FALSE AND v.amount > 0 AND LOWER(v.type) = 'receipt'
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = v.company_id AND le.reference = 'voucher:' || v.voucher_id::text || ':1000:debit'
  );

INSERT INTO ledger_entries (company_id, account_id, voucher_id, date, debit, credit, transaction_type, transaction_id, reference, description, created_by, updated_by)
SELECT
  v.company_id,
  v.account_id,
  v.voucher_id,
  v.date,
  0,
  v.amount,
  'voucher',
  v.voucher_id,
  'voucher:' || v.voucher_id::text || ':acct:' || v.account_id::text || ':credit',
  v.description,
  v.created_by,
  v.created_by
FROM vouchers v
WHERE v.is_deleted = FALSE AND v.amount > 0 AND LOWER(v.type) = 'receipt'
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = v.company_id AND le.reference = 'voucher:' || v.voucher_id::text || ':acct:' || v.account_id::text || ':credit'
  );

-- +goose Down
-- No-op (seed + additive columns).
