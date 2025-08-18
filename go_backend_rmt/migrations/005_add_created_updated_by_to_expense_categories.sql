ALTER TABLE expense_categories
    ADD COLUMN created_by INTEGER REFERENCES users(user_id);
ALTER TABLE expense_categories
    ADD COLUMN updated_by INTEGER REFERENCES users(user_id);
UPDATE expense_categories SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE expense_categories ALTER COLUMN created_by SET NOT NULL;
