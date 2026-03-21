-- +goose Up

ALTER TABLE promotions
    DROP CONSTRAINT IF EXISTS promotions_discount_type_check;

ALTER TABLE promotions
    ADD CONSTRAINT promotions_discount_type_check
    CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'FIXED_PRICE', 'BUY_X_GET_Y'));

ALTER TABLE promotions
    ADD COLUMN IF NOT EXISTS discount_scope VARCHAR(20) NOT NULL DEFAULT 'ORDER',
    ADD COLUMN IF NOT EXISTS priority INTEGER NOT NULL DEFAULT 0;

ALTER TABLE promotions
    DROP CONSTRAINT IF EXISTS promotions_discount_scope_check;

ALTER TABLE promotions
    ADD CONSTRAINT promotions_discount_scope_check
    CHECK (discount_scope IN ('ORDER', 'ITEM'));

CREATE TABLE IF NOT EXISTS promotion_product_rules (
    promotion_rule_id SERIAL PRIMARY KEY,
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    barcode_id INTEGER REFERENCES product_barcodes(barcode_id) ON DELETE SET NULL,
    discount_type VARCHAR(50) NOT NULL CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'FIXED_PRICE')),
    value NUMERIC(12,2) NOT NULL,
    min_qty NUMERIC(12,3) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_promotion_product_rules_promotion
    ON promotion_product_rules(promotion_id);

CREATE INDEX IF NOT EXISTS idx_promotion_product_rules_product
    ON promotion_product_rules(product_id, barcode_id);

CREATE TABLE IF NOT EXISTS coupon_series (
    coupon_series_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    prefix VARCHAR(20) NOT NULL DEFAULT 'CPN',
    code_length INTEGER NOT NULL DEFAULT 10,
    discount_type VARCHAR(50) NOT NULL CHECK (discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT')),
    discount_value NUMERIC(12,2) NOT NULL,
    min_purchase_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    max_discount_amount NUMERIC(12,2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_coupons INTEGER NOT NULL DEFAULT 0,
    usage_limit_per_coupon INTEGER NOT NULL DEFAULT 1,
    usage_limit_per_customer INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coupon_series_company_active
    ON coupon_series(company_id, is_active, start_date, end_date);

CREATE TABLE IF NOT EXISTS coupon_codes (
    coupon_code_id SERIAL PRIMARY KEY,
    coupon_series_id INTEGER NOT NULL REFERENCES coupon_series(coupon_series_id) ON DELETE CASCADE,
    code VARCHAR(64) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'REDEEMED', 'VOID')),
    redeem_count INTEGER NOT NULL DEFAULT 0,
    issued_to_customer_id INTEGER REFERENCES customers(customer_id) ON DELETE SET NULL,
    issued_sale_id INTEGER REFERENCES sales(sale_id) ON DELETE SET NULL,
    redeemed_sale_id INTEGER REFERENCES sales(sale_id) ON DELETE SET NULL,
    issued_at TIMESTAMP,
    redeemed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coupon_codes_series_status
    ON coupon_codes(coupon_series_id, status);

CREATE INDEX IF NOT EXISTS idx_coupon_codes_customer
    ON coupon_codes(issued_to_customer_id, status);

CREATE TABLE IF NOT EXISTS raffle_definitions (
    raffle_definition_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    prefix VARCHAR(20) NOT NULL DEFAULT 'RF',
    code_length INTEGER NOT NULL DEFAULT 10,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    trigger_amount NUMERIC(12,2) NOT NULL,
    coupons_per_trigger INTEGER NOT NULL DEFAULT 1,
    max_coupons_per_sale INTEGER,
    default_auto_fill_customer_data BOOLEAN NOT NULL DEFAULT FALSE,
    print_after_invoice BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_raffle_definitions_company_active
    ON raffle_definitions(company_id, is_active, start_date, end_date);

CREATE TABLE IF NOT EXISTS raffle_coupons (
    raffle_coupon_id SERIAL PRIMARY KEY,
    raffle_definition_id INTEGER NOT NULL REFERENCES raffle_definitions(raffle_definition_id) ON DELETE CASCADE,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    customer_id INTEGER REFERENCES customers(customer_id) ON DELETE SET NULL,
    coupon_code VARCHAR(64) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'ISSUED' CHECK (status IN ('ISSUED', 'WINNER', 'VOID')),
    auto_filled BOOLEAN NOT NULL DEFAULT FALSE,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(50),
    customer_email VARCHAR(255),
    customer_address TEXT,
    winner_name VARCHAR(255),
    winner_notes TEXT,
    issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    winner_marked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_raffle_coupons_definition_sale
    ON raffle_coupons(raffle_definition_id, sale_id);

CREATE INDEX IF NOT EXISTS idx_raffle_coupons_status
    ON raffle_coupons(status, issued_at DESC);

-- +goose Down

DROP INDEX IF EXISTS idx_raffle_coupons_status;
DROP INDEX IF EXISTS idx_raffle_coupons_definition_sale;
DROP TABLE IF EXISTS raffle_coupons;

DROP INDEX IF EXISTS idx_raffle_definitions_company_active;
DROP TABLE IF EXISTS raffle_definitions;

DROP INDEX IF EXISTS idx_coupon_codes_customer;
DROP INDEX IF EXISTS idx_coupon_codes_series_status;
DROP TABLE IF EXISTS coupon_codes;

DROP INDEX IF EXISTS idx_coupon_series_company_active;
DROP TABLE IF EXISTS coupon_series;

DROP INDEX IF EXISTS idx_promotion_product_rules_product;
DROP INDEX IF EXISTS idx_promotion_product_rules_promotion;
DROP TABLE IF EXISTS promotion_product_rules;

ALTER TABLE promotions
    DROP CONSTRAINT IF EXISTS promotions_discount_scope_check;

ALTER TABLE promotions
    DROP COLUMN IF EXISTS discount_scope,
    DROP COLUMN IF EXISTS priority;

ALTER TABLE promotions
    DROP CONSTRAINT IF EXISTS promotions_discount_type_check;

ALTER TABLE promotions
    ADD CONSTRAINT promotions_discount_type_check
    CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'BUY_X_GET_Y'));
