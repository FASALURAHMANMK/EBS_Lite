CREATE UNIQUE INDEX ux_product_barcodes_primary ON product_barcodes(product_id) WHERE is_primary;
