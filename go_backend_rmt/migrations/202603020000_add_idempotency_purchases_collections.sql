-- +goose Up
-- Source: Docs & Schema/migrations/2026_03_02_add_idempotency_purchases_collections.sql

ALTER TABLE IF EXISTS purchases
	ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_purchases_location_idempotency
	ON purchases(location_id, idempotency_key)
	WHERE idempotency_key IS NOT NULL;

ALTER TABLE IF EXISTS collections
	ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_location_idempotency
	ON collections(location_id, idempotency_key)
	WHERE idempotency_key IS NOT NULL;

-- +goose Down
-- No-op (indexes/columns are forward-only for production safety).

