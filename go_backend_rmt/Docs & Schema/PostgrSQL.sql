-- ===============================================
-- ERP System - Complete PostgreSQL Schema
-- ===============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated;
    END IF;
END$$;

-- ===============================================
-- MASTER TABLES
-- ===============================================

-- Languages Table
CREATE TABLE languages (
    language_code VARCHAR(10) PRIMARY KEY,
    language_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Currencies Table
CREATE TABLE currencies (
    currency_id SERIAL PRIMARY KEY,
    code VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10),
    exchange_rate NUMERIC(12,6) DEFAULT 1.0,
    is_base_currency BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Companies Table
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    logo TEXT,
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(100),
    tax_number VARCHAR(100),
    currency_id INTEGER REFERENCES currencies(currency_id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Locations Table
CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Roles Table
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Permissions Table
CREATE TABLE permissions (
    permission_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    module VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL
);

-- Role Permissions Junction Table
CREATE TABLE role_permissions (
    role_id INTEGER REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Users Table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id),
    role_id INTEGER REFERENCES roles(role_id),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    preferred_language VARCHAR(10) REFERENCES languages(language_code),
    secondary_language VARCHAR(10) REFERENCES languages(language_code),
    max_allowed_devices INTEGER DEFAULT 3,
    is_locked BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- User Preferences Table
CREATE TABLE user_preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value TEXT,
    UNIQUE(user_id, key)
);

-- Device Sessions Table
CREATE TABLE device_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_sync_time TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_stale BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories Table
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id INTEGER REFERENCES categories(category_id),
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Brands Table
CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Units Table
CREATE TABLE units (
    unit_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    symbol VARCHAR(10),
    base_unit_id INTEGER REFERENCES units(unit_id),
    conversion_factor NUMERIC(12,6) DEFAULT 1.0
);

-- Product Attributes Table
CREATE TABLE product_attributes (
    attribute_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('TEXT', 'NUMBER', 'DATE', 'BOOLEAN', 'SELECT')),
    is_required BOOLEAN DEFAULT FALSE,
    options JSONB, -- For SELECT type attributes
    is_active BOOLEAN DEFAULT TRUE,
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Products Table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(category_id),
    brand_id INTEGER REFERENCES brands(brand_id),
    unit_id INTEGER REFERENCES units(unit_id),
    tax_id INTEGER NOT NULL REFERENCES taxes(tax_id),
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100),
    description TEXT,
    cost_price NUMERIC(12,2),
    selling_price NUMERIC(12,2),
    reorder_level INTEGER DEFAULT 0,
    weight NUMERIC(10,3),
    dimensions VARCHAR(100),
    is_serialized BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Product Barcodes Table
CREATE TABLE product_barcodes (
    barcode_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    barcode VARCHAR(100) NOT NULL,
    pack_size INTEGER NOT NULL DEFAULT 1,
    cost_price NUMERIC(12,2),
    selling_price NUMERIC(12,2),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE
);

-- Product Attribute Values Table
CREATE TABLE product_attribute_values (
    value_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    attribute_id INTEGER NOT NULL REFERENCES product_attributes(attribute_id),
    value TEXT NOT NULL
);

-- Suppliers Table
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    tax_number VARCHAR(100),
    payment_terms INTEGER DEFAULT 0, -- Days
    credit_limit NUMERIC(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers Table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    tax_number VARCHAR(100),
    credit_limit NUMERIC(12,2) DEFAULT 0,
    payment_terms INTEGER DEFAULT 0, -- Days
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Taxes Table
CREATE TABLE taxes (
    tax_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    percentage NUMERIC(5,2) NOT NULL,
    is_compound BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment Methods Table
CREATE TABLE payment_methods (
    method_id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(company_id),
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('CASH', 'CARD', 'ONLINE', 'UPI', 'CHEQUE', 'CREDIT', 'BANK', 'DIGITAL', 'OTHER')),
    external_integration JSONB,
    is_active BOOLEAN DEFAULT TRUE
);

-- Mapping of allowed currencies per payment method with override rates
CREATE TABLE IF NOT EXISTS payment_method_currencies (
    id SERIAL PRIMARY KEY,
    method_id INTEGER NOT NULL REFERENCES payment_methods(method_id) ON DELETE CASCADE,
    currency_id INTEGER NOT NULL REFERENCES currencies(currency_id),
    exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(method_id, currency_id)
);
CREATE INDEX IF NOT EXISTS idx_pmc_method ON payment_method_currencies(method_id);
CREATE INDEX IF NOT EXISTS idx_pmc_currency ON payment_method_currencies(currency_id);

-- Employees Table
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id),
    employee_code VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    position VARCHAR(100),
    department VARCHAR(100),
    salary NUMERIC(12,2),
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Chart of Accounts Table
CREATE TABLE chart_of_accounts (
    account_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    account_code VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    subtype VARCHAR(100),
    parent_id INTEGER REFERENCES chart_of_accounts(account_id),
    is_active BOOLEAN DEFAULT TRUE
);

-- Expense Categories Table
CREATE TABLE expense_categories (
    category_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Workflow Tables
CREATE TABLE workflow_templates (
    workflow_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id)
);

CREATE TABLE workflow_states (
    state_id SERIAL PRIMARY KEY,
    workflow_id INT REFERENCES workflow_templates(workflow_id),
    state_name VARCHAR(100),
    sequence INT,
    is_final BOOLEAN DEFAULT FALSE,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id)
);

CREATE TABLE workflow_approvals (
    approval_id SERIAL PRIMARY KEY,
    state_id INT REFERENCES workflow_states(state_id),
    approver_role_id INT REFERENCES roles(role_id),
    status VARCHAR(50),
    remarks TEXT,
    approved_at TIMESTAMP,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id)
);

ALTER TABLE workflow_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_approvals ENABLE ROW LEVEL SECURITY;

CREATE POLICY workflow_templates_rls ON workflow_templates FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.user_id = workflow_templates.created_by
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.user_id = workflow_templates.created_by
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY workflow_states_rls ON workflow_states FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workflow_templates wt
      JOIN users u ON u.user_id = wt.created_by
      WHERE wt.workflow_id = workflow_states.workflow_id
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workflow_templates wt
      JOIN users u ON u.user_id = wt.created_by
      WHERE wt.workflow_id = workflow_states.workflow_id
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY workflow_approvals_rls ON workflow_approvals FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workflow_states ws
      JOIN workflow_templates wt ON wt.workflow_id = ws.workflow_id
      JOIN users u ON u.user_id = wt.created_by
      WHERE ws.state_id = workflow_approvals.state_id
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workflow_states ws
      JOIN workflow_templates wt ON wt.workflow_id = ws.workflow_id
      JOIN users u ON u.user_id = wt.created_by
      WHERE ws.state_id = workflow_approvals.state_id
        AND u.company_id = current_setting('app.current_company_id')::int
        AND (
          u.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

-- ===============================================
-- TRANSACTIONAL TABLES
-- ===============================================

-- Sales Table
CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    sale_number VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
    sale_time TIME DEFAULT CURRENT_TIME,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(12,2) DEFAULT 0 CHECK (paid_amount <= total_amount),
    payment_method_id INTEGER REFERENCES payment_methods(method_id),
    status VARCHAR(50) DEFAULT 'COMPLETED' CHECK (status IN ('DRAFT', 'COMPLETED', 'VOID', 'RETURNED')),
    pos_status VARCHAR(20) DEFAULT 'COMPLETED' CHECK (pos_status IN ('HOLD', 'ACTIVE', 'COMPLETED')),
    is_quick_sale BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Sale Details Table
CREATE TABLE sale_details (
    sale_detail_id SERIAL PRIMARY KEY,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(product_id),
    product_name VARCHAR(255), -- For quick sales
    quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    discount_percentage NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    tax_id INTEGER REFERENCES taxes(tax_id),
    tax_amount NUMERIC(12,2) DEFAULT 0,
    line_total NUMERIC(12,2) NOT NULL,
    serial_numbers TEXT[], -- Array for serialized products
    notes TEXT
);

-- Sale Payments Table (supports multi-tender and currencies)
CREATE TABLE IF NOT EXISTS sale_payments (
    sale_payment_id SERIAL PRIMARY KEY,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    method_id INTEGER NOT NULL REFERENCES payment_methods(method_id),
    currency_id INTEGER REFERENCES currencies(currency_id),
    amount NUMERIC(12,2) NOT NULL, -- amount in given currency (or base if NULL currency)
    base_amount NUMERIC(12,2) NOT NULL, -- converted amount in base currency
    exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sale_payments_sale ON sale_payments(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_payments_method ON sale_payments(method_id);

-- Sale Returns Table
CREATE TABLE sale_returns (
    return_id SERIAL PRIMARY KEY,
    return_number VARCHAR(100) NOT NULL,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    reason TEXT,
    status VARCHAR(50) DEFAULT 'COMPLETED',
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Sale Return Details Table
CREATE TABLE sale_return_details (
    return_detail_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES sale_returns(return_id) ON DELETE CASCADE,
    sale_detail_id INTEGER REFERENCES sale_details(sale_detail_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL
);
-- Purchase Orders Table
CREATE TABLE purchase_orders (
    purchase_order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(50) DEFAULT 'PENDING',
    total_amount NUMERIC(12,2) DEFAULT 0,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    workflow_state_id INTEGER REFERENCES workflow_states(state_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Purchase Order Items Table
CREATE TABLE purchase_order_items (
    purchase_order_item_id SERIAL PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL REFERENCES purchase_orders(purchase_order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL
);

-- Quotes Table
CREATE TABLE quotes (
    quote_id SERIAL PRIMARY KEY,
    quote_number VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    quote_date DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status VARCHAR(50) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SENT','ACCEPTED')),
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Purchases Table
CREATE TABLE purchases (
    purchase_id SERIAL PRIMARY KEY,
    purchase_number VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    purchase_order_id INTEGER REFERENCES purchase_orders(purchase_order_id),
    workflow_state_id INTEGER REFERENCES workflow_states(state_id),
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(12,2) DEFAULT 0,
    payment_terms INTEGER DEFAULT 0,
    due_date DATE,
    status VARCHAR(50) DEFAULT 'COMPLETED',
    reference_number VARCHAR(100),
    invoice_file VARCHAR(255),
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Purchase Details Table
CREATE TABLE purchase_details (
    purchase_detail_id SERIAL PRIMARY KEY,
    purchase_id INTEGER NOT NULL REFERENCES purchases(purchase_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    discount_percentage NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    tax_id INTEGER REFERENCES taxes(tax_id),
    tax_amount NUMERIC(12,2) DEFAULT 0,
    line_total NUMERIC(12,2) NOT NULL,
    received_quantity NUMERIC(10,3) DEFAULT 0,
    serial_numbers TEXT[],
    expiry_date DATE,
    batch_number VARCHAR(100)
);

-- Purchase Returns Table
CREATE TABLE purchase_returns (
    return_id SERIAL PRIMARY KEY,
    return_number VARCHAR(100) NOT NULL,
    purchase_id INTEGER NOT NULL REFERENCES purchases(purchase_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    reason TEXT,
    reference_number VARCHAR(100),
    receipt_file VARCHAR(255),
    status VARCHAR(50) DEFAULT 'COMPLETED',
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    approved_by INTEGER REFERENCES users(user_id),
    approved_at TIMESTAMP,
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Purchase Return Details Table
CREATE TABLE purchase_return_details (
    return_detail_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES purchase_returns(return_id) ON DELETE CASCADE,
    purchase_detail_id INTEGER REFERENCES purchase_details(purchase_detail_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL
);

-- Goods Receipts Table
CREATE TABLE goods_receipts (
    goods_receipt_id SERIAL PRIMARY KEY,
    receipt_number VARCHAR(100) NOT NULL,
    purchase_order_id INTEGER REFERENCES purchase_orders(purchase_order_id),
    purchase_id INTEGER REFERENCES purchases(purchase_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    received_date DATE NOT NULL DEFAULT CURRENT_DATE,
    received_by INTEGER NOT NULL REFERENCES users(user_id),
    workflow_state_id INTEGER REFERENCES workflow_states(state_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Goods Receipt Items Table
CREATE TABLE goods_receipt_items (
    goods_receipt_item_id SERIAL PRIMARY KEY,
    goods_receipt_id INTEGER NOT NULL REFERENCES goods_receipts(goods_receipt_id) ON DELETE CASCADE,
    purchase_order_item_id INTEGER REFERENCES purchase_order_items(purchase_order_item_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    received_quantity NUMERIC(10,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL
);

-- Stock Table
CREATE TABLE stock (
    stock_id SERIAL PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL DEFAULT 0,
    reserved_quantity NUMERIC(10,3) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(location_id, product_id)
);

-- Stock Lots Table (for FIFO/LIFO tracking)
CREATE TABLE stock_lots (
    lot_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    purchase_id INTEGER REFERENCES purchases(purchase_id),
    goods_receipt_id INTEGER REFERENCES goods_receipts(goods_receipt_id),
    quantity NUMERIC(10,3) NOT NULL,
    remaining_quantity NUMERIC(10,3) NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    received_date DATE NOT NULL,
    expiry_date DATE,
    batch_number VARCHAR(100),
    serial_numbers TEXT[]
);

-- Stock Transfers Table
CREATE TABLE stock_transfers (
    transfer_id SERIAL PRIMARY KEY,
    transfer_number VARCHAR(100) NOT NULL,
    from_location_id INTEGER NOT NULL REFERENCES locations(location_id),
    to_location_id INTEGER NOT NULL REFERENCES locations(location_id),
    transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED')),
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    approved_by INTEGER REFERENCES users(user_id),
    approved_at TIMESTAMP,
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stock Transfer Details Table
CREATE TABLE stock_transfer_details (
    transfer_detail_id SERIAL PRIMARY KEY,
    transfer_id INTEGER NOT NULL REFERENCES stock_transfers(transfer_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC(10,3) NOT NULL,
    received_quantity NUMERIC(10,3) DEFAULT 0
);



-- Collections Table
CREATE TABLE collections (
    collection_id SERIAL PRIMARY KEY,
    collection_number VARCHAR(100) NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    amount NUMERIC(12,2) NOT NULL,
    collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method_id INTEGER REFERENCES payment_methods(method_id),
    reference_number VARCHAR(100),
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Link collections to sales invoices for partial payments
CREATE TABLE collection_invoices (
    id SERIAL PRIMARY KEY,
    collection_id INTEGER NOT NULL REFERENCES collections(collection_id) ON DELETE CASCADE,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id),
    amount NUMERIC(12,2) NOT NULL
);

-- Payments Table
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    payment_number VARCHAR(100) NOT NULL,
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    purchase_id INTEGER REFERENCES purchases(purchase_id),
    location_id INTEGER REFERENCES locations(location_id),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(12,2) NOT NULL,
    payment_method_id INTEGER REFERENCES payment_methods(method_id),
    reference_number VARCHAR(100),
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Expenses Table
CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    expense_number VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    category_id INTEGER NOT NULL REFERENCES expense_categories(category_id),
    amount NUMERIC(12,2) NOT NULL,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    receipt_number VARCHAR(100),
    vendor_name VARCHAR(255),
    payment_method_id INTEGER REFERENCES payment_methods(method_id),
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Cash Register Table
CREATE TABLE cash_register (
    register_id SERIAL PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    date DATE NOT NULL,
    opening_balance NUMERIC(12,2) DEFAULT 0,
    closing_balance NUMERIC(12,2) DEFAULT 0,
    expected_balance NUMERIC(12,2) DEFAULT 0,
    cash_in NUMERIC(12,2) DEFAULT 0,
    cash_out NUMERIC(12,2) DEFAULT 0,
    variance NUMERIC(12,2) DEFAULT 0,
    opened_by INTEGER REFERENCES users(user_id),
    closed_by INTEGER REFERENCES users(user_id),
    status VARCHAR(50) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(location_id, date)
);

-- Vouchers Table
CREATE TABLE vouchers (
    voucher_id SERIAL PRIMARY KEY,
    voucher_number VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('PAYMENT', 'RECEIPT', 'JOURNAL')),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    reference VARCHAR(100),
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    updated_by INTEGER NOT NULL REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Ledger Entries Table
CREATE TABLE ledger_entries (
    entry_id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES chart_of_accounts(account_id),
    voucher_id INTEGER REFERENCES vouchers(voucher_id),
    date DATE NOT NULL,
    debit NUMERIC(12,2) DEFAULT 0,
    credit NUMERIC(12,2) DEFAULT 0,
    balance NUMERIC(12,2) DEFAULT 0,
    transaction_type VARCHAR(50),
    transaction_id INTEGER,
    description TEXT,
    created_by INT NOT NULL REFERENCES users(user_id),
    updated_by INT REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- HR TABLES
-- ===============================================

-- Leave Types Table
CREATE TABLE leave_types (
    leave_type_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    max_days_per_year INTEGER,
    is_paid BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Employee Leaves Table
CREATE TABLE employee_leaves (
    leave_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    leave_type_id INTEGER NOT NULL REFERENCES leave_types(leave_type_id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days_count INTEGER NOT NULL,
    reason TEXT,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approved_by INTEGER REFERENCES users(user_id),
    applied_date DATE DEFAULT CURRENT_DATE,
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Holidays Table
CREATE TABLE holidays (
    holiday_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    description TEXT,
    is_recurring BOOLEAN DEFAULT FALSE,
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE(company_id, date)
);

-- Attendance Table
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    in_time TIME,
    out_time TIME,
    total_hours NUMERIC(4,2),
    status VARCHAR(50) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'HALF_DAY')),
    leave_type_id INTEGER REFERENCES leave_types(leave_type_id),
    notes TEXT,
    created_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, date)
);

-- Salary Components Table
CREATE TABLE salary_components (
    component_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('EARNING', 'DEDUCTION')),
    is_percentage BOOLEAN DEFAULT FALSE,
    default_value NUMERIC(12,2),
    is_active BOOLEAN DEFAULT TRUE
);

-- Employee Salaries Table
CREATE TABLE employee_salaries (
    salary_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    component_id INTEGER NOT NULL REFERENCES salary_components(component_id),
    amount NUMERIC(12,2) NOT NULL,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Payroll Table
CREATE TABLE payroll (
    payroll_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    pay_period_start DATE NOT NULL,
    pay_period_end DATE NOT NULL,
    basic_salary NUMERIC(12,2) DEFAULT 0,
    gross_salary NUMERIC(12,2) DEFAULT 0,
    total_deductions NUMERIC(12,2) DEFAULT 0,
    net_salary NUMERIC(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'FINALIZED', 'PAID')),
    processed_by INTEGER REFERENCES users(user_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- ADDITIONAL TABLES
-- ===============================================

-- Loyalty Programs Table
CREATE TABLE loyalty_programs (
    loyalty_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    points NUMERIC(10,2) DEFAULT 0,
    total_earned NUMERIC(10,2) DEFAULT 0,
    total_redeemed NUMERIC(10,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Loyalty Redemptions Table
CREATE TABLE loyalty_redemptions (
    redemption_id SERIAL PRIMARY KEY,
    sale_id INTEGER REFERENCES sales(sale_id),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    points_used NUMERIC(10,2) NOT NULL,
    value_redeemed NUMERIC(12,2) NOT NULL,
    redeemed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Promotions Table
CREATE TABLE promotions (
    promotion_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    discount_type VARCHAR(50) CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'BUY_X_GET_Y')),
    value NUMERIC(12,2),
    min_amount NUMERIC(12,2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    applicable_to VARCHAR(50) CHECK (applicable_to IN ('ALL', 'PRODUCTS', 'CATEGORIES', 'CUSTOMERS')),
    conditions JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Settings Table
CREATE TABLE settings (
    setting_id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(company_id),
    location_id INTEGER REFERENCES locations(location_id),
    key VARCHAR(255) NOT NULL,
    value TEXT,
    description TEXT,
    data_type VARCHAR(50) DEFAULT 'TEXT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (company_id, key)
);

-- Example: limit active device sessions per user
-- INSERT INTO settings (company_id, key, value, data_type) VALUES (1, 'max_sessions', '{"value":5}', 'INT');

-- Translations Table
CREATE TABLE translations (
    translation_id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    language_code VARCHAR(10) NOT NULL REFERENCES languages(language_code),
    value TEXT NOT NULL,
    context VARCHAR(50), -- UI, RECEIPT, REPORT
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(key, language_code, context)
);

-- Printer Settings Table
CREATE TABLE printer_settings (
    printer_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id),
    name VARCHAR(100) NOT NULL,
    printer_type VARCHAR(50) NOT NULL,
    paper_size VARCHAR(50),
    connectivity JSONB,
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Numbering Sequences Table
CREATE TABLE numbering_sequences (
    sequence_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id),
    name VARCHAR(100) NOT NULL,
    prefix VARCHAR(20),
    sequence_length INTEGER NOT NULL DEFAULT 6,
    current_number INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoice Formats Table
CREATE TABLE invoice_formats (
    format_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(location_id),
    sequence_id INTEGER REFERENCES numbering_sequences(sequence_id),
    name VARCHAR(100) NOT NULL,
    tax_fields JSONB,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoice Templates Table
CREATE TABLE invoice_templates (
    template_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    template_type VARCHAR(50) CHECK (template_type IN ('INVOICE', 'RECEIPT', 'QUOTE')),
    layout JSONB NOT NULL,
    primary_language VARCHAR(10) REFERENCES languages(language_code),
    secondary_language VARCHAR(10) REFERENCES languages(language_code),
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sync Log Table
CREATE TABLE sync_log (
    sync_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    device_id VARCHAR(255),
    user_id INTEGER REFERENCES users(user_id),
    operation VARCHAR(50) CHECK (operation IN ('CREATE', 'UPDATE', 'DELETE')),
    status VARCHAR(50) CHECK (status IN ('SUCCESS', 'FAILED', 'PENDING')),
    error_message TEXT,
    last_synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Log Table
CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    old_value JSONB,
    new_value JSONB,
    field_changes JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- INDEXES FOR PERFORMANCE
-- ===============================================

-- Companies and Locations
CREATE INDEX idx_locations_company_id ON locations(company_id);
CREATE INDEX idx_locations_active ON locations(company_id, is_active);

-- Users and Authentication
CREATE INDEX idx_users_company_location ON users(company_id, location_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_device_sessions_user_id ON device_sessions(user_id);
CREATE INDEX idx_device_sessions_active ON device_sessions(user_id, is_active);

-- Products and Inventory
CREATE INDEX idx_products_company_id ON products(company_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_active ON products(company_id, is_active);
CREATE UNIQUE INDEX ux_product_barcodes_barcode ON product_barcodes(barcode);
CREATE UNIQUE INDEX ux_product_barcodes_product_id_barcode ON product_barcodes(product_id, barcode);
CREATE UNIQUE INDEX ux_product_barcodes_primary ON product_barcodes(product_id) WHERE is_primary;
CREATE INDEX idx_product_attributes_company ON product_attributes(company_id);
CREATE INDEX idx_product_attribute_values_product ON product_attribute_values(product_id);
CREATE INDEX idx_product_attribute_values_product_attribute ON product_attribute_values(product_id, attribute_id);

-- Categories and Brands
CREATE INDEX idx_categories_company ON categories(company_id);
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_brands_company ON brands(company_id);

-- Stock Management
CREATE INDEX idx_stock_location_product ON stock(location_id, product_id);
CREATE INDEX idx_stock_low_stock ON stock(product_id) WHERE quantity <= 0;
CREATE INDEX idx_stock_lots_product_location ON stock_lots(product_id, location_id);
CREATE INDEX idx_stock_lots_expiry ON stock_lots(expiry_date) WHERE expiry_date IS NOT NULL;

-- Sales
CREATE INDEX idx_sales_location ON sales(location_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_status ON sales(status);
CREATE INDEX idx_sales_number ON sales(sale_number);
CREATE INDEX idx_sales_created_by ON sales(created_by);
CREATE INDEX idx_sale_details_sale ON sale_details(sale_id);
CREATE INDEX idx_sale_details_product ON sale_details(product_id);

-- Quotes
CREATE INDEX idx_quotes_customer ON quotes(customer_id);
CREATE INDEX idx_quotes_date ON quotes(quote_date);
CREATE INDEX idx_quotes_status ON quotes(status);

-- Purchases
CREATE INDEX idx_purchases_location ON purchases(location_id);
CREATE INDEX idx_purchases_supplier ON purchases(supplier_id);
CREATE INDEX idx_purchases_date ON purchases(purchase_date);
CREATE INDEX idx_purchases_status ON purchases(status);
CREATE INDEX idx_purchase_details_purchase ON purchase_details(purchase_id);
CREATE INDEX idx_purchase_details_product ON purchase_details(product_id);

-- Returns
CREATE INDEX idx_sale_returns_sale ON sale_returns(sale_id);
CREATE INDEX idx_sale_returns_date ON sale_returns(return_date);
CREATE INDEX idx_purchase_returns_purchase ON purchase_returns(purchase_id);
CREATE INDEX idx_purchase_returns_date ON purchase_returns(return_date);
CREATE INDEX idx_purchase_returns_supplier ON purchase_returns(supplier_id);

-- Customers and Suppliers
CREATE INDEX idx_customers_company ON customers(company_id);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_suppliers_company ON suppliers(company_id);
CREATE INDEX idx_suppliers_phone ON suppliers(phone);
CREATE INDEX idx_suppliers_email ON suppliers(email);

-- Financial
CREATE INDEX idx_payments_supplier ON payments(supplier_id);
CREATE INDEX idx_collections_customer ON collections(customer_id);
CREATE INDEX idx_collections_date ON collections(collection_date);
CREATE INDEX idx_expenses_location ON expenses(location_id);
CREATE INDEX idx_expenses_category ON expenses(category_id);
CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_cash_register_location_date ON cash_register(location_id, date);
CREATE INDEX idx_ledger_entries_account ON ledger_entries(account_id);
CREATE INDEX idx_ledger_entries_date ON ledger_entries(date);

-- HR
CREATE INDEX idx_employees_company ON employees(company_id);
CREATE INDEX idx_employees_location ON employees(location_id);
CREATE INDEX idx_attendance_employee_date ON attendance(employee_id, date);
CREATE INDEX idx_payroll_employee ON payroll(employee_id);
CREATE INDEX idx_payroll_period ON payroll(pay_period_start, pay_period_end);

-- Sync and Audit
CREATE INDEX idx_sync_log_table_record ON sync_log(table_name, record_id);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);

-- Settings and Configuration
CREATE INDEX idx_settings_company_key ON settings(company_id, key);
CREATE INDEX idx_translations_key_lang ON translations(key, language_code);
CREATE INDEX idx_invoice_formats_company_location ON invoice_formats(company_id, location_id);
CREATE INDEX idx_numbering_sequences_company_location ON numbering_sequences(company_id, location_id);

-- ===============================================
-- TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- ===============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to relevant tables
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_quotes_updated_at BEFORE UPDATE ON quotes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_purchases_updated_at BEFORE UPDATE ON purchases FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===============================================
-- INITIAL DATA POPULATION
-- ===============================================

-- Default Languages
INSERT INTO languages (language_code, language_name) VALUES 
('en', 'English'),
('zh', 'Chinese (Mandarin)'),
('es', 'Spanish'),
('fr', 'French'),
('ar', 'Arabic'),
('pt', 'Portuguese'),
('de', 'German'),
('ja', 'Japanese'),
('ru', 'Russian'),
('hi', 'Hindi'),
('ko', 'Korean'),
('it', 'Italian'),
('nl', 'Dutch');

-- Default Currency
INSERT INTO currencies (code, name, symbol, is_base_currency) VALUES 
('USD', 'US Dollar', '$', true);

-- Default Roles
INSERT INTO roles (name, description, is_system_role) VALUES 
('Super Admin', 'Full system access', true),
('Admin', 'Company administration', true),
('Manager', 'Location management', true),
('Sales', 'Sales operations', true),
('Store', 'Store operations', true),
('HR', 'Human resources', true),
('Accountant', 'Accounting operations', true);

-- Default Units
INSERT INTO units (name, symbol) VALUES 
('Pieces', 'pcs'),
('Kilograms', 'kg'),
('Grams', 'g'),
('Liters', 'L'),
('Milliliters', 'mL'),
('Meters', 'm'),
('Centimeters', 'cm'),
('Boxes', 'box'),
('Dozens', 'doz');

-- Default Payment Methods
INSERT INTO payment_methods (name, type) VALUES 
('Cash', 'CASH'),
('Credit Card', 'CARD'),
('Debit Card', 'CARD'),
('Bank Transfer', 'BANK'),
('Check', 'BANK');

-- ===============================================
-- ROW LEVEL SECURITY (Optional)
-- ===============================================

-- Enable RLS on key tables
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;

-- Tenant isolation policies
CREATE POLICY companies_rls ON companies FOR ALL TO authenticated
  USING (company_id = current_setting('app.current_company_id')::int)
  WITH CHECK (company_id = current_setting('app.current_company_id')::int);

CREATE POLICY locations_rls ON locations FOR ALL TO authenticated
  USING (company_id = current_setting('app.current_company_id')::int)
  WITH CHECK (company_id = current_setting('app.current_company_id')::int);

CREATE POLICY users_rls ON users FOR ALL TO authenticated
  USING (
    company_id = current_setting('app.current_company_id')::int AND
    (location_id = current_setting('app.current_location_id')::int OR
     current_setting('app.current_location_id', true) IS NULL)
  )
  WITH CHECK (
    company_id = current_setting('app.current_company_id')::int AND
    (location_id = current_setting('app.current_location_id')::int OR
     current_setting('app.current_location_id', true) IS NULL)
  );

CREATE POLICY products_rls ON products FOR ALL TO authenticated
  USING (company_id = current_setting('app.current_company_id')::int)
  WITH CHECK (company_id = current_setting('app.current_company_id')::int);

CREATE POLICY sales_rls ON sales FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = sales.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = sales.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY quotes_rls ON quotes FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = quotes.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = quotes.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY purchases_rls ON purchases FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchases.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchases.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY sale_returns_rls ON sale_returns FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = sale_returns.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = sale_returns.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY purchase_orders_rls ON purchase_orders FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchase_orders.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchase_orders.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY purchase_returns_rls ON purchase_returns FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchase_returns.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = purchase_returns.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY goods_receipts_rls ON goods_receipts FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = goods_receipts.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = goods_receipts.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY stock_transfers_rls ON stock_transfers FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id IN (stock_transfers.from_location_id, stock_transfers.to_location_id)
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id IN (stock_transfers.from_location_id, stock_transfers.to_location_id)
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

CREATE POLICY collections_rls ON collections FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = collections.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM locations l
      WHERE l.location_id = collections.location_id
        AND l.company_id = current_setting('app.current_company_id')::int
        AND (
          l.location_id = current_setting('app.current_location_id')::int OR
          current_setting('app.current_location_id', true) IS NULL
        )
    )
  );

ALTER TABLE stock_transfers ADD COLUMN workflow_state_id INT REFERENCES workflow_states(state_id);

-- Reporting Views
CREATE TABLE report_views (
    view_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT,
    sql_query TEXT
);

-- Stored Procedures
CREATE OR REPLACE FUNCTION sp_create_sale(customer_id INT, location_id INT, items JSONB, user_id INT)
RETURNS VOID AS $$
BEGIN
  RAISE NOTICE 'Sale created for customer % at location %', customer_id, location_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_process_return(sale_id INT, return_items JSONB, user_id INT)
RETURNS VOID AS $$
BEGIN
  RAISE NOTICE 'Return processed for sale %', sale_id;
END;
$$ LANGUAGE plpgsql;

-- Functions
CREATE OR REPLACE FUNCTION fn_get_current_stock(pid INT, loc_id INT)
RETURNS NUMERIC AS $$
  SELECT quantity FROM stock WHERE product_id = pid AND location_id = loc_id;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fn_calculate_tax(amount NUMERIC, tax_id INT)
RETURNS NUMERIC AS $$
  SELECT amount * (percentage / 100) FROM taxes WHERE tax_id = tax_id;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fn_get_loyalty_points(cid INT)
RETURNS NUMERIC AS $$
  SELECT points FROM loyalty_programs WHERE customer_id = cid;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fn_get_top_selling_products(start_date DATE, end_date DATE)
RETURNS TABLE(product_id INT, total_qty NUMERIC) AS $$
BEGIN
  RETURN QUERY
    SELECT product_id, SUM(quantity)
    FROM sale_details sd
    JOIN sales s ON s.sale_id = sd.sale_id
    WHERE s.sale_date BETWEEN start_date AND end_date
    GROUP BY product_id
    ORDER BY SUM(quantity) DESC;
END;
$$ LANGUAGE plpgsql;

-- Insert basic permissions
INSERT INTO permissions (name, description, module, action) VALUES
-- Authentication
('VIEW_DASHBOARD', 'View dashboard', 'dashboard', 'view'),

-- User Management
('VIEW_USERS', 'View users list', 'users', 'view'),
('CREATE_USERS', 'Create new users', 'users', 'create'),
('UPDATE_USERS', 'Update user details', 'users', 'update'),
('DELETE_USERS', 'Delete users', 'users', 'delete'),

-- Company Management
('VIEW_COMPANIES', 'View companies', 'companies', 'view'),
('CREATE_COMPANIES', 'Create companies', 'companies', 'create'),
('UPDATE_COMPANIES', 'Update companies', 'companies', 'update'),
('DELETE_COMPANIES', 'Delete companies', 'companies', 'delete'),

-- Location Management
('VIEW_LOCATIONS', 'View locations', 'locations', 'view'),
('CREATE_LOCATIONS', 'Create locations', 'locations', 'create'),
('UPDATE_LOCATIONS', 'Update locations', 'locations', 'update'),
('DELETE_LOCATIONS', 'Delete locations', 'locations', 'delete'),

-- Role Management
('VIEW_ROLES', 'View roles', 'roles', 'view'),
('CREATE_ROLES', 'Create roles', 'roles', 'create'),
('UPDATE_ROLES', 'Update roles', 'roles', 'update'),
('DELETE_ROLES', 'Delete roles', 'roles', 'delete'),
('ASSIGN_PERMISSIONS', 'Assign permissions to roles', 'roles', 'assign');

-- Assign ALL permissions to Super Admin (role_id = 1)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions;

-- Assign Admin permissions (role_id = 2) - Company level access
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, permission_id FROM permissions 
WHERE name IN ('VIEW_DASHBOARD', 'VIEW_USERS', 'CREATE_USERS', 'UPDATE_USERS', 'DELETE_USERS', 
               'VIEW_COMPANIES', 'UPDATE_COMPANIES', 'VIEW_LOCATIONS', 'CREATE_LOCATIONS', 
               'UPDATE_LOCATIONS', 'DELETE_LOCATIONS', 'VIEW_ROLES');

-- Assign Manager permissions (role_id = 3) - Location level access
INSERT INTO role_permissions (role_id, permission_id)
SELECT 3, permission_id FROM permissions 
WHERE name IN ('VIEW_DASHBOARD', 'VIEW_USERS', 'CREATE_USERS', 'UPDATE_USERS', 
               'VIEW_LOCATIONS', 'UPDATE_LOCATIONS');

-- ===============================================
-- SCHEMA COMPLETE
-- ===============================================

-- new

-- Allow company_id to be NULL for users without companies yet
ALTER TABLE users ALTER COLUMN company_id DROP NOT NULL;

-- Also allow role_id to be NULL initially  
ALTER TABLE users ALTER COLUMN role_id DROP NOT NULL;

-- Allow location_id to be NULL initially
ALTER TABLE users ALTER COLUMN location_id DROP NOT NULL;

-- Add permissions
-- INSERT INTO permissions (name, description, module, action) VALUES
-- ('VIEW_PRODUCTS', 'View products', 'products', 'view'),
-- ('CREATE_PRODUCTS', 'Create products', 'products', 'create'),
-- ('UPDATE_PRODUCTS', 'Update products', 'products', 'update'),
-- ('DELETE_PRODUCTS', 'Delete products', 'products', 'delete'),
-- ('VIEW_INVENTORY', 'View inventory', 'inventory', 'view'),
-- ('ADJUST_STOCK', 'Adjust stock', 'inventory', 'adjust'),
-- ('CREATE_TRANSFERS', 'Create transfers', 'inventory', 'transfer'),
-- ('APPROVE_TRANSFERS', 'Approve transfers', 'inventory', 'approve');

-- Assign to Admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions 
WHERE name LIKE '%PRODUCTS%' OR name LIKE '%INVENTORY%';

-- Add Product & Inventory Permissions
INSERT INTO permissions (name, description, module, action) VALUES
('VIEW_PRODUCTS', 'View products list', 'products', 'view'),
('CREATE_PRODUCTS', 'Create new products', 'products', 'create'),
('UPDATE_PRODUCTS', 'Update product details', 'products', 'update'),
('DELETE_PRODUCTS', 'Delete products', 'products', 'delete'),
('VIEW_INVENTORY', 'View inventory and stock levels', 'inventory', 'view'),
('ADJUST_STOCK', 'Adjust stock levels', 'inventory', 'adjust'),
('CREATE_TRANSFERS', 'Create stock transfers', 'inventory', 'transfer'),
('APPROVE_TRANSFERS', 'Approve and complete stock transfers', 'inventory', 'approve');

-- Assign ALL permissions to Admin role (role_id = 1)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions 
WHERE name IN ('VIEW_PRODUCTS', 'CREATE_PRODUCTS', 'UPDATE_PRODUCTS', 'DELETE_PRODUCTS',
               'VIEW_INVENTORY', 'ADJUST_STOCK', 'CREATE_TRANSFERS', 'APPROVE_TRANSFERS');

-- Assign basic permissions to Manager role (role_id = 3)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 3, permission_id FROM permissions 
WHERE name IN ('VIEW_PRODUCTS', 'CREATE_PRODUCTS', 'UPDATE_PRODUCTS',
               'VIEW_INVENTORY', 'ADJUST_STOCK', 'CREATE_TRANSFERS');

-- Assign view permissions to Sales role (role_id = 4)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 4, permission_id FROM permissions 
WHERE name IN ('VIEW_PRODUCTS', 'VIEW_INVENTORY');

-- Add Sales & POS Permissions
INSERT INTO permissions (name, description, module, action) VALUES
-- Sales permissions
('VIEW_SALES', 'View sales records and transactions', 'sales', 'view'),
('CREATE_SALES', 'Create new sales and transactions', 'sales', 'create'),
('UPDATE_SALES', 'Update existing sales records', 'sales', 'update'),
('DELETE_SALES', 'Delete or void sales records', 'sales', 'delete'),
('CREATE_RETURNS', 'Process sale returns', 'sales', 'return'),
('VIEW_QUOTES', 'View quotes and proposals', 'quotes', 'view'),
('CREATE_QUOTES', 'Create new quotes', 'quotes', 'create'),
('UPDATE_QUOTES', 'Update existing quotes', 'quotes', 'update'),
('DELETE_QUOTES', 'Delete quotes', 'quotes', 'delete'),

-- POS permissions
('PRINT_INVOICES', 'Print invoices and receipts', 'pos', 'print'),
('VIEW_REPORTS', 'View sales and business reports', 'reports', 'view'),

-- Customer permissions (if not already exists)
('VIEW_CUSTOMERS', 'View customer information', 'customers', 'view'),
('CREATE_CUSTOMERS', 'Create new customers', 'customers', 'create'),
('UPDATE_CUSTOMERS', 'Update customer information', 'customers', 'update'),
('DELETE_CUSTOMERS', 'Delete customers', 'customers', 'delete')

ON CONFLICT (name) DO NOTHING;

-- Assign permissions to existing roles
-- Admin role gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions 
WHERE name IN (
    'VIEW_SALES', 'CREATE_SALES', 'UPDATE_SALES', 'DELETE_SALES', 'CREATE_RETURNS',
    'PRINT_INVOICES', 'VIEW_REPORTS', 'VIEW_CUSTOMERS', 'CREATE_CUSTOMERS', 
    'UPDATE_CUSTOMERS', 'DELETE_CUSTOMERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Manager role gets most permissions except delete
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, permission_id FROM permissions 
WHERE name IN (
    'VIEW_SALES', 'CREATE_SALES', 'UPDATE_SALES', 'CREATE_RETURNS',
    'VIEW_QUOTES', 'CREATE_QUOTES', 'UPDATE_QUOTES',
    'PRINT_INVOICES', 'VIEW_REPORTS', 'VIEW_CUSTOMERS', 'CREATE_CUSTOMERS',
    'UPDATE_CUSTOMERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Sales role gets sales-related permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 4, permission_id FROM permissions 
WHERE name IN (
    'VIEW_SALES', 'CREATE_SALES', 'CREATE_RETURNS', 'PRINT_INVOICES',
    'VIEW_QUOTES', 'CREATE_QUOTES', 'UPDATE_QUOTES',
    'VIEW_CUSTOMERS', 'CREATE_CUSTOMERS', 'UPDATE_CUSTOMERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Store role gets basic sales permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 5, permission_id FROM permissions 
WHERE name IN (
    'VIEW_SALES', 'CREATE_SALES', 'PRINT_INVOICES', 'VIEW_CUSTOMERS',
    'VIEW_QUOTES', 'CREATE_QUOTES'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create customer table if missing fields (add to existing customers table)
-- This adds any missing indexes for performance
CREATE INDEX IF NOT EXISTS idx_customers_company_active ON customers(company_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sales_location_date ON sales(location_id, sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_customer_date ON sales(customer_id, sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_pos_status ON sales(pos_status);
CREATE INDEX IF NOT EXISTS idx_quotes_customer_date ON quotes(customer_id, quote_date);
CREATE INDEX IF NOT EXISTS idx_quotes_status ON quotes(status);
CREATE INDEX IF NOT EXISTS idx_sale_details_product ON sale_details(product_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_company ON payment_methods(company_id);

-- Add any missing stock adjustment table (if not exists)
CREATE TABLE IF NOT EXISTS stock_adjustments (
    adjustment_id SERIAL PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    adjustment NUMERIC(10,3) NOT NULL,
    reason TEXT NOT NULL,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_location_product ON stock_adjustments(location_id, product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_created_at ON stock_adjustments(created_at);

-- Add Loyalty, Promotions & Returns Permissions
INSERT INTO permissions (name, description, module, action) VALUES

-- Loyalty permissions
('VIEW_LOYALTY', 'View loyalty programs and points', 'loyalty', 'view'),
('REDEEM_POINTS', 'Redeem customer loyalty points', 'loyalty', 'redeem'),
('AWARD_POINTS', 'Award loyalty points to customers', 'loyalty', 'award'),
('MANAGE_LOYALTY', 'Manage loyalty program settings', 'loyalty', 'manage'),

-- Promotions permissions  
('VIEW_PROMOTIONS', 'View active and inactive promotions', 'promotions', 'view'),
('CREATE_PROMOTIONS', 'Create new promotions', 'promotions', 'create'),
('UPDATE_PROMOTIONS', 'Update existing promotions', 'promotions', 'update'),
('DELETE_PROMOTIONS', 'Delete or deactivate promotions', 'promotions', 'delete'),
('APPLY_PROMOTIONS', 'Apply promotions to sales', 'promotions', 'apply'),

-- Returns permissions (if not already exists)
('VIEW_RETURNS', 'View sale returns and return history', 'returns', 'view'),
('CREATE_RETURNS', 'Process sale returns', 'returns', 'create'),
('UPDATE_RETURNS', 'Update return information', 'returns', 'update'),
('DELETE_RETURNS', 'Delete or cancel returns', 'returns', 'delete'),
('APPROVE_RETURNS', 'Approve return requests', 'returns', 'approve')

ON CONFLICT (name) DO NOTHING;

-- Assign permissions to existing roles
-- Admin role gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions 
WHERE name IN (
    'VIEW_LOYALTY', 'REDEEM_POINTS', 'AWARD_POINTS', 'MANAGE_LOYALTY',
    'VIEW_PROMOTIONS', 'CREATE_PROMOTIONS', 'UPDATE_PROMOTIONS', 'DELETE_PROMOTIONS', 'APPLY_PROMOTIONS',
    'VIEW_RETURNS', 'CREATE_RETURNS', 'UPDATE_RETURNS', 'DELETE_RETURNS', 'APPROVE_RETURNS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Manager role gets most permissions except delete
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, permission_id FROM permissions 
WHERE name IN (
    'VIEW_LOYALTY', 'REDEEM_POINTS', 'AWARD_POINTS', 'MANAGE_LOYALTY',
    'VIEW_PROMOTIONS', 'CREATE_PROMOTIONS', 'UPDATE_PROMOTIONS', 'APPLY_PROMOTIONS',
    'VIEW_RETURNS', 'CREATE_RETURNS', 'UPDATE_RETURNS', 'APPROVE_RETURNS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Sales role gets sales-related loyalty and return permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 4, permission_id FROM permissions 
WHERE name IN (
    'VIEW_LOYALTY', 'REDEEM_POINTS', 'AWARD_POINTS',
    'VIEW_PROMOTIONS', 'APPLY_PROMOTIONS',
    'VIEW_RETURNS', 'CREATE_RETURNS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Store role gets basic loyalty and return permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 5, permission_id FROM permissions 
WHERE name IN (
    'VIEW_LOYALTY', 'REDEEM_POINTS',
    'VIEW_PROMOTIONS', 'APPLY_PROMOTIONS',
    'VIEW_RETURNS', 'CREATE_RETURNS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create missing indexes for performance
CREATE INDEX IF NOT EXISTS idx_loyalty_programs_customer ON loyalty_programs(customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_customer ON loyalty_redemptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_date ON loyalty_redemptions(redeemed_at);
CREATE INDEX IF NOT EXISTS idx_promotions_company_active ON promotions(company_id, is_active);
CREATE INDEX IF NOT EXISTS idx_promotions_dates ON promotions(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_sale_returns_location_date ON sale_returns(location_id, return_date);
CREATE INDEX IF NOT EXISTS idx_sale_returns_sale ON sale_returns(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_returns_customer ON sale_returns(customer_id);
CREATE INDEX IF NOT EXISTS idx_sale_return_details_return ON sale_return_details(return_id);
CREATE INDEX IF NOT EXISTS idx_sale_return_details_product ON sale_return_details(product_id);

-- Add any missing constraints (if not already exists)
ALTER TABLE loyalty_programs ADD CONSTRAINT chk_loyalty_points_positive
    CHECK (points >= 0);

ALTER TABLE loyalty_programs ADD CONSTRAINT chk_loyalty_totals_positive
    CHECK (total_earned >= 0 AND total_redeemed >= 0);

ALTER TABLE loyalty_redemptions ADD CONSTRAINT chk_redemption_points_positive
    CHECK (points_used > 0 AND value_redeemed > 0);

ALTER TABLE promotions ADD CONSTRAINT chk_promotion_dates
    CHECK (end_date >= start_date);

ALTER TABLE sale_returns ADD CONSTRAINT chk_return_amount_positive
    CHECK (total_amount >= 0);

-- Create unique constraint for customer loyalty programs (if not exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'loyalty_programs_customer_id_key'
    ) THEN
        ALTER TABLE loyalty_programs 
        ADD CONSTRAINT loyalty_programs_customer_id_key UNIQUE (customer_id);
    END IF;
END $$;

-- Add helpful views for reporting (optional)
CREATE OR REPLACE VIEW loyalty_summary AS
SELECT 
    c.company_id,
    COUNT(lp.customer_id) as total_customers,
    SUM(lp.points) as total_active_points,
    SUM(lp.total_earned) as total_points_earned,
    SUM(lp.total_redeemed) as total_points_redeemed,
    AVG(lp.points) as avg_points_per_customer
FROM loyalty_programs lp
JOIN customers c ON lp.customer_id = c.customer_id
WHERE c.is_deleted = FALSE
GROUP BY c.company_id;

CREATE OR REPLACE VIEW active_promotions AS
SELECT *
FROM promotions
WHERE is_active = TRUE
  AND start_date <= CURRENT_DATE
  AND end_date >= CURRENT_DATE;

CREATE OR REPLACE VIEW returns_summary AS
SELECT 
    l.company_id,
    DATE_TRUNC('month', sr.return_date) as month,
    COUNT(*) as total_returns,
    SUM(sr.total_amount) as total_amount,
    COUNT(DISTINCT sr.customer_id) as unique_customers
FROM sale_returns sr
JOIN locations l ON sr.location_id = l.location_id
WHERE sr.is_deleted = FALSE
GROUP BY l.company_id, DATE_TRUNC('month', sr.return_date);

CREATE OR REPLACE VIEW supplier_summary AS
SELECT
    s.supplier_id,
    s.company_id,
    COALESCE(SUM(p.total_amount), 0) AS total_purchases,
    COALESCE(SUM(pay.amount), 0) AS total_payments,
    COALESCE(SUM(pr.total_amount), 0) AS total_returns,
    COALESCE(SUM(p.total_amount), 0) - COALESCE(SUM(pay.amount), 0) - COALESCE(SUM(pr.total_amount), 0) AS credit_balance
FROM suppliers s
LEFT JOIN purchases p ON p.supplier_id = s.supplier_id AND p.is_deleted = FALSE
LEFT JOIN payments pay ON pay.supplier_id = s.supplier_id AND pay.is_deleted = FALSE
LEFT JOIN purchase_returns pr ON pr.supplier_id = s.supplier_id AND pr.is_deleted = FALSE
GROUP BY s.supplier_id, s.company_id;

-- Create missing tables for loyalty and promotions functionality

-- Sale Promotions Junction Table (track which promotions were applied to sales)
CREATE TABLE IF NOT EXISTS sale_promotions (
    sale_promotion_id SERIAL PRIMARY KEY,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id),
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sale_id, promotion_id)
);

-- Loyalty Transactions Table (detailed tracking of point movements)
CREATE TABLE IF NOT EXISTS loyalty_transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('EARNED', 'REDEEMED', 'EXPIRED', 'ADJUSTED')),
    points NUMERIC(10,2) NOT NULL,
    description TEXT,
    reference_type VARCHAR(20), -- 'SALE', 'REDEMPTION', 'MANUAL', 'EXPIRY'
    reference_id INTEGER, -- sale_id, redemption_id, etc.
    balance_after NUMERIC(10,2) NOT NULL,
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Promotion Product Eligibility (which products are eligible for promotions)
CREATE TABLE IF NOT EXISTS promotion_products (
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, product_id)
);

-- Promotion Category Eligibility (which categories are eligible for promotions)
CREATE TABLE IF NOT EXISTS promotion_categories (
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, category_id)
);

-- Promotion Customer Eligibility (which customers are eligible for promotions)
CREATE TABLE IF NOT EXISTS promotion_customers (
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, customer_id)
);

-- Promotion Usage Tracking (track how many times promotions have been used)
CREATE TABLE IF NOT EXISTS promotion_usage (
    usage_id SERIAL PRIMARY KEY,
    promotion_id INTEGER NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    customer_id INTEGER REFERENCES customers(customer_id),
    sale_id INTEGER REFERENCES sales(sale_id),
    discount_amount NUMERIC(12,2) NOT NULL,
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Return Reasons Table (predefined reasons for returns)
CREATE TABLE IF NOT EXISTS return_reasons (
    reason_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    requires_approval BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Credit Notes Table (for return refunds)
CREATE TABLE IF NOT EXISTS credit_notes (
    credit_note_id SERIAL PRIMARY KEY,
    credit_note_number VARCHAR(100) NOT NULL,
    return_id INTEGER NOT NULL REFERENCES sale_returns(return_id),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'ISSUED' CHECK (status IN ('ISSUED', 'APPLIED', 'EXPIRED')),
    issue_date DATE DEFAULT CURRENT_DATE,
    expiry_date DATE,
    notes TEXT,
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    applied_to_sale_id INTEGER REFERENCES sales(sale_id),
    sync_status VARCHAR(20) DEFAULT 'synced',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Customer Segments Table (for targeted promotions)
CREATE TABLE IF NOT EXISTS customer_segments (
    segment_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    criteria JSONB, -- Segment criteria (spending thresholds, purchase frequency, etc.)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer Segment Memberships
CREATE TABLE IF NOT EXISTS customer_segment_members (
    segment_id INTEGER NOT NULL REFERENCES customer_segments(segment_id) ON DELETE CASCADE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (segment_id, customer_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sale_promotions_sale ON sale_promotions(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_promotions_promotion ON sale_promotions(promotion_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_customer ON loyalty_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_type_date ON loyalty_transactions(transaction_type, created_at);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_reference ON loyalty_transactions(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_promotion_usage_promotion ON promotion_usage(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promotion_usage_customer ON promotion_usage(customer_id);
CREATE INDEX IF NOT EXISTS idx_promotion_usage_date ON promotion_usage(used_at);
CREATE INDEX IF NOT EXISTS idx_loyalty_settings_company ON loyalty_settings(company_id);
CREATE INDEX IF NOT EXISTS idx_return_reasons_company ON return_reasons(company_id, is_active);
CREATE INDEX IF NOT EXISTS idx_credit_notes_return ON credit_notes(return_id);
CREATE INDEX IF NOT EXISTS idx_credit_notes_customer ON credit_notes(customer_id);
CREATE INDEX IF NOT EXISTS idx_credit_notes_status_date ON credit_notes(status, issue_date);
CREATE INDEX IF NOT EXISTS idx_customer_segments_company ON customer_segments(company_id, is_active);
CREATE INDEX IF NOT EXISTS idx_customer_segment_members_customer ON customer_segment_members(customer_id);

-- Add triggers for updated_at timestamps
CREATE TRIGGER update_loyalty_settings_updated_at 
    BEFORE UPDATE ON loyalty_settings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customer_segments_updated_at 
    BEFORE UPDATE ON customer_segments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_credit_notes_updated_at 
    BEFORE UPDATE ON credit_notes 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- Insert default return reasons
INSERT INTO return_reasons (company_id, name, description, requires_approval) 
SELECT c.company_id, reason_name, reason_desc, requires_approval
FROM companies c
CROSS JOIN (
    VALUES 
    ('Defective Product', 'Product was damaged or defective', false),
    ('Wrong Item', 'Customer received wrong item', false),
    ('Customer Changed Mind', 'Customer no longer wants the item', false),
    ('Size/Fit Issue', 'Product does not fit correctly', false),
    ('Product Not as Described', 'Product differs from description', true),
    ('Quality Issues', 'Product quality is unsatisfactory', true),
    ('Damaged in Transit', 'Product was damaged during shipping', false),
    ('Other', 'Other reason not listed', true)
) AS reasons(reason_name, reason_desc, requires_approval)
WHERE NOT EXISTS (
    SELECT 1 FROM return_reasons rr 
    WHERE rr.company_id = c.company_id AND rr.name = reason_name
);

-- Create helpful functions
CREATE OR REPLACE FUNCTION calculate_customer_tier(customer_id_param INTEGER)
RETURNS TEXT AS $$
DECLARE
    total_spent NUMERIC;
    tier_name TEXT;
BEGIN
    -- Calculate total spent by customer in last 12 months
    SELECT COALESCE(SUM(s.total_amount), 0) INTO total_spent
    FROM sales s
    WHERE s.customer_id = customer_id_param
      AND s.sale_date >= CURRENT_DATE - INTERVAL '12 months'
      AND s.status = 'COMPLETED'
      AND s.is_deleted = FALSE;

    -- Determine tier based on spending
    IF total_spent >= 10000 THEN
        tier_name := 'PLATINUM';
    ELSIF total_spent >= 5000 THEN
        tier_name := 'GOLD';
    ELSIF total_spent >= 1000 THEN
        tier_name := 'SILVER';
    ELSE
        tier_name := 'BRONZE';
    END IF;

    RETURN tier_name;
END;
$$ LANGUAGE plpgsql;

-- Create function to expire loyalty points
CREATE OR REPLACE FUNCTION expire_loyalty_points()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER := 0;
    rec RECORD;
BEGIN
    -- Find customers with points that should expire
    FOR rec IN
        SELECT lp.customer_id, lp.points, ls.points_expiry_days
        FROM loyalty_programs lp
        JOIN customers c ON lp.customer_id = c.customer_id
        JOIN loyalty_settings ls ON c.company_id = ls.company_id
        WHERE lp.last_updated < CURRENT_DATE - (ls.points_expiry_days || ' days')::INTERVAL
          AND lp.points > 0
    LOOP
        -- Create expiry transaction
        INSERT INTO loyalty_transactions (
            customer_id, transaction_type, points, description, 
            reference_type, balance_after, created_at
        ) VALUES (
            rec.customer_id, 'EXPIRED', -rec.points, 
            'Points expired after ' || rec.points_expiry_days || ' days',
            'EXPIRY', 0, CURRENT_TIMESTAMP
        );

        -- Reset points to 0
        UPDATE loyalty_programs 
        SET points = 0, last_updated = CURRENT_TIMESTAMP
        WHERE customer_id = rec.customer_id;

        expired_count := expired_count + 1;
    END LOOP;

    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Create a view for customer loyalty summary
CREATE OR REPLACE VIEW customer_loyalty_summary AS
SELECT 
    c.customer_id,
    c.company_id,
    c.name as customer_name,
    c.email,
    c.phone,
    COALESCE(lp.points, 0) as current_points,
    COALESCE(lp.total_earned, 0) as total_earned,
    COALESCE(lp.total_redeemed, 0) as total_redeemed,
    lp.last_updated as last_activity,
    calculate_customer_tier(c.customer_id) as tier,
    COALESCE(recent_sales.sales_count, 0) as sales_last_12_months,
    COALESCE(recent_sales.total_spent, 0) as spent_last_12_months
FROM customers c
LEFT JOIN loyalty_programs lp ON c.customer_id = lp.customer_id
LEFT JOIN (
    SELECT 
        customer_id,
        COUNT(*) as sales_count,
        SUM(total_amount) as total_spent
    FROM sales
    WHERE sale_date >= CURRENT_DATE - INTERVAL '12 months'
      AND status = 'COMPLETED'
      AND is_deleted = FALSE
    GROUP BY customer_id
) recent_sales ON c.customer_id = recent_sales.customer_id
WHERE c.is_deleted = FALSE;

-- File: Add to your PostgreSQL.sql file or create a new migration file

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

ALTER TABLE stock_adjustment_documents
ADD CONSTRAINT fk_sad_location
FOREIGN KEY (location_id) REFERENCES locations(location_id) ON DELETE RESTRICT;
ALTER TABLE stock_adjustment_document_items
ADD CONSTRAINT fk_sadi_product
FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT;

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

-- Add Purchase & Supplier Permissions
INSERT INTO permissions (name, description, module, action) VALUES
-- Purchase permissions
('VIEW_PURCHASES', 'View purchase records and transactions', 'purchases', 'view'),
('CREATE_PURCHASES', 'Create new purchase orders', 'purchases', 'create'),
('UPDATE_PURCHASES', 'Update existing purchase records', 'purchases', 'update'),
('DELETE_PURCHASES', 'Delete or cancel purchase orders', 'purchases', 'delete'),
('RECEIVE_PURCHASES', 'Mark purchases as received and update inventory', 'purchases', 'receive'),

-- Purchase Return permissions
('VIEW_PURCHASE_RETURNS', 'View purchase return records', 'purchase_returns', 'view'),
('CREATE_PURCHASE_RETURNS', 'Process purchase returns', 'purchase_returns', 'create'),

-- Supplier permissions
('VIEW_SUPPLIERS', 'View supplier information', 'suppliers', 'view'),
('CREATE_SUPPLIERS', 'Create new suppliers', 'suppliers', 'create'),
('UPDATE_SUPPLIERS', 'Update supplier information', 'suppliers', 'update'),
('DELETE_SUPPLIERS', 'Delete suppliers', 'suppliers', 'delete')

ON CONFLICT (name) DO NOTHING;

-- Assign permissions to existing roles
-- Admin role gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions 
WHERE name IN (
    'VIEW_PURCHASES', 'CREATE_PURCHASES', 'UPDATE_PURCHASES', 'DELETE_PURCHASES', 'RECEIVE_PURCHASES',
    'VIEW_PURCHASE_RETURNS', 'CREATE_PURCHASE_RETURNS',
    'VIEW_SUPPLIERS', 'CREATE_SUPPLIERS', 'UPDATE_SUPPLIERS', 'DELETE_SUPPLIERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Manager role gets most permissions except delete
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, permission_id FROM permissions 
WHERE name IN (
    'VIEW_PURCHASES', 'CREATE_PURCHASES', 'UPDATE_PURCHASES', 'RECEIVE_PURCHASES',
    'VIEW_PURCHASE_RETURNS', 'CREATE_PURCHASE_RETURNS',
    'VIEW_SUPPLIERS', 'CREATE_SUPPLIERS', 'UPDATE_SUPPLIERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Store role gets basic view permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 5, permission_id FROM permissions 
WHERE name IN (
    'VIEW_PURCHASES', 'VIEW_SUPPLIERS'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create a Purchase Manager role (new role for purchase-focused users)
INSERT INTO roles (name, description) VALUES 
('Purchase Manager', 'Manage purchases and suppliers')
ON CONFLICT (name) DO NOTHING;

-- Get the Purchase Manager role ID and assign permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id 
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Purchase Manager'
AND p.name IN (
    'VIEW_PURCHASES', 'CREATE_PURCHASES', 'UPDATE_PURCHASES', 'RECEIVE_PURCHASES',
    'VIEW_PURCHASE_RETURNS', 'CREATE_PURCHASE_RETURNS',
    'VIEW_SUPPLIERS', 'CREATE_SUPPLIERS', 'UPDATE_SUPPLIERS',
    'VIEW_PRODUCTS', 'VIEW_INVENTORY'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =============================================================================
-- Audit Triggers
-- =============================================================================
-- Optional triggers to ensure auditing at the database level
-- These triggers log insert/update/delete operations for critical tables
-- as a fallback when application-level logging is bypassed.

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

-- =============================================================================
-- Master Data Backfill for User References
-- =============================================================================
ALTER TABLE customers ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE customers SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE customers ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE suppliers SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE suppliers ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE products ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE products SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE products ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE categories ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE categories SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE categories ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE brands ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE brands ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE brands SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE brands ALTER COLUMN created_by SET NOT NULL;

-- =============================================================================
-- Workflow Backfill for User References
-- =============================================================================
ALTER TABLE workflow_templates ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_templates ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_templates SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_templates ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE workflow_states ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_states ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_states SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_states ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE workflow_approvals ADD COLUMN IF NOT EXISTS created_by INT REFERENCES users(user_id);
ALTER TABLE workflow_approvals ADD COLUMN IF NOT EXISTS updated_by INT REFERENCES users(user_id);
UPDATE workflow_approvals SET created_by = 1, updated_by = 1 WHERE created_by IS NULL;
ALTER TABLE workflow_approvals ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE currencies
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

-- Seed currencies (idempotent)
INSERT INTO currencies (code, name, symbol, exchange_rate, is_base_currency)
VALUES
('USD', 'US Dollar', '$', 1.00, TRUE),
('EUR', 'Euro', '€', 0.92, FALSE),
('GBP', 'British Pound', '£', 0.78, FALSE),
('INR', 'Indian Rupee', '₹', 83.00, FALSE),
('AED', 'UAE Dirham', 'د.إ', 3.67, FALSE)
ON CONFLICT (code) DO NOTHING;

-- Optional: Default supplier link for products
ALTER TABLE products
ADD COLUMN IF NOT EXISTS default_supplier_id INTEGER REFERENCES suppliers(supplier_id);

ALTER TABLE purchases
ADD COLUMN IF NOT EXISTS invoice_file VARCHAR(255);

-- Add receipt and reference columns to purchase_returns for strict storage
ALTER TABLE purchase_returns ADD COLUMN IF NOT EXISTS receipt_file VARCHAR(255);
ALTER TABLE purchase_returns ADD COLUMN IF NOT EXISTS reference_number VARCHAR(100);
-- tax
ALTER TABLE taxes ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE taxes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
--payment
ALTER TABLE payment_methods DROP CONSTRAINT payment_methods_type_check;
ALTER TABLE payment_methods ADD CONSTRAINT payment_methods_type_check CHECK (type IN ('CASH','CARD','ONLINE','UPI','CHEQUE','CREDIT','BANK','DIGITAL','OTHER'));
-- tax
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_id INTEGER;
ALTER TABLE products ALTER COLUMN tax_id SET NOT NULL;
ALTER TABLE products ADD CONSTRAINT fk_products_tax FOREIGN KEY (tax_id) REFERENCES taxes(tax_id);
-- payment
CREATE TABLE IF NOT EXISTS payment_method_currencies (
    id SERIAL PRIMARY KEY,
    method_id INTEGER NOT NULL REFERENCES payment_methods(method_id) ON DELETE CASCADE,
    currency_id INTEGER NOT NULL REFERENCES currencies(currency_id),
    exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(method_id, currency_id)
);
CREATE INDEX IF NOT EXISTS idx_pmc_method ON payment_method_currencies(method_id);
CREATE INDEX IF NOT EXISTS idx_pmc_currency ON payment_method_currencies(currency_id);
-- sale payments
CREATE TABLE IF NOT EXISTS sale_payments (
    sale_payment_id SERIAL PRIMARY KEY,
    sale_id INTEGER NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    method_id INTEGER NOT NULL REFERENCES payment_methods(method_id),
    currency_id INTEGER REFERENCES currencies(currency_id),
    amount NUMERIC(12,2) NOT NULL, -- amount in given currency (or base if NULL currency)
    base_amount NUMERIC(12,2) NOT NULL, -- converted amount in base currency
    exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sale_payments_sale ON sale_payments(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_payments_method ON sale_payments(method_id);

-- loyalty additions

-- Loyalty Tiers: define tiers like Silver/Gold/Platinum with minimum points
CREATE TABLE IF NOT EXISTS loyalty_tiers (
    tier_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    min_points NUMERIC(10,2) NOT NULL DEFAULT 0,
    points_per_currency NUMERIC(10,2), -- optional per-tier earn ratio (points per 1 currency)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id, name)
);

CREATE INDEX IF NOT EXISTS idx_loyalty_tiers_company ON loyalty_tiers(company_id, is_active);

-- Ensure customers table has foreign key only after tier table exists
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='customers' AND column_name='loyalty_tier_id'
    ) THEN
        ALTER TABLE customers ADD COLUMN loyalty_tier_id INTEGER REFERENCES loyalty_tiers(tier_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='customers' AND column_name='is_loyalty'
    ) THEN
        ALTER TABLE customers ADD COLUMN is_loyalty BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Add per-tier earn ratio column if missing
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='loyalty_tiers' AND column_name='points_per_currency'
    ) THEN
        ALTER TABLE loyalty_tiers ADD COLUMN points_per_currency NUMERIC(10,2);
    END IF;
END $$;

-- drop existing loyalty settings if they exist
DROP TABLE IF EXISTS loyalty_settings;

CREATE TABLE IF NOT EXISTS loyalty_settings (
    setting_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    points_per_currency NUMERIC(5,2) DEFAULT 1.0, -- Points earned per currency unit
    point_value NUMERIC(5,4) DEFAULT 0.01, -- Value of each point in currency
    min_redemption_points INTEGER DEFAULT 100, -- Minimum points required to redeem
    min_points_reserve INTEGER DEFAULT 0, -- Minimum points to keep (not redeemable)
    points_expiry_days INTEGER DEFAULT 365, -- Days after which points expire
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id)
);

-- Backfill default loyalty settings for existing companies
 INSERT INTO loyalty_settings (company_id, points_per_currency, point_value, min_redemption_points, points_expiry_days)
SELECT company_id, 1.0, 0.01, 100, 365
FROM companies
WHERE company_id NOT IN (SELECT company_id FROM loyalty_settings)
ON CONFLICT (company_id) DO NOTHING;