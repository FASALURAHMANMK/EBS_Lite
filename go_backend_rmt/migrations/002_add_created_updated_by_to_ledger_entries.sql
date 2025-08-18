ALTER TABLE ledger_entries
    ADD COLUMN created_by INTEGER REFERENCES users(user_id);
ALTER TABLE ledger_entries
    ADD COLUMN updated_by INTEGER REFERENCES users(user_id);
UPDATE ledger_entries SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE ledger_entries ALTER COLUMN created_by SET NOT NULL;
