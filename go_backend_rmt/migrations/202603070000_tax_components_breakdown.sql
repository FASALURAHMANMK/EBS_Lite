-- +goose Up
-- Tax breakdown components (e.g., GST -> CGST/SGST)

CREATE TABLE IF NOT EXISTS tax_components (
	component_id SERIAL PRIMARY KEY,
	tax_id INTEGER NOT NULL REFERENCES taxes(tax_id) ON DELETE CASCADE,
	name VARCHAR(100) NOT NULL,
	percentage NUMERIC(5,2) NOT NULL CHECK (percentage >= 0 AND percentage <= 100),
	sort_order INTEGER NOT NULL DEFAULT 0,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tax_components_tax_id ON tax_components(tax_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tax_components_tax_lower_name ON tax_components(tax_id, LOWER(name));

-- +goose Down
-- No-op (forward-only for production safety).

