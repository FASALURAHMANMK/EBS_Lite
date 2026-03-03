-- +goose Up
-- +goose StatementBegin

-- Permissions for cash register operations (ensure new DBs + upgraded DBs can authorize).
INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_CASH_REGISTERS', 'View cash registers', 'accounts', 'view'),
  ('OPEN_CASH_REGISTER', 'Open cash register', 'accounts', 'open'),
  ('CLOSE_CASH_REGISTER', 'Close cash register', 'accounts', 'close'),
  ('TALLY_CASH_REGISTER', 'Record cash tally', 'accounts', 'tally'),
  ('CASH_REGISTER_MOVEMENT', 'Record cash movement (drop/payout)', 'accounts', 'movement'),
  ('FORCE_CLOSE_CASH_REGISTER', 'Force-close cash register', 'accounts', 'force_close')
ON CONFLICT (name) DO NOTHING;

-- Grant these permissions to Super Admin (1) and Admin (2) by default.
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, p.permission_id FROM permissions p
WHERE p.name IN (
  'VIEW_CASH_REGISTERS',
  'OPEN_CASH_REGISTER',
  'CLOSE_CASH_REGISTER',
  'TALLY_CASH_REGISTER',
  'CASH_REGISTER_MOVEMENT',
  'FORCE_CLOSE_CASH_REGISTER'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, p.permission_id FROM permissions p
WHERE p.name IN (
  'VIEW_CASH_REGISTERS',
  'OPEN_CASH_REGISTER',
  'CLOSE_CASH_REGISTER',
  'TALLY_CASH_REGISTER',
  'CASH_REGISTER_MOVEMENT',
  'FORCE_CLOSE_CASH_REGISTER'
)
ON CONFLICT DO NOTHING;

-- Add session metadata columns to cash_register.
ALTER TABLE cash_register
  ADD COLUMN IF NOT EXISTS opened_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS opened_session_id UUID,
  ADD COLUMN IF NOT EXISTS closed_session_id UUID,
  ADD COLUMN IF NOT EXISTS opened_request_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS closed_request_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS forced_closed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS forced_close_reason TEXT;

-- Event log for immutable session activity (open/close/tally/movements).
CREATE TABLE IF NOT EXISTS cash_register_events (
  event_id SERIAL PRIMARY KEY,
  register_id INTEGER NOT NULL REFERENCES cash_register(register_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id),
  event_type VARCHAR(50) NOT NULL,
  direction VARCHAR(10),
  amount NUMERIC(12,2),
  reason_code VARCHAR(100),
  notes TEXT,
  denominations JSONB,
  created_by INTEGER NOT NULL REFERENCES users(user_id),
  session_id UUID,
  request_id VARCHAR(100),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cash_register_events_register_created
  ON cash_register_events(register_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cash_register_events_location_created
  ON cash_register_events(location_id, created_at DESC);

-- Enforce immutability (no UPDATE/DELETE).
CREATE OR REPLACE FUNCTION prevent_cash_register_events_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'cash_register_events is immutable';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cash_register_events_no_update ON cash_register_events;
CREATE TRIGGER trg_cash_register_events_no_update
BEFORE UPDATE ON cash_register_events
FOR EACH ROW EXECUTE FUNCTION prevent_cash_register_events_mutation();

DROP TRIGGER IF EXISTS trg_cash_register_events_no_delete ON cash_register_events;
CREATE TRIGGER trg_cash_register_events_no_delete
BEFORE DELETE ON cash_register_events
FOR EACH ROW EXECUTE FUNCTION prevent_cash_register_events_mutation();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TRIGGER IF EXISTS trg_cash_register_events_no_update ON cash_register_events;
DROP TRIGGER IF EXISTS trg_cash_register_events_no_delete ON cash_register_events;
DROP FUNCTION IF EXISTS prevent_cash_register_events_mutation();
DROP TABLE IF EXISTS cash_register_events;

ALTER TABLE cash_register
  DROP COLUMN IF EXISTS opened_at,
  DROP COLUMN IF EXISTS closed_at,
  DROP COLUMN IF EXISTS opened_session_id,
  DROP COLUMN IF EXISTS closed_session_id,
  DROP COLUMN IF EXISTS opened_request_id,
  DROP COLUMN IF EXISTS closed_request_id,
  DROP COLUMN IF EXISTS forced_closed,
  DROP COLUMN IF EXISTS forced_close_reason;

DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.permission_id AND p.name IN (
  'VIEW_CASH_REGISTERS',
  'OPEN_CASH_REGISTER',
  'CLOSE_CASH_REGISTER',
  'TALLY_CASH_REGISTER',
  'CASH_REGISTER_MOVEMENT',
  'FORCE_CLOSE_CASH_REGISTER'
);

DELETE FROM permissions
WHERE name IN (
  'VIEW_CASH_REGISTERS',
  'OPEN_CASH_REGISTER',
  'CLOSE_CASH_REGISTER',
  'TALLY_CASH_REGISTER',
  'CASH_REGISTER_MOVEMENT',
  'FORCE_CLOSE_CASH_REGISTER'
);
-- +goose StatementEnd

