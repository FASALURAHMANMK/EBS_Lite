-- +goose Up
-- +goose StatementBegin

INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_DESIGNATIONS', 'View designations', 'designations', 'view'),
  ('MANAGE_DESIGNATIONS', 'Create/update/delete designations', 'designations', 'manage')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.name IN ('VIEW_DESIGNATIONS', 'MANAGE_DESIGNATIONS')
WHERE r.name IN ('Super Admin', 'Admin')
ON CONFLICT DO NOTHING;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- No-op.
-- +goose StatementEnd

