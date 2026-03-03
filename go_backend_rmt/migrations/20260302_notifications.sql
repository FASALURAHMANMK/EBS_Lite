-- +goose Up
-- +goose StatementBegin

INSERT INTO permissions (name, description, module, action) VALUES
  ('VIEW_NOTIFICATIONS', 'View notifications', 'notifications', 'view'),
  ('MARK_NOTIFICATIONS_READ', 'Mark notifications as read', 'notifications', 'mark_read')
ON CONFLICT (name) DO NOTHING;

-- Grant to all system roles by default (safer than only 1/2 so cashiers can see alerts).
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON p.name IN ('VIEW_NOTIFICATIONS', 'MARK_NOTIFICATIONS_READ')
WHERE COALESCE(r.is_system_role, FALSE) = TRUE
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS notification_reads (
  company_id INTEGER NOT NULL REFERENCES companies(company_id),
  user_id INTEGER NOT NULL REFERENCES users(user_id),
  notification_key TEXT NOT NULL,
  read_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (company_id, user_id, notification_key)
);

CREATE INDEX IF NOT EXISTS idx_notification_reads_user_company
  ON notification_reads(company_id, user_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_notification_reads_user_company;
DROP TABLE IF EXISTS notification_reads;

DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.permission_id AND p.name IN ('VIEW_NOTIFICATIONS', 'MARK_NOTIFICATIONS_READ');

DELETE FROM permissions
WHERE name IN ('VIEW_NOTIFICATIONS', 'MARK_NOTIFICATIONS_READ');

-- +goose StatementEnd

