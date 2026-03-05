-- +goose Up
-- +goose StatementBegin

-- Backfill user.location_id when missing.
-- This prevents "location not found" errors for users who were created before we started
-- assigning a default location during company creation.
UPDATE users u
SET location_id = sub.location_id,
    updated_at = CURRENT_TIMESTAMP
FROM (
    SELECT DISTINCT ON (u2.user_id)
           u2.user_id,
           l.location_id
    FROM users u2
    JOIN locations l ON l.company_id = u2.company_id AND l.is_active = TRUE
    WHERE u2.company_id IS NOT NULL
      AND u2.location_id IS NULL
      AND u2.is_deleted = FALSE
    ORDER BY u2.user_id, l.location_id
) sub
WHERE u.user_id = sub.user_id;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- No-op: don't unset user locations on downgrade.
-- +goose StatementEnd

