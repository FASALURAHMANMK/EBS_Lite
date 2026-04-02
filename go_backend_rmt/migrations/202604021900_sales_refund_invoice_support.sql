-- +goose Up
-- +goose StatementBegin

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS source_channel VARCHAR(20),
  ADD COLUMN IF NOT EXISTS refund_source_sale_id INTEGER REFERENCES sales(sale_id);

ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS source_sale_detail_id INTEGER REFERENCES sale_details(sale_detail_id);

ALTER TABLE sales
  DROP CONSTRAINT IF EXISTS sales_paid_amount_check;

ALTER TABLE sales
  ADD CONSTRAINT sales_paid_amount_check CHECK (
    (
      total_amount >= 0
      AND paid_amount >= 0
      AND paid_amount <= total_amount
    )
    OR
    (
      total_amount < 0
      AND paid_amount <= 0
      AND paid_amount >= total_amount
    )
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_source_channel_check'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_source_channel_check
      CHECK (
        source_channel IS NULL
        OR source_channel IN ('POS', 'INVOICE', 'QUOTE', 'POS_REFUND')
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sales_source_channel_not_deleted
  ON sales(source_channel)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sales_refund_source_sale_id
  ON sales(refund_source_sale_id)
  WHERE refund_source_sale_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sale_details_source_sale_detail_id
  ON sale_details(source_sale_detail_id)
  WHERE source_sale_detail_id IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_sale_details_source_sale_detail_id;
DROP INDEX IF EXISTS idx_sales_refund_source_sale_id;
DROP INDEX IF EXISTS idx_sales_source_channel_not_deleted;

ALTER TABLE sales
  DROP CONSTRAINT IF EXISTS sales_source_channel_check;

ALTER TABLE sales
  DROP CONSTRAINT IF EXISTS sales_paid_amount_check;

ALTER TABLE sales
  ADD CONSTRAINT sales_paid_amount_check CHECK (paid_amount <= total_amount);

ALTER TABLE sale_details
  DROP COLUMN IF EXISTS source_sale_detail_id;

ALTER TABLE sales
  DROP COLUMN IF EXISTS refund_source_sale_id,
  DROP COLUMN IF EXISTS source_channel;

-- +goose StatementEnd
