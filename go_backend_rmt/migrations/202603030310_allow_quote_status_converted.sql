-- Allow quotes to be marked as CONVERTED after successful conversion to a Sale.
-- Existing schema uses an unnamed CHECK constraint on quotes.status which PostgreSQL
-- auto-names as "quotes_status_check".

-- +goose Up
-- +goose StatementBegin

-- Allow quotes to be marked as CONVERTED after successful conversion to a Sale.
-- Existing schema uses a CHECK constraint on quotes.status which PostgreSQL
-- auto-names as "quotes_status_check".
ALTER TABLE quotes
  DROP CONSTRAINT IF EXISTS quotes_status_check;

ALTER TABLE quotes
  ADD CONSTRAINT quotes_status_check
  CHECK (status IN ('DRAFT', 'SENT', 'ACCEPTED', 'CONVERTED'));

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- No-op: reverting this constraint could fail if any rows are already CONVERTED.
-- +goose StatementEnd
