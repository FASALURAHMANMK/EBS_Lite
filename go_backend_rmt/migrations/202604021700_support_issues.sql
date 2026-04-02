-- +goose Up
CREATE TABLE IF NOT EXISTS support_issues (
    issue_id SERIAL PRIMARY KEY,
    issue_number VARCHAR(32) UNIQUE,
    company_id INT NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INT REFERENCES locations(location_id) ON DELETE SET NULL,
    reported_by_user_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    title VARCHAR(160) NOT NULL,
    severity VARCHAR(16) NOT NULL,
    details TEXT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'OPEN',
    app_version VARCHAR(64) NOT NULL DEFAULT '',
    build_number VARCHAR(64) NOT NULL DEFAULT '',
    release_channel VARCHAR(64) NOT NULL DEFAULT '',
    platform VARCHAR(64) NOT NULL DEFAULT '',
    platform_version VARCHAR(255) NOT NULL DEFAULT '',
    backend_reachable BOOLEAN NOT NULL DEFAULT FALSE,
    queued_sync_items INT NOT NULL DEFAULT 0,
    last_sync_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_support_issues_company_created_at
    ON support_issues (company_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_issues_company_status
    ON support_issues (company_id, status);

CREATE INDEX IF NOT EXISTS idx_support_issues_company_severity
    ON support_issues (company_id, severity);

DROP TRIGGER IF EXISTS update_support_issues_updated_at ON support_issues;
CREATE TRIGGER update_support_issues_updated_at
    BEFORE UPDATE ON support_issues
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- +goose Down
DROP TRIGGER IF EXISTS update_support_issues_updated_at ON support_issues;
DROP TABLE IF EXISTS support_issues;
