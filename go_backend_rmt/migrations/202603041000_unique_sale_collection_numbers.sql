-- +goose Up
-- Ensure document numbers never collide per location (critical for offline-first numbering).
-- +goose StatementBegin

CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_location_sale_number_unique
ON sales(location_id, sale_number)
WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_location_collection_number_unique
ON collections(location_id, collection_number);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_collections_location_collection_number_unique;
DROP INDEX IF EXISTS idx_sales_location_sale_number_unique;
-- +goose StatementEnd
