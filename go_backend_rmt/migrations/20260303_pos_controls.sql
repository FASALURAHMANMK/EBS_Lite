-- +goose Up
-- +goose StatementBegin

-- Manager override permission (used as a short-lived token scope).
INSERT INTO permissions (name, description, module, action) VALUES
  ('OVERRIDE_DISCOUNTS', 'Approve discounts above staff role limits', 'pos', 'override_discount')
ON CONFLICT (name) DO NOTHING;

-- Per-role POS limits (percentages).
CREATE TABLE IF NOT EXISTS role_pos_limits (
  role_id INTEGER PRIMARY KEY REFERENCES roles(role_id) ON DELETE CASCADE,
  max_line_discount_pct NUMERIC NOT NULL DEFAULT 0,
  max_bill_discount_pct NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed reasonable defaults for common system roles (if they exist).
-- role_id: 1 Super Admin, 2 Admin, 3 Manager, 4 Sales, 5 Store/Cashier
INSERT INTO role_pos_limits (role_id, max_line_discount_pct, max_bill_discount_pct)
VALUES
  (1, 100, 100),
  (2, 100, 100),
  (3, 50, 50),
  (4, 10, 10),
  (5, 5, 5)
ON CONFLICT (role_id) DO NOTHING;

-- Grant override permission to Super Admin + Admin + Manager by default.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.name = 'OVERRIDE_DISCOUNTS'
WHERE r.role_id IN (1,2,3)
ON CONFLICT DO NOTHING;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.permission_id AND p.name IN ('OVERRIDE_DISCOUNTS');

DROP TABLE IF EXISTS role_pos_limits;

DELETE FROM permissions
WHERE name IN ('OVERRIDE_DISCOUNTS');

-- +goose StatementEnd

