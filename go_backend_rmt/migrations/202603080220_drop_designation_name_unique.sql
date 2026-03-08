-- +goose Up
-- Allow duplicate designation names (same name can exist in multiple departments).
-- Drop the legacy UNIQUE(company_id, name) constraint that was created on employee_roles
-- (and kept after renaming to designations).

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.designations') IS NOT NULL THEN
    ALTER TABLE designations DROP CONSTRAINT IF EXISTS employee_roles_company_id_name_key;
    ALTER TABLE designations DROP CONSTRAINT IF EXISTS designations_company_id_name_key;
  END IF;

  IF to_regclass('public.employee_roles') IS NOT NULL THEN
    ALTER TABLE employee_roles DROP CONSTRAINT IF EXISTS employee_roles_company_id_name_key;
  END IF;
END
$$;
-- +goose StatementEnd

-- Helpful non-unique index for listing/searching designations under departments.
CREATE INDEX IF NOT EXISTS idx_designations_company_department_name
  ON designations(company_id, department_id, name);

-- +goose Down
-- No-op (relax constraint).

