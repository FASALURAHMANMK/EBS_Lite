-- Schema bootstrap for new Stock Adjustment Documents and permissions
-- Run automatically by docker-compose via /docker-entrypoint-initdb.d

BEGIN;

-- Create table: stock_adjustment_documents
CREATE TABLE IF NOT EXISTS stock_adjustment_documents (
  document_id      SERIAL PRIMARY KEY,
  document_number  VARCHAR(64) NOT NULL UNIQUE,
  location_id      INTEGER NOT NULL,
  reason           VARCHAR(255) NOT NULL,
  created_by       INTEGER NOT NULL,
  created_at       TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create table: stock_adjustment_document_items
CREATE TABLE IF NOT EXISTS stock_adjustment_document_items (
  item_id      SERIAL PRIMARY KEY,
  document_id  INTEGER NOT NULL REFERENCES stock_adjustment_documents(document_id) ON DELETE CASCADE,
  product_id   INTEGER NOT NULL,
  adjustment   DOUBLE PRECISION NOT NULL
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_sad_location_id ON stock_adjustment_documents(location_id);
CREATE INDEX IF NOT EXISTS idx_sadi_document_id ON stock_adjustment_document_items(document_id);
CREATE INDEX IF NOT EXISTS idx_sadi_product_id ON stock_adjustment_document_items(product_id);

-- If your schema has products and locations tables, you may enable FKs below.
-- Uncomment if present (kept commented to avoid failing on missing tables in early setups)
-- ALTER TABLE stock_adjustment_documents
--   ADD CONSTRAINT fk_sad_location
--   FOREIGN KEY (location_id) REFERENCES locations(location_id) ON DELETE RESTRICT;
-- ALTER TABLE stock_adjustment_document_items
--   ADD CONSTRAINT fk_sadi_product
--   FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT;

-- Ensure permissions exist
-- VIEW_INVENTORY
INSERT INTO permissions (name, description, module, action)
SELECT 'VIEW_INVENTORY', 'View inventory and stock', 'INVENTORY', 'VIEW'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'VIEW_INVENTORY');

-- ADJUST_STOCK
INSERT INTO permissions (name, description, module, action)
SELECT 'ADJUST_STOCK', 'Create stock adjustments', 'INVENTORY', 'ADJUST'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'ADJUST_STOCK');

-- Assign to Admin role if present
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r, permissions p
WHERE r.name = 'Admin' AND p.name = 'VIEW_INVENTORY'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.role_id AND rp.permission_id = p.permission_id
  );

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r, permissions p
WHERE r.name = 'Admin' AND p.name = 'ADJUST_STOCK'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.role_id AND rp.permission_id = p.permission_id
  );

COMMIT;

