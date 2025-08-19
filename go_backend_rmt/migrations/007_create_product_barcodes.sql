BEGIN;

CREATE TABLE product_barcodes (
    barcode_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    barcode VARCHAR(100) NOT NULL,
    pack_size INTEGER NOT NULL DEFAULT 1,
    cost_price NUMERIC(12,2),
    selling_price NUMERIC(12,2),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO product_barcodes (product_id, barcode, pack_size, cost_price, selling_price, is_primary)
SELECT product_id, barcode, 1, cost_price, selling_price, TRUE
FROM products
WHERE barcode IS NOT NULL AND barcode <> '';

DROP INDEX IF EXISTS idx_products_barcode;
ALTER TABLE products DROP COLUMN IF EXISTS barcode;

CREATE UNIQUE INDEX ux_product_barcodes_barcode ON product_barcodes(barcode);
CREATE UNIQUE INDEX ux_product_barcodes_product_id_barcode ON product_barcodes(product_id, barcode);

COMMIT;
