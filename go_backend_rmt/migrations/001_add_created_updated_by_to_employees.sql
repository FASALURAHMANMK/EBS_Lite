ALTER TABLE employees
    ADD COLUMN created_by INTEGER REFERENCES users(user_id);
ALTER TABLE employees
    ADD COLUMN updated_by INTEGER REFERENCES users(user_id);
UPDATE employees SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE employees ALTER COLUMN created_by SET NOT NULL;
