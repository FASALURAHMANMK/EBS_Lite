-- +goose Up
-- +goose StatementBegin

-- HR master data permissions
INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_DEPARTMENTS', 'View departments', 'departments', 'view'),
  ('MANAGE_DEPARTMENTS', 'Create/update/delete departments', 'departments', 'manage'),

  ('VIEW_EMPLOYEE_ROLES', 'View employee roles', 'employee_roles', 'view'),
  ('MANAGE_EMPLOYEE_ROLES', 'Create/update/delete employee roles', 'employee_roles', 'manage'),

  ('VIEW_LEAVES', 'View leave requests', 'leaves', 'view'),
  ('APPROVE_LEAVES', 'Approve/reject leave requests', 'leaves', 'approve'),

  ('CALCULATE_PAYROLLS', 'Calculate payroll from attendance/leaves', 'payroll', 'calculate')
ON CONFLICT (name) DO NOTHING;

-- Ensure Super Admin and Admin always have full access to all permissions.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.name IN ('Super Admin', 'Admin')
ON CONFLICT DO NOTHING;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- No-op.
-- +goose StatementEnd

