-- +goose Up
-- Rename Employee Roles -> Designations and allow Designations under Departments.

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.employee_roles') IS NOT NULL AND to_regclass('public.designations') IS NULL THEN
    ALTER TABLE employee_roles RENAME TO designations;
  END IF;
END
$$;
-- +goose StatementEnd

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.designations') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'designations'
        AND column_name = 'employee_role_id'
    ) THEN
      ALTER TABLE designations RENAME COLUMN employee_role_id TO designation_id;
    END IF;
  END IF;
END
$$;
-- +goose StatementEnd

ALTER TABLE IF EXISTS designations
  ADD COLUMN IF NOT EXISTS department_id INTEGER;

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.departments') IS NOT NULL AND to_regclass('public.designations') IS NOT NULL THEN
    BEGIN
      ALTER TABLE designations
        ADD CONSTRAINT designations_department_id_fkey
        FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END
$$;
-- +goose StatementEnd

-- Rename employees.employee_role_id -> employees.designation_id (if present).
-- +goose StatementBegin
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'employees'
      AND column_name = 'employee_role_id'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'employees'
      AND column_name = 'designation_id'
  ) THEN
    ALTER TABLE employees RENAME COLUMN employee_role_id TO designation_id;
  END IF;
END
$$;
-- +goose StatementEnd

ALTER TABLE employees
  DROP CONSTRAINT IF EXISTS employees_employee_role_id_fkey;

-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.designations') IS NOT NULL THEN
    BEGIN
      ALTER TABLE employees
        ADD CONSTRAINT employees_designation_id_fkey
        FOREIGN KEY (designation_id) REFERENCES designations(designation_id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END
$$;
-- +goose StatementEnd

CREATE INDEX IF NOT EXISTS idx_designations_company ON designations(company_id);
CREATE INDEX IF NOT EXISTS idx_designations_department ON designations(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_designation ON employees(designation_id);

-- +goose Down
-- No-op (rename migration).

