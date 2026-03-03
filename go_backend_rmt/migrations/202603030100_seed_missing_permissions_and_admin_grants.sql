-- +goose Up
-- +goose StatementBegin

-- Ensure system roles exist (by name) and are marked as system roles.
INSERT INTO roles (name, description, is_system_role) VALUES
  ('Super Admin', 'Full system access', TRUE),
  ('Admin', 'Company administration', TRUE)
ON CONFLICT (name) DO UPDATE
SET is_system_role = TRUE;

-- Seed permissions referenced by routes but missing from the original schema seed.
-- (Safe to run on existing DBs; name is unique.)
INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_SETTINGS', 'View settings', 'settings', 'view'),
  ('MANAGE_SETTINGS', 'Manage settings', 'settings', 'manage'),

  ('VIEW_TRANSLATIONS', 'View translations', 'translations', 'view'),
  ('MANAGE_TRANSLATIONS', 'Manage translations', 'translations', 'manage'),

  ('VIEW_AUDIT_LOGS', 'View audit logs', 'audit', 'view'),

  ('VIEW_LEDGER', 'View ledger balances', 'ledger', 'view'),
  ('VIEW_LEDGER_DETAILS', 'View ledger entries', 'ledger', 'entries'),

  ('VIEW_VOUCHERS', 'View vouchers', 'vouchers', 'view'),
  ('MANAGE_VOUCHERS', 'Manage vouchers', 'vouchers', 'manage'),

  ('VIEW_ATTENDANCE', 'View attendance', 'attendance', 'view'),
  ('MANAGE_ATTENDANCE', 'Manage attendance', 'attendance', 'manage'),

  ('VIEW_EMPLOYEES', 'View employees', 'employees', 'view'),
  ('CREATE_EMPLOYEES', 'Create employees', 'employees', 'create'),
  ('UPDATE_EMPLOYEES', 'Update employees', 'employees', 'update'),
  ('DELETE_EMPLOYEES', 'Delete employees', 'employees', 'delete'),

  ('VIEW_PAYROLLS', 'View payrolls', 'payroll', 'view'),
  ('CREATE_PAYROLLS', 'Create payrolls', 'payroll', 'create'),
  ('PROCESS_PAYROLLS', 'Process payrolls', 'payroll', 'process'),

  ('VIEW_EXPENSES', 'View expenses', 'expenses', 'view'),
  ('CREATE_EXPENSES', 'Create expenses', 'expenses', 'create'),
  ('UPDATE_EXPENSES', 'Update expenses', 'expenses', 'update'),
  ('DELETE_EXPENSES', 'Delete expenses', 'expenses', 'delete'),

  ('VIEW_COLLECTIONS', 'View collections', 'collections', 'view'),
  ('CREATE_COLLECTIONS', 'Create collections', 'collections', 'create'),
  ('DELETE_COLLECTIONS', 'Delete collections', 'collections', 'delete'),

  ('UPDATE_PURCHASE_RETURNS', 'Update purchase returns', 'purchases', 'update_return'),
  ('DELETE_PURCHASE_RETURNS', 'Delete purchase returns', 'purchases', 'delete_return'),

  ('VIEW_WORKFLOWS', 'View workflow requests', 'workflow', 'view'),
  ('CREATE_WORKFLOWS', 'Create workflow requests', 'workflow', 'create'),
  ('APPROVE_WORKFLOWS', 'Approve/reject workflow requests', 'workflow', 'approve'),

  ('VIEW_NOTIFICATIONS', 'View notifications', 'notifications', 'view'),
  ('MARK_NOTIFICATIONS_READ', 'Mark notifications as read', 'notifications', 'mark_read'),

  ('VIEW_CASH_REGISTERS', 'View cash registers', 'cash_register', 'view'),
  ('OPEN_CASH_REGISTER', 'Open cash register', 'cash_register', 'open'),
  ('CLOSE_CASH_REGISTER', 'Close cash register', 'cash_register', 'close'),
  ('TALLY_CASH_REGISTER', 'Record cash tally', 'cash_register', 'tally'),
  ('CASH_REGISTER_MOVEMENT', 'Record cash movement (drop/payout)', 'cash_register', 'movement'),
  ('FORCE_CLOSE_CASH_REGISTER', 'Force close cash register', 'cash_register', 'force_close'),

  ('TOGGLE_TRAINING_MODE', 'Enable/disable training mode for the current session', 'cash_register', 'training_mode')
ON CONFLICT (name) DO NOTHING;

-- Ensure Super Admin and Admin always have full access to all permissions.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.name IN ('Super Admin', 'Admin')
ON CONFLICT DO NOTHING;

-- Ensure role-based POS limits exist for common system roles (by name).
-- This is an upsert so that DBs created before limits existed get sane defaults.
INSERT INTO role_pos_limits (role_id, max_line_discount_pct, max_bill_discount_pct)
SELECT
  r.role_id,
  CASE
    WHEN r.name IN ('Super Admin', 'Admin') THEN 100
    WHEN r.name = 'Manager' THEN 50
    WHEN r.name = 'Sales' THEN 10
    WHEN r.name = 'Store' THEN 5
    ELSE 0
  END AS max_line_discount_pct,
  CASE
    WHEN r.name IN ('Super Admin', 'Admin') THEN 100
    WHEN r.name = 'Manager' THEN 50
    WHEN r.name = 'Sales' THEN 10
    WHEN r.name = 'Store' THEN 5
    ELSE 0
  END AS max_bill_discount_pct
FROM roles r
WHERE COALESCE(r.is_system_role, FALSE) = TRUE
ON CONFLICT (role_id) DO UPDATE
SET max_line_discount_pct = EXCLUDED.max_line_discount_pct,
    max_bill_discount_pct = EXCLUDED.max_bill_discount_pct,
    updated_at = CURRENT_TIMESTAMP;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- No-op: we don't delete permissions or grants on downgrade.

-- +goose StatementEnd

