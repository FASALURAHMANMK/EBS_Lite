-- +goose Up
ALTER TABLE users
ADD COLUMN IF NOT EXISTS sales_action_password_hash VARCHAR(255);

-- +goose Down
ALTER TABLE users
DROP COLUMN IF EXISTS sales_action_password_hash;
