-- +goose Up
-- HR enhancements:
-- - Departments and employee roles (job roles) master data
-- - Link employees to department/role
-- - Leave approvals audit fields
-- - User flags for temp passwords (best-effort)

-- Departments master table (company-scoped)
CREATE TABLE IF NOT EXISTS departments (
    department_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE(company_id, name)
);

-- Employee roles (job roles/positions) master table (company-scoped)
CREATE TABLE IF NOT EXISTS employee_roles (
    employee_role_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE(company_id, name)
);

ALTER TABLE IF EXISTS employees
    ADD COLUMN IF NOT EXISTS department_id INTEGER,
    ADD COLUMN IF NOT EXISTS employee_role_id INTEGER;

-- +goose StatementBegin
DO $$
BEGIN
    IF to_regclass('public.departments') IS NOT NULL THEN
        BEGIN
            ALTER TABLE employees
                ADD CONSTRAINT employees_department_id_fkey
                FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL;
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF to_regclass('public.employee_roles') IS NOT NULL THEN
        BEGIN
            ALTER TABLE employees
                ADD CONSTRAINT employees_employee_role_id_fkey
                FOREIGN KEY (employee_role_id) REFERENCES employee_roles(employee_role_id) ON DELETE SET NULL;
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
END;
$$;
-- +goose StatementEnd

CREATE INDEX IF NOT EXISTS idx_departments_company ON departments(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_roles_company ON employee_roles(company_id);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_employee_role ON employees(employee_role_id);

-- Leave approvals audit fields
ALTER TABLE IF EXISTS leaves
    ADD COLUMN IF NOT EXISTS approved_by INTEGER REFERENCES users(user_id),
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS decision_notes TEXT;

-- Optional flag for users created with temporary password.
ALTER TABLE IF EXISTS users
    ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

-- +goose Down
-- No-op (additive).
