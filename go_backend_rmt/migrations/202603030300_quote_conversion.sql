-- +goose Up
-- +goose StatementBegin

-- Track quote -> sale conversion so quotes become immutable afterwards.
ALTER TABLE quotes
  ADD COLUMN IF NOT EXISTS converted_sale_id INTEGER REFERENCES sales(sale_id),
  ADD COLUMN IF NOT EXISTS converted_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS converted_by INTEGER REFERENCES users(user_id);

CREATE INDEX IF NOT EXISTS idx_quotes_converted_sale_id ON quotes(converted_sale_id);
CREATE INDEX IF NOT EXISTS idx_quotes_status ON quotes(status);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- Keep columns on downgrade (non-destructive).
-- +goose StatementEnd

