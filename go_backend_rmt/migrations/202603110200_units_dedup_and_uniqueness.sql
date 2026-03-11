-- +goose Up

CREATE TEMP TABLE tmp_duplicate_units AS
WITH normalized_units AS (
    SELECT
        unit_id,
        MIN(unit_id) OVER (
            PARTITION BY
                LOWER(BTRIM(name)),
                LOWER(BTRIM(COALESCE(symbol, ''))),
                COALESCE(base_unit_id, 0),
                COALESCE(conversion_factor, 1.0)
        ) AS keep_unit_id
    FROM units
)
SELECT unit_id, keep_unit_id
FROM normalized_units
WHERE unit_id <> keep_unit_id;

UPDATE products p
SET unit_id = d.keep_unit_id
FROM tmp_duplicate_units d
WHERE p.unit_id = d.unit_id;

UPDATE units u
SET base_unit_id = d.keep_unit_id
FROM tmp_duplicate_units d
WHERE u.base_unit_id = d.unit_id;

DELETE FROM units u
USING tmp_duplicate_units d
WHERE u.unit_id = d.unit_id;

DROP TABLE tmp_duplicate_units;

CREATE UNIQUE INDEX IF NOT EXISTS idx_units_semantic_unique
ON units (
    LOWER(BTRIM(name)),
    LOWER(BTRIM(COALESCE(symbol, ''))),
    COALESCE(base_unit_id, 0),
    COALESCE(conversion_factor, 1.0)
);

-- +goose Down

DROP INDEX IF EXISTS idx_units_semantic_unique;
