-- +goose Up
-- Add idempotency key support for offline outbox retries (Expense create)
-- +goose StatementBegin

ALTER TABLE expenses
ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

-- Enforce uniqueness per location to prevent duplicate expenses on retries.
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_location_idempotency_key
ON expenses (location_id, idempotency_key)
WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_expenses_location_idempotency_key;

ALTER TABLE expenses
DROP COLUMN IF EXISTS idempotency_key;

-- +goose StatementEnd
