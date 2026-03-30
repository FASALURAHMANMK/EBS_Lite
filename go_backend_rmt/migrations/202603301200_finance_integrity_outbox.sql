-- +goose Up

CREATE TABLE IF NOT EXISTS finance_integrity_outbox (
    outbox_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
    event_type VARCHAR(80) NOT NULL,
    aggregate_type VARCHAR(40) NOT NULL,
    aggregate_id INTEGER NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'FAILED', 'COMPLETED')),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    last_attempt_at TIMESTAMP,
    next_attempt_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (event_type, aggregate_type, aggregate_id)
);

CREATE INDEX IF NOT EXISTS idx_finance_integrity_outbox_company_status
    ON finance_integrity_outbox(company_id, status, next_attempt_at, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_finance_integrity_outbox_aggregate
    ON finance_integrity_outbox(company_id, aggregate_type, aggregate_id);

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_location_idempotency_key
    ON payments(location_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_sale_customer_type
    ON loyalty_redemptions(sale_id, customer_id, redemption_type)
    WHERE sale_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_coupon_codes_redeemed_sale
    ON coupon_codes(redeemed_sale_id)
    WHERE redeemed_sale_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_raffle_coupons_sale
    ON raffle_coupons(sale_id);

-- +goose Down

DROP INDEX IF EXISTS idx_raffle_coupons_sale;
DROP INDEX IF EXISTS idx_coupon_codes_redeemed_sale;
DROP INDEX IF EXISTS idx_loyalty_redemptions_sale_customer_type;
DROP INDEX IF EXISTS idx_payments_location_idempotency_key;

ALTER TABLE payments
    DROP COLUMN IF EXISTS idempotency_key;

DROP INDEX IF EXISTS idx_finance_integrity_outbox_aggregate;
DROP INDEX IF EXISTS idx_finance_integrity_outbox_company_status;
DROP TABLE IF EXISTS finance_integrity_outbox;
