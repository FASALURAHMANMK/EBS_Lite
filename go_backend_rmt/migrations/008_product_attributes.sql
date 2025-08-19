-- Migration to align product attributes schema and add index
-- Adds type, is_required, options to product_attributes and creates
-- product_attribute_values table with composite index on (product_id, attribute_id)

-- Update product_attributes table
ALTER TABLE IF EXISTS product_attributes
    ADD COLUMN IF NOT EXISTS type VARCHAR(50) NOT NULL DEFAULT 'TEXT',
    ADD COLUMN IF NOT EXISTS is_required BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS options JSONB,
    DROP COLUMN IF EXISTS value;

-- Create product_attribute_values table if it does not exist
CREATE TABLE IF NOT EXISTS product_attribute_values (
    value_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    attribute_id INTEGER NOT NULL REFERENCES product_attributes(attribute_id),
    value TEXT NOT NULL
);

-- Add composite index for fast lookups
CREATE INDEX IF NOT EXISTS idx_product_attribute_values_product_attribute
    ON product_attribute_values(product_id, attribute_id);
