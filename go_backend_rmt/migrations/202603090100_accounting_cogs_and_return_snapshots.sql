-- +goose Up
ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,2) NOT NULL DEFAULT 0;

ALTER TABLE sale_return_details
  ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,2) NOT NULL DEFAULT 0;

UPDATE sale_details sd
SET cost_price = COALESCE(p.cost_price, 0)
FROM sales s,
     locations l,
     products p
WHERE sd.sale_id = s.sale_id
  AND l.location_id = s.location_id
  AND p.product_id = sd.product_id
  AND l.company_id = p.company_id
  AND COALESCE(sd.cost_price, 0) = 0;

UPDATE sale_return_details srd
SET sale_detail_id = src.sale_detail_id
FROM (
  SELECT DISTINCT ON (srd.return_detail_id)
    srd.return_detail_id,
    sd.sale_detail_id
  FROM sale_return_details srd
  JOIN sale_returns sr ON sr.return_id = srd.return_id
  JOIN sale_details sd ON sd.sale_id = sr.sale_id AND sd.product_id = srd.product_id
  WHERE srd.sale_detail_id IS NULL
  ORDER BY srd.return_detail_id, sd.sale_detail_id
) AS src
WHERE srd.return_detail_id = src.return_detail_id
  AND srd.sale_detail_id IS NULL;

UPDATE sale_return_details srd
SET tax_amount = COALESCE(src.tax_amount, 0),
    cost_price = COALESCE(src.cost_price, 0)
FROM (
  SELECT
    srd.return_detail_id,
    CASE
      WHEN COALESCE(sd.quantity, 0) <> 0 THEN (COALESCE(sd.tax_amount, 0) / sd.quantity) * srd.quantity
      ELSE 0
    END::numeric(12,2) AS tax_amount,
    COALESCE(sd.cost_price, p.cost_price, 0)::numeric(12,2) AS cost_price
  FROM sale_return_details srd
  JOIN sale_returns sr ON sr.return_id = srd.return_id
  LEFT JOIN sale_details sd ON sd.sale_detail_id = srd.sale_detail_id
  LEFT JOIN products p ON p.product_id = srd.product_id
) AS src
WHERE srd.return_detail_id = src.return_detail_id
  AND (COALESCE(srd.tax_amount, 0) = 0 OR COALESCE(srd.cost_price, 0) = 0);

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_cogs.account_id,
  s.sale_date,
  cogs.amount,
  0,
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':5000',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_cogs ON coa_cogs.company_id = l.company_id AND coa_cogs.account_code = '5000'
JOIN (
  SELECT sd.sale_id, COALESCE(SUM(sd.quantity * COALESCE(sd.cost_price, 0)), 0)::float8 AS amount
  FROM sale_details sd
  GROUP BY sd.sale_id
) cogs ON cogs.sale_id = s.sale_id
WHERE s.is_deleted = FALSE
  AND COALESCE(s.is_training, FALSE) = FALSE
  AND cogs.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':5000'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_inv.account_id,
  s.sale_date,
  0,
  cogs.amount,
  'sale',
  s.sale_id,
  'sale:' || s.sale_id::text || ':1200',
  s.created_by,
  s.created_by
FROM sales s
JOIN locations l ON l.location_id = s.location_id
JOIN chart_of_accounts coa_inv ON coa_inv.company_id = l.company_id AND coa_inv.account_code = '1200'
JOIN (
  SELECT sd.sale_id, COALESCE(SUM(sd.quantity * COALESCE(sd.cost_price, 0)), 0)::float8 AS amount
  FROM sale_details sd
  GROUP BY sd.sale_id
) cogs ON cogs.sale_id = s.sale_id
WHERE s.is_deleted = FALSE
  AND COALESCE(s.is_training, FALSE) = FALSE
  AND cogs.amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale:' || s.sale_id::text || ':1200'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_sales.account_id,
  sr.return_date,
  GREATEST(COALESCE(sr.total_amount, 0) - COALESCE(ret.tax_amount, 0), 0),
  0,
  'sale_return',
  sr.return_id,
  'sale_return:' || sr.return_id::text || ':4000',
  sr.created_by,
  sr.created_by
FROM sale_returns sr
JOIN locations l ON l.location_id = sr.location_id
JOIN chart_of_accounts coa_sales ON coa_sales.company_id = l.company_id AND coa_sales.account_code = '4000'
JOIN (
  SELECT return_id, COALESCE(SUM(COALESCE(tax_amount, 0)), 0)::float8 AS tax_amount
  FROM sale_return_details
  GROUP BY return_id
) ret ON ret.return_id = sr.return_id
WHERE sr.is_deleted = FALSE
  AND GREATEST(COALESCE(sr.total_amount, 0) - COALESCE(ret.tax_amount, 0), 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale_return:' || sr.return_id::text || ':4000'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_tax.account_id,
  sr.return_date,
  COALESCE(ret.tax_amount, 0),
  0,
  'sale_return',
  sr.return_id,
  'sale_return:' || sr.return_id::text || ':2100',
  sr.created_by,
  sr.created_by
FROM sale_returns sr
JOIN locations l ON l.location_id = sr.location_id
JOIN chart_of_accounts coa_tax ON coa_tax.company_id = l.company_id AND coa_tax.account_code = '2100'
JOIN (
  SELECT return_id, COALESCE(SUM(COALESCE(tax_amount, 0)), 0)::float8 AS tax_amount
  FROM sale_return_details
  GROUP BY return_id
) ret ON ret.return_id = sr.return_id
WHERE sr.is_deleted = FALSE
  AND COALESCE(ret.tax_amount, 0) > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale_return:' || sr.return_id::text || ':2100'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_ar.account_id,
  sr.return_date,
  0,
  sr.total_amount,
  'sale_return',
  sr.return_id,
  'sale_return:' || sr.return_id::text || ':1100',
  sr.created_by,
  sr.created_by
FROM sale_returns sr
JOIN locations l ON l.location_id = sr.location_id
JOIN chart_of_accounts coa_ar ON coa_ar.company_id = l.company_id AND coa_ar.account_code = '1100'
WHERE sr.is_deleted = FALSE
  AND sr.total_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale_return:' || sr.return_id::text || ':1100'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_inv.account_id,
  sr.return_date,
  ret.cogs_amount,
  0,
  'sale_return',
  sr.return_id,
  'sale_return:' || sr.return_id::text || ':1200',
  sr.created_by,
  sr.created_by
FROM sale_returns sr
JOIN locations l ON l.location_id = sr.location_id
JOIN chart_of_accounts coa_inv ON coa_inv.company_id = l.company_id AND coa_inv.account_code = '1200'
JOIN (
  SELECT return_id, COALESCE(SUM(quantity * COALESCE(cost_price, 0)), 0)::float8 AS cogs_amount
  FROM sale_return_details
  GROUP BY return_id
) ret ON ret.return_id = sr.return_id
WHERE sr.is_deleted = FALSE
  AND ret.cogs_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale_return:' || sr.return_id::text || ':1200'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_cogs.account_id,
  sr.return_date,
  0,
  ret.cogs_amount,
  'sale_return',
  sr.return_id,
  'sale_return:' || sr.return_id::text || ':5000',
  sr.created_by,
  sr.created_by
FROM sale_returns sr
JOIN locations l ON l.location_id = sr.location_id
JOIN chart_of_accounts coa_cogs ON coa_cogs.company_id = l.company_id AND coa_cogs.account_code = '5000'
JOIN (
  SELECT return_id, COALESCE(SUM(quantity * COALESCE(cost_price, 0)), 0)::float8 AS cogs_amount
  FROM sale_return_details
  GROUP BY return_id
) ret ON ret.return_id = sr.return_id
WHERE sr.is_deleted = FALSE
  AND ret.cogs_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'sale_return:' || sr.return_id::text || ':5000'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_inv.account_id,
  pr.return_date,
  tax_adj.tax_amount,
  0,
  'purchase_return',
  pr.return_id,
  'purchase_return:' || pr.return_id::text || ':1200:tax_adjustment',
  pr.created_by,
  pr.created_by
FROM purchase_returns pr
JOIN locations l ON l.location_id = pr.location_id
JOIN chart_of_accounts coa_inv ON coa_inv.company_id = l.company_id AND coa_inv.account_code = '1200'
JOIN (
  SELECT
    pr.return_id,
    COALESCE(SUM(
      CASE
        WHEN prd.purchase_detail_id IS NOT NULL AND COALESCE(pd.quantity, 0) <> 0
          THEN (COALESCE(pd.tax_amount, 0) / pd.quantity) * prd.quantity
        ELSE 0
      END
    ), 0)::float8 AS tax_amount
  FROM purchase_returns pr
  JOIN purchase_return_details prd ON prd.return_id = pr.return_id
  LEFT JOIN purchase_details pd ON pd.purchase_detail_id = prd.purchase_detail_id
  GROUP BY pr.return_id
) tax_adj ON tax_adj.return_id = pr.return_id
WHERE pr.is_deleted = FALSE
  AND tax_adj.tax_amount > 0
  AND EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase_return:' || pr.return_id::text || ':1200'
  )
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase_return:' || pr.return_id::text || ':1200:tax_adjustment'
  );

INSERT INTO ledger_entries (
  company_id, account_id, date, debit, credit, transaction_type, transaction_id, reference, created_by, updated_by
)
SELECT
  l.company_id,
  coa_tax.account_id,
  pr.return_date,
  0,
  tax_adj.tax_amount,
  'purchase_return',
  pr.return_id,
  'purchase_return:' || pr.return_id::text || ':2200',
  pr.created_by,
  pr.created_by
FROM purchase_returns pr
JOIN locations l ON l.location_id = pr.location_id
JOIN chart_of_accounts coa_tax ON coa_tax.company_id = l.company_id AND coa_tax.account_code = '2200'
JOIN (
  SELECT
    pr.return_id,
    COALESCE(SUM(
      CASE
        WHEN prd.purchase_detail_id IS NOT NULL AND COALESCE(pd.quantity, 0) <> 0
          THEN (COALESCE(pd.tax_amount, 0) / pd.quantity) * prd.quantity
        ELSE 0
      END
    ), 0)::float8 AS tax_amount
  FROM purchase_returns pr
  JOIN purchase_return_details prd ON prd.return_id = pr.return_id
  LEFT JOIN purchase_details pd ON pd.purchase_detail_id = prd.purchase_detail_id
  GROUP BY pr.return_id
) tax_adj ON tax_adj.return_id = pr.return_id
WHERE pr.is_deleted = FALSE
  AND tax_adj.tax_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM ledger_entries le
    WHERE le.company_id = l.company_id AND le.reference = 'purchase_return:' || pr.return_id::text || ':2200'
  );

-- +goose Down
DELETE FROM ledger_entries
WHERE reference LIKE 'sale_return:%'
   OR reference LIKE 'purchase_return:%:1200:tax_adjustment'
   OR reference LIKE 'purchase_return:%:2200'
   OR reference LIKE 'sale:%:5000'
   OR reference LIKE 'sale:%:1200';

ALTER TABLE sale_return_details
  DROP COLUMN IF EXISTS cost_price,
  DROP COLUMN IF EXISTS tax_amount;

ALTER TABLE sale_details
  DROP COLUMN IF EXISTS cost_price;
