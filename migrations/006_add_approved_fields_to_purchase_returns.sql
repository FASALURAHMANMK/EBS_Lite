ALTER TABLE purchase_returns
    ADD COLUMN approved_by INT REFERENCES users(user_id),
    ADD COLUMN approved_at TIMESTAMP;
