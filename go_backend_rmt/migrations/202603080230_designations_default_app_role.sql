-- +goose Up
-- Add optional default app role per designation to streamline "Is app user" onboarding.

ALTER TABLE IF EXISTS designations
  ADD COLUMN IF NOT EXISTS default_app_role_id INTEGER;

-- FK is best-effort (in case roles table is missing in some environments).
-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.designations') IS NOT NULL AND to_regclass('public.roles') IS NOT NULL THEN
    BEGIN
      ALTER TABLE designations
        ADD CONSTRAINT designations_default_app_role_id_fkey
        FOREIGN KEY (default_app_role_id) REFERENCES roles(role_id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END
$$;
-- +goose StatementEnd

CREATE INDEX IF NOT EXISTS idx_designations_default_app_role_id
  ON designations(default_app_role_id);

-- +goose Down
-- No-op (additive).

