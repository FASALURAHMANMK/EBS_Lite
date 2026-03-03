-- +goose Up
-- +goose StatementBegin

-- Permission to toggle training mode (session-scoped).
INSERT INTO permissions (name, description, module, action) VALUES
  ('TOGGLE_TRAINING_MODE', 'Enable/disable training mode for the current cash register session', 'accounts', 'training_mode')
ON CONFLICT (name) DO NOTHING;

-- Grant to Super Admin (1) and Admin (2) by default.
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, p.permission_id FROM permissions p
WHERE p.name IN ('TOGGLE_TRAINING_MODE')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, p.permission_id FROM permissions p
WHERE p.name IN ('TOGGLE_TRAINING_MODE')
ON CONFLICT DO NOTHING;

-- Track training mode at the current cash register session level.
ALTER TABLE cash_register
  ADD COLUMN IF NOT EXISTS training_mode BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS training_mode_updated_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS training_mode_updated_by INTEGER REFERENCES users(user_id);

-- Flag training sales so they can be excluded from operational reporting by default.
ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS is_training BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_sales_is_training_not_deleted
  ON sales(is_training)
  WHERE is_deleted = FALSE;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_sales_is_training_not_deleted;

ALTER TABLE sales
  DROP COLUMN IF EXISTS is_training;

ALTER TABLE cash_register
  DROP COLUMN IF EXISTS training_mode,
  DROP COLUMN IF EXISTS training_mode_updated_at,
  DROP COLUMN IF EXISTS training_mode_updated_by;

DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.permission_id AND p.name IN ('TOGGLE_TRAINING_MODE');

DELETE FROM permissions
WHERE name IN ('TOGGLE_TRAINING_MODE');

-- +goose StatementEnd

