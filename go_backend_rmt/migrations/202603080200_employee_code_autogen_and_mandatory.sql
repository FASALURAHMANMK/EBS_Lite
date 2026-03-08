-- +goose Up
-- Ensure employee_code is mandatory and auto-generated when omitted/blank.

CREATE SEQUENCE IF NOT EXISTS employee_code_seq;

ALTER TABLE IF EXISTS employees
  ALTER COLUMN employee_code SET DEFAULT (
    'EMP-' || LPAD(nextval('employee_code_seq')::text, 6, '0')
  );

UPDATE employees
SET employee_code = 'EMP-' || LPAD(nextval('employee_code_seq')::text, 6, '0')
WHERE employee_code IS NULL OR TRIM(employee_code) = '';

ALTER TABLE IF EXISTS employees
  ALTER COLUMN employee_code SET NOT NULL;

-- +goose Down
-- No-op (data change).

