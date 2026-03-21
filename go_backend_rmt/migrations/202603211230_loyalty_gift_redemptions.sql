-- +goose Up

ALTER TABLE loyalty_settings
    ADD COLUMN IF NOT EXISTS redemption_type VARCHAR(20) NOT NULL DEFAULT 'DISCOUNT';

ALTER TABLE loyalty_settings
    DROP CONSTRAINT IF EXISTS loyalty_settings_redemption_type_check;

ALTER TABLE loyalty_settings
    ADD CONSTRAINT loyalty_settings_redemption_type_check
    CHECK (redemption_type IN ('DISCOUNT', 'GIFT'));

ALTER TABLE loyalty_redemptions
    ADD COLUMN IF NOT EXISTS redemption_type VARCHAR(20) NOT NULL DEFAULT 'DISCOUNT',
    ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE loyalty_redemptions
    DROP CONSTRAINT IF EXISTS loyalty_redemptions_redemption_type_check;

ALTER TABLE loyalty_redemptions
    ADD CONSTRAINT loyalty_redemptions_redemption_type_check
    CHECK (redemption_type IN ('DISCOUNT', 'GIFT'));

CREATE TABLE IF NOT EXISTS loyalty_redemption_items (
    redemption_item_id SERIAL PRIMARY KEY,
    redemption_id INTEGER NOT NULL REFERENCES loyalty_redemptions(redemption_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    barcode_id INTEGER REFERENCES product_barcodes(barcode_id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    variant_name VARCHAR(255),
    quantity NUMERIC(12,3) NOT NULL,
    points_used NUMERIC(10,2) NOT NULL,
    value_redeemed NUMERIC(12,2) NOT NULL,
    unit_cost NUMERIC(12,2) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL,
    serial_numbers TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    batch_allocations JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE loyalty_redemption_items
    DROP CONSTRAINT IF EXISTS loyalty_redemption_items_positive_values_check;

ALTER TABLE loyalty_redemption_items
    ADD CONSTRAINT loyalty_redemption_items_positive_values_check
    CHECK (
        quantity > 0
        AND points_used > 0
        AND value_redeemed >= 0
        AND unit_cost >= 0
        AND total_cost >= 0
    );

CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_type_date
    ON loyalty_redemptions(redemption_type, redeemed_at DESC);

CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_location
    ON loyalty_redemptions(location_id, redeemed_at DESC);

CREATE INDEX IF NOT EXISTS idx_loyalty_redemption_items_redemption
    ON loyalty_redemption_items(redemption_id);

-- +goose Down

DROP INDEX IF EXISTS idx_loyalty_redemption_items_redemption;
DROP INDEX IF EXISTS idx_loyalty_redemptions_location;
DROP INDEX IF EXISTS idx_loyalty_redemptions_type_date;

DROP TABLE IF EXISTS loyalty_redemption_items;

ALTER TABLE loyalty_redemptions
    DROP CONSTRAINT IF EXISTS loyalty_redemptions_redemption_type_check;

ALTER TABLE loyalty_redemptions
    DROP COLUMN IF EXISTS notes,
    DROP COLUMN IF EXISTS location_id,
    DROP COLUMN IF EXISTS redemption_type;

ALTER TABLE loyalty_settings
    DROP CONSTRAINT IF EXISTS loyalty_settings_redemption_type_check;

ALTER TABLE loyalty_settings
    DROP COLUMN IF EXISTS redemption_type;
