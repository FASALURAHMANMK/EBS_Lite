-- +goose Up
-- Repair legacy settings tables that are missing the unique constraint used by
-- settings upserts.

-- +goose StatementBegin
WITH ranked AS (
  SELECT
    setting_id,
    ROW_NUMBER() OVER (
      PARTITION BY company_id, key
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, setting_id DESC
    ) AS row_num
  FROM settings
  WHERE company_id IS NOT NULL
)
DELETE FROM settings AS s
USING ranked AS r
WHERE s.setting_id = r.setting_id
  AND r.row_num > 1;
-- +goose StatementEnd

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.settings') IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class t
    JOIN pg_namespace ns ON ns.oid = t.relnamespace
    JOIN pg_index i ON i.indrelid = t.oid
    JOIN LATERAL (
      SELECT string_agg(a.attname, ',' ORDER BY keys.ordinality) AS cols
      FROM unnest(i.indkey) WITH ORDINALITY AS keys(attnum, ordinality)
      JOIN pg_attribute a
        ON a.attrelid = t.oid
        AND a.attnum = keys.attnum
    ) idx_cols ON TRUE
    WHERE ns.nspname = 'public'
      AND t.relname = 'settings'
      AND i.indisunique
      AND i.indpred IS NULL
      AND idx_cols.cols = 'company_id,key'
  ) THEN
    ALTER TABLE settings
      ADD CONSTRAINT settings_company_key_unique UNIQUE (company_id, key);
  END IF;
END
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE settings
  DROP CONSTRAINT IF EXISTS settings_company_key_unique;
-- +goose StatementEnd
