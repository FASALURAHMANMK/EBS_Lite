ALTER TABLE customers ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE customers SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE customers ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE suppliers SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE suppliers ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE products ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE products SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE products ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE categories ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE categories SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE categories ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE brands ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE brands ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE brands SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE brands ALTER COLUMN created_by SET NOT NULL;
