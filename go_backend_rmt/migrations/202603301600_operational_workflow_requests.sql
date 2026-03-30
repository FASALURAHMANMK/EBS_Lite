-- +goose Up
CREATE TABLE IF NOT EXISTS workflow_requests (
    approval_id SERIAL PRIMARY KEY,
    company_id INT NOT NULL REFERENCES companies(company_id),
    location_id INT REFERENCES locations(location_id),
    module VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INT,
    action_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    summary TEXT,
    request_reason TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    approver_role_id INT NOT NULL REFERENCES roles(role_id),
    payload JSONB,
    result_snapshot JSONB,
    due_at TIMESTAMP,
    escalation_level INT NOT NULL DEFAULT 0,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    approved_by INT REFERENCES users(user_id),
    approved_at TIMESTAMP,
    decision_reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workflow_requests_company_status
    ON workflow_requests(company_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_workflow_requests_entity
    ON workflow_requests(company_id, entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_workflow_requests_approver_role
    ON workflow_requests(company_id, approver_role_id, status);

CREATE INDEX IF NOT EXISTS idx_workflow_requests_due
    ON workflow_requests(company_id, due_at)
    WHERE due_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS workflow_request_events (
    event_id SERIAL PRIMARY KEY,
    approval_id INT NOT NULL REFERENCES workflow_requests(approval_id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    actor_id INT REFERENCES users(user_id),
    from_status VARCHAR(30),
    to_status VARCHAR(30),
    remarks TEXT,
    payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workflow_request_events_request
    ON workflow_request_events(approval_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS workflow_request_events;
DROP TABLE IF EXISTS workflow_requests;
