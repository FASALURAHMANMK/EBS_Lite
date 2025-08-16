-- Optional triggers to ensure auditing at the database level
-- These triggers log insert/update/delete operations for critical tables
-- as a fallback when application-level logging is bypassed.

-- Users table trigger
CREATE OR REPLACE FUNCTION fn_log_users_audit() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(action, table_name, record_id, old_value, new_value, timestamp)
    VALUES (TG_OP, 'users', COALESCE(NEW.user_id, OLD.user_id), to_jsonb(OLD), to_jsonb(NEW), CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_audit
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION fn_log_users_audit();

-- Products table trigger
CREATE OR REPLACE FUNCTION fn_log_products_audit() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(action, table_name, record_id, old_value, new_value, timestamp)
    VALUES (TG_OP, 'products', COALESCE(NEW.product_id, OLD.product_id), to_jsonb(OLD), to_jsonb(NEW), CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_products_audit
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW EXECUTE FUNCTION fn_log_products_audit();

-- Sales table trigger
CREATE OR REPLACE FUNCTION fn_log_sales_audit() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(action, table_name, record_id, old_value, new_value, timestamp)
    VALUES (TG_OP, 'sales', COALESCE(NEW.sale_id, OLD.sale_id), to_jsonb(OLD), to_jsonb(NEW), CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sales_audit
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION fn_log_sales_audit();
