-- +goose Up
-- +goose StatementBegin

ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS customer_type VARCHAR(20) NOT NULL DEFAULT 'RETAIL',
  ADD COLUMN IF NOT EXISTS contact_person VARCHAR(255),
  ADD COLUMN IF NOT EXISTS shipping_address TEXT;

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS transaction_type VARCHAR(20) NOT NULL DEFAULT 'RETAIL';

ALTER TABLE quotes
  ADD COLUMN IF NOT EXISTS transaction_type VARCHAR(20) NOT NULL DEFAULT 'B2B';

ALTER TABLE sale_returns
  ADD COLUMN IF NOT EXISTS transaction_type VARCHAR(20) NOT NULL DEFAULT 'RETAIL';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'customers_customer_type_check'
  ) THEN
    ALTER TABLE customers
      ADD CONSTRAINT customers_customer_type_check
      CHECK (customer_type IN ('RETAIL', 'B2B'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_transaction_type_check'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_transaction_type_check
      CHECK (transaction_type IN ('RETAIL', 'B2B'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quotes_transaction_type_check'
  ) THEN
    ALTER TABLE quotes
      ADD CONSTRAINT quotes_transaction_type_check
      CHECK (transaction_type IN ('RETAIL', 'B2B'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sale_returns_transaction_type_check'
  ) THEN
    ALTER TABLE sale_returns
      ADD CONSTRAINT sale_returns_transaction_type_check
      CHECK (transaction_type IN ('RETAIL', 'B2B'));
  END IF;
END $$;

UPDATE sales
SET transaction_type = CASE
  WHEN COALESCE(source_channel, 'INVOICE') IN ('POS', 'POS_REFUND') THEN 'RETAIL'
  ELSE 'B2B'
END
WHERE transaction_type NOT IN ('RETAIL', 'B2B')
   OR transaction_type IS NULL
   OR transaction_type = 'RETAIL';

UPDATE quotes
SET transaction_type = 'B2B'
WHERE transaction_type IS NULL OR transaction_type NOT IN ('RETAIL', 'B2B');

UPDATE sale_returns sr
SET transaction_type = COALESCE(s.transaction_type, 'B2B')
FROM sales s
WHERE s.sale_id = sr.sale_id
  AND (
    sr.transaction_type IS NULL
    OR sr.transaction_type NOT IN ('RETAIL', 'B2B')
    OR sr.transaction_type = 'RETAIL'
  );

UPDATE customers c
SET customer_type = 'B2B'
WHERE EXISTS (
  SELECT 1
  FROM sales s
  WHERE s.customer_id = c.customer_id
    AND COALESCE(s.transaction_type, 'B2B') = 'B2B'
)
OR EXISTS (
  SELECT 1
  FROM quotes q
  WHERE q.customer_id = c.customer_id
    AND COALESCE(q.transaction_type, 'B2B') = 'B2B'
)
OR COALESCE(c.payment_terms, 0) > 0
OR COALESCE(c.credit_limit, 0) > 0
OR NULLIF(TRIM(COALESCE(c.tax_number, '')), '') IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_customers_company_customer_type
  ON customers(company_id, customer_type)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sales_transaction_type
  ON sales(transaction_type)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_quotes_transaction_type
  ON quotes(transaction_type)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sale_returns_transaction_type
  ON sale_returns(transaction_type)
  WHERE is_deleted = FALSE;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_sale_returns_transaction_type;
DROP INDEX IF EXISTS idx_quotes_transaction_type;
DROP INDEX IF EXISTS idx_sales_transaction_type;
DROP INDEX IF EXISTS idx_customers_company_customer_type;

ALTER TABLE sale_returns
  DROP CONSTRAINT IF EXISTS sale_returns_transaction_type_check;

ALTER TABLE quotes
  DROP CONSTRAINT IF EXISTS quotes_transaction_type_check;

ALTER TABLE sales
  DROP CONSTRAINT IF EXISTS sales_transaction_type_check;

ALTER TABLE customers
  DROP CONSTRAINT IF EXISTS customers_customer_type_check;

ALTER TABLE sale_returns
  DROP COLUMN IF EXISTS transaction_type;

ALTER TABLE quotes
  DROP COLUMN IF EXISTS transaction_type;

ALTER TABLE sales
  DROP COLUMN IF EXISTS transaction_type;

ALTER TABLE customers
  DROP COLUMN IF EXISTS shipping_address,
  DROP COLUMN IF EXISTS contact_person,
  DROP COLUMN IF EXISTS customer_type;

-- +goose StatementEnd
