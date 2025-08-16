ALTER TABLE workflow_templates ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_templates ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_templates SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_templates ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE workflow_states ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_states ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_states SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_states ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE workflow_approvals ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_approvals ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_approvals SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_approvals ALTER COLUMN created_by SET NOT NULL;
