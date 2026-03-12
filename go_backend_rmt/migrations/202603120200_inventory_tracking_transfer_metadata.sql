-- +goose Up
ALTER TABLE stock_transfer_details
  ADD COLUMN IF NOT EXISTS serial_numbers TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS batch_allocations JSONB DEFAULT '[]'::jsonb;

ALTER TABLE stock_adjustment_document_items
  ADD COLUMN IF NOT EXISTS serial_numbers TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS batch_allocations JSONB DEFAULT '[]'::jsonb;

-- +goose Down
ALTER TABLE stock_adjustment_document_items
  DROP COLUMN IF EXISTS batch_allocations,
  DROP COLUMN IF EXISTS serial_numbers;

ALTER TABLE stock_transfer_details
  DROP COLUMN IF EXISTS batch_allocations,
  DROP COLUMN IF EXISTS serial_numbers;
