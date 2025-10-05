-- =========================================================
-- 0) Extensions & settings
-- =========================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1) Core reference tables
-- =========================================================
CREATE TABLE settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE roles (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL
);

CREATE TABLE role_permissions (
  role_id     bigint REFERENCES roles(id) ON DELETE CASCADE,
  perm_code   text NOT NULL,
  PRIMARY KEY (role_id, perm_code)
);

CREATE TABLE users (
  id          bigserial PRIMARY KEY,
  username    text UNIQUE NOT NULL,
  pw_hash     text NOT NULL,
  role_id     bigint NOT NULL REFERENCES roles(id),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Document numbering
CREATE TABLE number_series (
  id          bigserial PRIMARY KEY,
  code        text UNIQUE NOT NULL,                 -- e.g. 'INV','GRN','RET'
  prefix      text NOT NULL DEFAULT '',
  next_no     integer NOT NULL DEFAULT 1,
  width       integer NOT NULL DEFAULT 6
);

-- Masters
CREATE TABLE categories (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL
);

CREATE TABLE brands (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL
);

CREATE TABLE units (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL,                 -- e.g. PCS, BOX
  factor      numeric(18,6) NOT NULL DEFAULT 1     -- optional conversion factor
);

CREATE TABLE tax_groups (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL,
  is_inclusive boolean NOT NULL DEFAULT false       -- default behavior for items in this group
);

CREATE TABLE tax_rates (
  id              bigserial PRIMARY KEY,
  tax_group_id    bigint NOT NULL REFERENCES tax_groups(id) ON DELETE CASCADE,
  rate_percent    numeric(9,4) NOT NULL CHECK (rate_percent >= 0),
  effective_from  date NOT NULL DEFAULT CURRENT_DATE
);
CREATE INDEX ON tax_rates (tax_group_id, effective_from DESC);

-- Products
CREATE TABLE products (
  id              bigserial PRIMARY KEY,
  code            text UNIQUE NOT NULL,
  name            text NOT NULL,
  category_id     bigint REFERENCES categories(id),
  brand_id        bigint REFERENCES brands(id),
  unit_id         bigint REFERENCES units(id),
  tax_group_id    bigint REFERENCES tax_groups(id),
  price_retail    numeric(18,4) NOT NULL DEFAULT 0,
  price_wholesale numeric(18,4) NOT NULL DEFAULT 0,
  cost_wac        numeric(18,6) NOT NULL DEFAULT 0,
  reorder_qty     numeric(18,3) NOT NULL DEFAULT 0,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON products (code);
CREATE INDEX products_name_trgm ON products USING gin (name gin_trgm_ops);

CREATE TABLE product_barcodes (
  id          bigserial PRIMARY KEY,
  product_id  bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  barcode     text NOT NULL UNIQUE
);
CREATE INDEX ON product_barcodes (product_id);

-- Suppliers / Customers
CREATE TABLE suppliers (
  id          bigserial PRIMARY KEY,
  name        text NOT NULL,
  phone       text,
  is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE customers (
  id           bigserial PRIMARY KEY,
  name         text NOT NULL,
  phone        text,
  price_level  text NOT NULL DEFAULT 'retail',          -- 'retail'|'wholesale'
  credit_limit numeric(18,4) NOT NULL DEFAULT 0,
  opening_balance numeric(18,4) NOT NULL DEFAULT 0,
  is_active    boolean NOT NULL DEFAULT true
);
CREATE INDEX ON customers (name);
CREATE INDEX ON customers (phone);

-- Locations & Stock
CREATE TABLE locations (
  id          bigserial PRIMARY KEY,
  name        text UNIQUE NOT NULL
);

CREATE TABLE stock (
  product_id  bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  location_id bigint NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  qty         numeric(18,3) NOT NULL DEFAULT 0,
  PRIMARY KEY (product_id, location_id)
);

CREATE TABLE stock_ledger (
  id              bigserial PRIMARY KEY,
  ts              timestamptz NOT NULL DEFAULT now(),
  product_id      bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  location_id     bigint NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  ref_type        text NOT NULL,   -- 'GRN','SALE','RET','ADJ+','ADJ-'
  ref_id          bigint,          -- head id
  in_qty          numeric(18,3) NOT NULL DEFAULT 0,
  out_qty         numeric(18,3) NOT NULL DEFAULT 0,
  cost_wac_after  numeric(18,6) NOT NULL DEFAULT 0,
  note            text
);
CREATE INDEX ON stock_ledger (product_id, location_id, ts);

-- Purchases (GRN)
CREATE TABLE purchase_head (
  id          bigserial PRIMARY KEY,
  ts          timestamptz NOT NULL DEFAULT now(),
  doc_no      text UNIQUE NOT NULL,
  doc_date    date NOT NULL DEFAULT CURRENT_DATE,
  supplier_id bigint NOT NULL REFERENCES suppliers(id),
  location_id bigint NOT NULL REFERENCES locations(id),
  subtotal    numeric(18,4) NOT NULL DEFAULT 0,
  tax_amount  numeric(18,4) NOT NULL DEFAULT 0,
  expenses    numeric(18,4) NOT NULL DEFAULT 0,
  grand_total numeric(18,4) NOT NULL DEFAULT 0,
  status      text NOT NULL DEFAULT 'DRAFT',           -- 'DRAFT'|'POSTED'|'VOID'
  notes       text
);

CREATE TABLE purchase_line (
  id              bigserial PRIMARY KEY,
  head_id         bigint NOT NULL REFERENCES purchase_head(id) ON DELETE CASCADE,
  product_id      bigint NOT NULL REFERENCES products(id),
  qty             numeric(18,3) NOT NULL,
  unit_cost       numeric(18,6) NOT NULL,              -- pre-tax unit cost
  tax_group_id    bigint REFERENCES tax_groups(id),
  line_tax_amt    numeric(18,4) NOT NULL DEFAULT 0
);
CREATE INDEX ON purchase_line (head_id);
CREATE INDEX ON purchase_line (product_id);

-- Sales
CREATE TABLE sale_head (
  id              bigserial PRIMARY KEY,
  ts              timestamptz NOT NULL DEFAULT now(),
  doc_no          text UNIQUE NOT NULL,
  doc_date        date NOT NULL DEFAULT CURRENT_DATE,
  customer_id     bigint REFERENCES customers(id),
  cashier_id      bigint REFERENCES users(id),
  location_id     bigint NOT NULL REFERENCES locations(id),
  tax_inclusive   boolean NOT NULL DEFAULT true,
  gross           numeric(18,4) NOT NULL DEFAULT 0,
  discount        numeric(18,4) NOT NULL DEFAULT 0,
  tax             numeric(18,4) NOT NULL DEFAULT 0,
  net             numeric(18,4) NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'DRAFT'        -- 'DRAFT'|'POSTED'|'VOID'
);

CREATE TABLE sale_line (
  id              bigserial PRIMARY KEY,
  head_id         bigint NOT NULL REFERENCES sale_head(id) ON DELETE CASCADE,
  product_id      bigint NOT NULL REFERENCES products(id),
  qty             numeric(18,3) NOT NULL,
  unit_price      numeric(18,6) NOT NULL,
  line_discount   numeric(18,4) NOT NULL DEFAULT 0,
  tax_group_id    bigint REFERENCES tax_groups(id),
  line_tax_amt    numeric(18,4) NOT NULL DEFAULT 0
);
CREATE INDEX ON sale_line (head_id);
CREATE INDEX ON sale_line (product_id);

CREATE TABLE sale_payments (
  id          bigserial PRIMARY KEY,
  head_id     bigint NOT NULL REFERENCES sale_head(id) ON DELETE CASCADE,
  mode        text NOT NULL,                            -- 'CASH','CARD','MIX','OTHER'
  amount      numeric(18,4) NOT NULL,
  ref         text
);

-- Returns (head only, lines  same as sale_lines with negative qty)
CREATE TABLE sale_returns (
  id              bigserial PRIMARY KEY,
  sale_head_id    bigint NOT NULL REFERENCES sale_head(id) ON DELETE CASCADE,
  ts              timestamptz NOT NULL DEFAULT now(),
  reason          text
);

-- Loyalty & AR
CREATE TABLE loyalty_rules (
  id            bigserial PRIMARY KEY,
  type          text NOT NULL DEFAULT 'percent',        -- 'percent'|'slab'
  earn_rate     numeric(18,6) NOT NULL DEFAULT 0,       -- points per 1.00 of net
  redeem_rate   numeric(18,6) NOT NULL DEFAULT 0,       -- 1 point = ? amount
  min_points    numeric(18,2) NOT NULL DEFAULT 0,
  max_redeem_pct numeric(5,2) NOT NULL DEFAULT 100
);

CREATE TABLE loyalty_ledger (
  id            bigserial PRIMARY KEY,
  ts            timestamptz NOT NULL DEFAULT now(),
  customer_id   bigint NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  points        numeric(18,2) NOT NULL,
  ref_type      text NOT NULL,                          -- 'SALE','ADJUST'
  ref_id        bigint,
  note          text
);

CREATE TABLE customer_ledger (
  id            bigserial PRIMARY KEY,
  ts            timestamptz NOT NULL DEFAULT now(),
  customer_id   bigint NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  debit         numeric(18,4) NOT NULL DEFAULT 0,       -- sale increases AR
  credit        numeric(18,4) NOT NULL DEFAULT 0,       -- payment reduces AR
  ref_type      text NOT NULL,                          -- 'SALE','PAYMENT','ADJUST'
  ref_id        bigint,
  note          text
);

-- Audit
CREATE TABLE audit_log (
  id            bigserial PRIMARY KEY,
  ts            timestamptz NOT NULL DEFAULT now(),
  user_id       bigint REFERENCES users(id),
  action        text NOT NULL,          -- 'INSERT','UPDATE','DELETE','POST','VOID'
  entity        text NOT NULL,          -- table name or domain entity
  entity_id     bigint,
  payload_json  jsonb
);

-- ============================
-- 1.A  Product Variants (size/color)
-- ============================
CREATE TABLE IF NOT EXISTS product_variants (
  id           bigserial PRIMARY KEY,
  product_id   bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku          text UNIQUE,                 -- optional merchant SKU for variant
  size_label   text,                        -- e.g. S,M,L,XL / 28,30,32 ...
  color_label  text,                        -- e.g. Red, Blue ...
  extra_json   jsonb NOT NULL DEFAULT '{}'::jsonb  -- extensible attrs
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_variant_identity
  ON product_variants(product_id, COALESCE(size_label,''), COALESCE(color_label,''));

CREATE TABLE IF NOT EXISTS product_variant_barcodes (
  id           bigserial PRIMARY KEY,
  variant_id   bigint NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  barcode      text NOT NULL UNIQUE
);

-- Wire variants to lines (optional use)
ALTER TABLE IF NOT EXISTS purchase_line ADD COLUMN IF NOT EXISTS variant_id bigint REFERENCES product_variants(id);
ALTER TABLE IF NOT EXISTS sale_line     ADD COLUMN IF NOT EXISTS variant_id bigint REFERENCES product_variants(id);

-- ============================
-- 1.B  Batch / Expiry (per location)
-- ============================
CREATE TABLE IF NOT EXISTS product_batches (
  id            bigserial PRIMARY KEY,
  product_id    bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  batch_no      text NOT NULL,
  expiry_date   date,                        -- nullable if no expiry
  UNIQUE(product_id, batch_no)
);

-- Optional variant+batch stock per location (fine-grained); qty can be zero
CREATE TABLE IF NOT EXISTS stock_batches (
  product_id    bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  location_id   bigint NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  batch_id      bigint NOT NULL REFERENCES product_batches(id) ON DELETE CASCADE,
  qty           numeric(18,3) NOT NULL DEFAULT 0,
  PRIMARY KEY (product_id, location_id, batch_id)
);

-- Link lines to a batch directly (optional use)
ALTER TABLE IF NOT EXISTS purchase_line ADD COLUMN IF NOT EXISTS batch_id bigint REFERENCES product_batches(id);
ALTER TABLE IF NOT EXISTS sale_line     ADD COLUMN IF NOT EXISTS batch_id bigint REFERENCES product_batches(id);

-- Also keep the common case: purchase_line has the known expiry even without batch record
ALTER TABLE IF NOT EXISTS purchase_line ADD COLUMN IF NOT EXISTS expiry_date date;

-- ============================
-- 1.C  Serial / IMEI management
-- ============================
-- Central registry of serials; reflects current status.
CREATE TYPE IF NOT EXISTS serial_status AS ENUM('IN_STOCK','RESERVED','SOLD','RETURNED','VOID');

CREATE TABLE IF NOT EXISTS product_serials (
  id               bigserial PRIMARY KEY,
  product_id       bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  location_id      bigint REFERENCES locations(id),             -- where it sits (nullable until posted)
  serial_no        text NOT NULL UNIQUE,                        -- IMEI / S/N
  status           serial_status NOT NULL DEFAULT 'IN_STOCK',
  purchase_line_id bigint REFERENCES purchase_line(id) ON DELETE SET NULL,
  sale_line_id     bigint REFERENCES sale_line(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_serials_product ON product_serials(product_id);
CREATE INDEX IF NOT EXISTS ix_serials_location ON product_serials(location_id);

-- Serial lists captured per line (many serials per line qty)
CREATE TABLE IF NOT EXISTS purchase_line_serials (
  id            bigserial PRIMARY KEY,
  line_id       bigint NOT NULL REFERENCES purchase_line(id) ON DELETE CASCADE,
  serial_no     text NOT NULL,
  UNIQUE(line_id, serial_no)
);

CREATE TABLE IF NOT EXISTS sale_line_serials (
  id            bigserial PRIMARY KEY,
  line_id       bigint NOT NULL REFERENCES sale_line(id) ON DELETE CASCADE,
  serial_no     text NOT NULL,
  UNIQUE(line_id, serial_no)
);


-- =========================================================
-- 2) Utility Functions
-- =========================================================

-- 2.1 Get active tax rate for a tax_group at a date
CREATE OR REPLACE FUNCTION fn_tax_rate(p_tax_group_id bigint, p_on date)
RETURNS numeric AS $$
DECLARE r numeric;
BEGIN
  SELECT tr.rate_percent
  INTO r
  FROM tax_rates tr
  WHERE tr.tax_group_id = p_tax_group_id AND tr.effective_from <= p_on
  ORDER BY tr.effective_from DESC
  LIMIT 1;
  RETURN COALESCE(r, 0);
END;
$$ LANGUAGE plpgsql STABLE;

-- 2.2 Compute tax for a line amount given group & inclusive flag
-- Returns (line_tax, line_net, line_gross)
CREATE OR REPLACE FUNCTION fn_calc_tax(
  p_amount numeric,            -- amount after discount for qty (price*qty - discount)
  p_tax_group_id bigint,
  p_doc_date date,
  p_is_inclusive boolean
) RETURNS TABLE (tax numeric, net numeric, gross numeric)
AS $$
DECLARE rate numeric := fn_tax_rate(p_tax_group_id, p_doc_date);
BEGIN
  IF p_is_inclusive THEN
    -- amount is gross, extract tax
    tax := p_amount - (p_amount / (1 + (rate/100)));
    net := p_amount - tax;
    gross := p_amount;
  ELSE
    tax := p_amount * (rate/100);
    net := p_amount;
    gross := p_amount + tax;
  END IF;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- 2.3 Atomic next document number
CREATE OR REPLACE FUNCTION fn_next_number(p_code text)
RETURNS text AS $$
DECLARE v_id bigint; v_prefix text; v_next int; v_width int; v_doc text;
BEGIN
  SELECT id, prefix, next_no, width
    INTO v_id, v_prefix, v_next, v_width
  FROM number_series WHERE code = p_code
  FOR UPDATE;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'number_series % not found', p_code;
  END IF;
  UPDATE number_series SET next_no = v_next + 1 WHERE id = v_id;
  v_doc := v_prefix || lpad(v_next::text, v_width, '0');
  RETURN v_doc;
END;
$$ LANGUAGE plpgsql;

-- 2.4 Safety: ensure stock row exists (UPSERT helper)
CREATE OR REPLACE FUNCTION fn_ensure_stock(p_product_id bigint, p_location_id bigint)
RETURNS void AS $$
BEGIN
  INSERT INTO stock(product_id, location_id, qty)
  VALUES (p_product_id, p_location_id, 0)
  ON CONFLICT (product_id, location_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_stock_adjust(
  p_product_id  bigint,
  p_location_id bigint,
  p_delta       numeric,               -- +ve add, -ve remove
  p_reason      text,
  p_user_id     bigint DEFAULT NULL,
  p_batch_id    bigint DEFAULT NULL,   -- optional: adjust specific batch
  p_unit_cost   numeric DEFAULT NULL   -- optional: when adding stock, touch WAC
)
RETURNS void AS $$
DECLARE
  v_old_qty   numeric;
  v_new_qty   numeric;
  v_old_wac   numeric;
  v_new_wac   numeric;
BEGIN
  -- Ensure stock row exists
  PERFORM fn_ensure_stock(p_product_id, p_location_id);

  -- Lock stock row
  SELECT qty, p.cost_wac INTO v_old_qty, v_old_wac
  FROM stock s JOIN products p ON p.id = s.product_id
  WHERE s.product_id = p_product_id AND s.location_id = p_location_id
  FOR UPDATE;

  v_new_qty := v_old_qty + p_delta;
  IF v_new_qty < 0 THEN
    RAISE EXCEPTION 'Stock adjust would go negative (prod %, loc %): have %, delta %',
      p_product_id, p_location_id, v_old_qty, p_delta;
  END IF;

  -- Optional WAC touch when adding stock and unit cost supplied
  IF p_delta > 0 AND p_unit_cost IS NOT NULL THEN
    v_new_wac := ((v_old_qty * v_old_wac) + (p_delta * p_unit_cost)) / NULLIF(v_old_qty + p_delta,0);
  ELSE
    v_new_wac := v_old_wac;
  END IF;

  UPDATE stock SET qty = v_new_qty WHERE product_id = p_product_id AND location_id = p_location_id;
  UPDATE products SET cost_wac = v_new_wac, updated_at = now() WHERE id = p_product_id;

  -- Batch-level update (if provided)
  IF p_batch_id IS NOT NULL THEN
    INSERT INTO stock_batches(product_id, location_id, batch_id, qty)
    VALUES (p_product_id, p_location_id, p_batch_id, GREATEST(p_delta,0))  -- insert with +ve; fixed below
    ON CONFLICT (product_id, location_id, batch_id)
    DO UPDATE SET qty = stock_batches.qty + EXCLUDED.qty;
    -- If delta negative, correct:
    IF p_delta < 0 THEN
      UPDATE stock_batches
      SET qty = qty + p_delta
      WHERE product_id = p_product_id AND location_id = p_location_id AND batch_id = p_batch_id;
      -- guard:
      IF (SELECT qty FROM stock_batches WHERE product_id = p_product_id AND location_id = p_location_id AND batch_id = p_batch_id) < 0 THEN
        RAISE EXCEPTION 'Batch stock negative for product %, location %, batch %', p_product_id, p_location_id, p_batch_id;
      END IF;
    END IF;
  END IF;

  -- Ledger
  INSERT INTO stock_ledger(product_id, location_id, ref_type, ref_id, in_qty, out_qty, cost_wac_after, note)
  VALUES (p_product_id, p_location_id,
          CASE WHEN p_delta>=0 THEN 'ADJ+' ELSE 'ADJ-' END,
          NULL, GREATEST(p_delta,0), GREATEST(-p_delta,0),
          v_new_wac, coalesce(p_reason,'Stock adjust'));

  -- Audit
  INSERT INTO audit_log(user_id, action, entity, entity_id, payload_json)
  VALUES (p_user_id, 'POST', 'stock_adjust', NULL,
          jsonb_build_object('product_id',p_product_id,'location_id',p_location_id,'delta',p_delta,'reason',p_reason,'batch_id',p_batch_id,'unit_cost',p_unit_cost));
END;
$$ LANGUAGE plpgsql;

-- Helper: compute current earned/available points for a customer
CREATE OR REPLACE FUNCTION fn_loyalty_points(customer_id bigint)
RETURNS numeric AS $$
DECLARE v numeric;
BEGIN
  SELECT COALESCE(SUM(points),0) INTO v FROM loyalty_ledger WHERE customer_id = fn_loyalty_points.customer_id;
  RETURN v;
END; $$ LANGUAGE plpgsql STABLE;

-- sp_loyalty_redeem: decide how much to redeem for a sale & write ledger
-- Returns (OUT o_redeem_amount money, OUT o_points_used numeric)
CREATE OR REPLACE FUNCTION sp_loyalty_redeem(
  p_head_id bigint,
  p_points  numeric DEFAULT NULL,   -- optional: if NULL, use max allowed by rules
  p_user_id bigint DEFAULT NULL,
  OUT o_redeem_amount numeric,
  OUT o_points_used numeric
) AS $$
DECLARE
  v_head sale_head%ROWTYPE;
  v_rules loyalty_rules%ROWTYPE;
  v_have_points numeric;
  v_rate numeric;            -- redeem_rate (1 point = v_rate amount)
  v_max_pct numeric;         -- max percent of net
  v_want_points numeric;
  v_cap_amount numeric;
BEGIN
  SELECT * INTO v_head FROM sale_head WHERE id = p_head_id;
  IF v_head.status <> 'DRAFT' THEN
    RAISE EXCEPTION 'Sale % is not DRAFT', p_head_id;
  END IF;
  IF v_head.customer_id IS NULL THEN
    RAISE EXCEPTION 'No customer on sale % for redeem', p_head_id;
  END IF;

  SELECT * INTO v_rules FROM loyalty_rules ORDER BY id LIMIT 1;
  v_rate := COALESCE(v_rules.redeem_rate,0);       -- amount per point
  v_max_pct := COALESCE(v_rules.max_redeem_pct,100);

  IF v_rate <= 0 THEN
    RAISE EXCEPTION 'Redeem rate not configured';
  END IF;

  v_have_points := fn_loyalty_points(v_head.customer_id);

  -- maximum money you may redeem on this sale:
  v_cap_amount := (v_head.net * v_max_pct / 100.0);

  -- If p_points not specified, use min(points for cap, points available)
  IF p_points IS NULL THEN
    v_want_points := LEAST( v_have_points, floor( v_cap_amount / v_rate ) );
  ELSE
    v_want_points := LEAST( p_points, v_have_points, floor( v_cap_amount / v_rate ) );
  END IF;

  IF v_want_points <= 0 THEN
    o_redeem_amount := 0; o_points_used := 0; RETURN;
  END IF;

  o_points_used := v_want_points;
  o_redeem_amount := o_points_used * v_rate;

  -- write negative points (redeem)
  INSERT INTO loyalty_ledger(customer_id, points, ref_type, ref_id, note)
  VALUES (v_head.customer_id, -o_points_used, 'SALE', p_head_id, 'Redeem on sale');

  -- audit
  INSERT INTO audit_log(user_id, action, entity, entity_id, payload_json)
  VALUES (p_user_id, 'POST', 'loyalty_redeem', p_head_id,
          jsonb_build_object('points_used',o_points_used,'redeem_amount',o_redeem_amount));

END;
$$ LANGUAGE plpgsql;


-- =========================================================
-- 3) Posting Procedures (as transaction-safe functions)
-- =========================================================

-- 3.1 Post GRN (purchase_head.id) → updates stock, WAC, ledger, totals
CREATE OR REPLACE FUNCTION sp_post_grn(p_head_id bigint, p_user_id bigint DEFAULT NULL)
RETURNS void AS $$
DECLARE
  v_head purchase_head%ROWTYPE;
  v_line record;
  v_amount numeric;
  v_rate numeric;
  v_old_qty numeric; v_old_wac numeric; v_new_qty numeric; v_new_wac numeric;
BEGIN
  SELECT * INTO v_head FROM purchase_head WHERE id = p_head_id FOR UPDATE;
  IF v_head.status <> 'DRAFT' THEN RAISE EXCEPTION 'GRN % is not DRAFT', p_head_id; END IF;

  v_head.subtotal := 0; v_head.tax_amount := 0; v_head.grand_total := 0;

  FOR v_line IN
    SELECT pl.*, COALESCE(pl.tax_group_id, p.tax_group_id) AS eff_tax_group_id
    FROM purchase_line pl
    JOIN products p ON p.id = pl.product_id
    WHERE pl.head_id = p_head_id
  LOOP
    PERFORM fn_ensure_stock(v_line.product_id, v_head.location_id);

    v_amount := v_line.qty * v_line.unit_cost;

    SELECT tr.rate_percent INTO v_rate
    FROM tax_rates tr
    WHERE tr.tax_group_id = v_line.eff_tax_group_id AND tr.effective_from <= v_head.doc_date
    ORDER BY effective_from DESC LIMIT 1;
    v_rate := COALESCE(v_rate,0);

    v_head.subtotal  := v_head.subtotal  + v_amount;
    v_head.tax_amount:= v_head.tax_amount+ (v_amount * (v_rate/100));

    -- WAC compute
    SELECT qty, p.cost_wac INTO v_old_qty, v_old_wac
    FROM stock s JOIN products p ON p.id = v_line.product_id
    WHERE s.product_id = v_line.product_id AND s.location_id = v_head.location_id
    FOR UPDATE;

    v_new_qty := v_old_qty + v_line.qty;
    v_new_wac := CASE WHEN v_new_qty>0
                      THEN ((v_old_qty*v_old_wac)+(v_line.qty*v_line.unit_cost))/v_new_qty
                      ELSE v_line.unit_cost END;

    UPDATE stock SET qty = v_new_qty
    WHERE product_id = v_line.product_id AND location_id = v_head.location_id;

    UPDATE products SET cost_wac = v_new_wac, updated_at = now()
    WHERE id = v_line.product_id;

    -- Batch stock if batch_id present
    IF v_line.batch_id IS NOT NULL THEN
      INSERT INTO stock_batches(product_id, location_id, batch_id, qty)
      VALUES (v_line.product_id, v_head.location_id, v_line.batch_id, v_line.qty)
      ON CONFLICT (product_id, location_id, batch_id)
      DO UPDATE SET qty = stock_batches.qty + EXCLUDED.qty;
    END IF;

    -- Serials: if purchase_line_serials exist, register them as IN_STOCK at location
    INSERT INTO product_serials(product_id, location_id, serial_no, status, purchase_line_id)
    SELECT v_line.product_id, v_head.location_id, pls.serial_no, 'IN_STOCK', v_line.id
    FROM purchase_line_serials pls
    WHERE pls.line_id = v_line.id
    ON CONFLICT (serial_no) DO NOTHING;

    INSERT INTO stock_ledger(product_id, location_id, ref_type, ref_id, in_qty, out_qty, cost_wac_after, note)
    VALUES (v_line.product_id, v_head.location_id, 'GRN', v_head.id, v_line.qty, 0, v_new_wac,
            COALESCE('GRN '||v_head.doc_no,'GRN'));
  END LOOP;

  v_head.grand_total := v_head.subtotal + v_head.tax_amount + v_head.expenses;

  UPDATE purchase_head
  SET subtotal=v_head.subtotal, tax_amount=v_head.tax_amount, grand_total=v_head.grand_total, status='POSTED'
  WHERE id = p_head_id;

  INSERT INTO audit_log(user_id, action, entity, entity_id, payload_json)
  VALUES (p_user_id, 'POST', 'purchase_head', p_head_id, jsonb_build_object('doc_no', v_head.doc_no));
END;
$$ LANGUAGE plpgsql;


-- 3.2 Post Sale (sale_head.id) → totals, stock out, ledger, loyalty, AR
CREATE OR REPLACE FUNCTION sp_post_sale(p_head_id bigint, p_user_id bigint DEFAULT NULL)
RETURNS void AS $$
DECLARE
  v_head sale_head%ROWTYPE;
  v_line record;
  v_amount numeric; v_tax numeric; v_net numeric; v_gross numeric;
  v_is_inc boolean; v_qty numeric; v_old_qty numeric; v_new_qty numeric; v_wac numeric;
  v_cust_id bigint; v_loyalty_points numeric; v_paid numeric;
BEGIN
  SELECT * INTO v_head FROM sale_head WHERE id = p_head_id FOR UPDATE;
  IF v_head.status <> 'DRAFT' THEN RAISE EXCEPTION 'SALE % is not DRAFT', p_head_id; END IF;

  v_is_inc := v_head.tax_inclusive;
  v_head.gross := 0; v_head.discount := 0; v_head.tax := 0; v_head.net := 0;

  FOR v_line IN
    SELECT sl.*, COALESCE(sl.tax_group_id, p.tax_group_id) AS eff_tax_group_id
    FROM sale_line sl
    JOIN products p ON p.id = sl.product_id
    WHERE sl.head_id = p_head_id
  LOOP
    v_qty := v_line.qty;
    v_amount := (v_line.unit_price * v_qty) - v_line.line_discount;

    SELECT tax, net, gross INTO v_tax, v_net, v_gross
    FROM fn_calc_tax(v_amount, v_line.eff_tax_group_id, v_head.doc_date, v_is_inc);

    v_head.tax := v_head.tax + v_tax;
    v_head.net := v_head.net + v_net;
    v_head.gross := v_head.gross + v_gross;
    v_head.discount := v_head.discount + COALESCE(v_line.line_discount,0);

    -- Stock OUT
    PERFORM fn_ensure_stock(v_line.product_id, v_head.location_id);
    SELECT qty, p.cost_wac INTO v_old_qty, v_wac
    FROM stock s JOIN products p ON p.id = v_line.product_id
    WHERE s.product_id = v_line.product_id AND s.location_id = v_head.location_id
    FOR UPDATE;

    IF v_old_qty < v_qty THEN
      RAISE EXCEPTION 'Insufficient stock for product %: have %, need %', v_line.product_id, v_old_qty, v_qty;
    END IF;

    v_new_qty := v_old_qty - v_qty;
    UPDATE stock SET qty = v_new_qty
    WHERE product_id = v_line.product_id AND location_id = v_head.location_id;

    -- Batch decrement if line bound to batch
    IF v_line.batch_id IS NOT NULL THEN
      UPDATE stock_batches
      SET qty = qty - v_qty
      WHERE product_id = v_line.product_id AND location_id = v_head.location_id AND batch_id = v_line.batch_id;
      IF (SELECT qty FROM stock_batches WHERE product_id=v_line.product_id AND location_id=v_head.location_id AND batch_id=v_line.batch_id) < 0 THEN
        RAISE EXCEPTION 'Batch stock negative (prod %, loc %, batch %)', v_line.product_id, v_head.location_id, v_line.batch_id;
      END IF;
    END IF;

    -- Serials: if sale_line_serials exist, ensure they are available and mark SOLD
    IF EXISTS (SELECT 1 FROM sale_line_serials WHERE line_id = v_line.id) THEN
      -- validate availability
      IF EXISTS (
        SELECT 1
        FROM sale_line_serials sls
        LEFT JOIN product_serials ps ON ps.serial_no = sls.serial_no
        WHERE sls.line_id = v_line.id
          AND (ps.serial_no IS NULL OR ps.status <> 'IN_STOCK' OR ps.product_id <> v_line.product_id OR ps.location_id <> v_head.location_id)
      ) THEN
        RAISE EXCEPTION 'One or more serials are not available/at location for sale line %', v_line.id;
      END IF;

      -- mark SOLD + attach sale_line_id
      UPDATE product_serials ps
      SET status = 'SOLD', sale_line_id = v_line.id, updated_at = now()
      FROM sale_line_serials sls
      WHERE ps.serial_no = sls.serial_no AND sls.line_id = v_line.id;
    END IF;

    INSERT INTO stock_ledger(product_id, location_id, ref_type, ref_id, in_qty, out_qty, cost_wac_after, note)
    VALUES (v_line.product_id, v_head.location_id, 'SALE', v_head.id, 0, v_qty, v_wac,
            COALESCE('SALE '||v_head.doc_no,'SALE'));
  END LOOP;

  UPDATE sale_head
  SET gross=v_head.gross, discount=v_head.discount, tax=v_head.tax, net=v_head.net, status='POSTED'
  WHERE id = p_head_id;

  -- Loyalty earn (keep as before)
  SELECT customer_id INTO v_cust_id FROM sale_head WHERE id = p_head_id;
  IF v_cust_id IS NOT NULL THEN
    SELECT earn_rate INTO v_loyalty_points FROM loyalty_rules ORDER BY id LIMIT 1;
    v_loyalty_points := COALESCE(v_loyalty_points,0) * v_head.net;
    IF v_loyalty_points > 0 THEN
      INSERT INTO loyalty_ledger(customer_id, points, ref_type, ref_id, note)
      VALUES (v_cust_id, v_loyalty_points, 'SALE', p_head_id, 'Earn on sale');
    END IF;

    SELECT COALESCE(sum(amount),0) INTO v_paid FROM sale_payments WHERE head_id = p_head_id;
    IF v_head.net - v_paid > 0 THEN
      INSERT INTO customer_ledger(customer_id, debit, credit, ref_type, ref_id, note)
      VALUES (v_cust_id, v_head.net - v_paid, 0, 'SALE', p_head_id, 'Credit sale');
    END IF;
  END IF;

  INSERT INTO audit_log(user_id, action, entity, entity_id, payload_json)
  VALUES (p_user_id, 'POST', 'sale_head', p_head_id, jsonb_build_object('doc_no', v_head.doc_no));
END;
$$ LANGUAGE plpgsql;


-- 3.3 Post Return (increase stock)
CREATE OR REPLACE FUNCTION sp_post_return(p_return_id bigint, p_user_id bigint DEFAULT NULL)
RETURNS void AS $$
DECLARE
  v_ret sale_returns%ROWTYPE;
  v_head sale_head%ROWTYPE;
  v_line record;
  v_qty numeric; v_old_qty numeric; v_new_qty numeric; v_wac numeric;
BEGIN
  SELECT * INTO v_ret FROM sale_returns WHERE id = p_return_id FOR UPDATE;
  SELECT * INTO v_head FROM sale_head WHERE id = v_ret.sale_head_id FOR UPDATE;

  FOR v_line IN
    SELECT sl.* FROM sale_line sl WHERE sl.head_id = v_head.id
  LOOP
    PERFORM fn_ensure_stock(v_line.product_id, v_head.location_id);
    SELECT qty, p.cost_wac INTO v_old_qty, v_wac
    FROM stock s JOIN products p ON p.id = v_line.product_id
    WHERE s.product_id = v_line.product_id AND s.location_id = v_head.location_id
    FOR UPDATE;

    v_qty := v_line.qty;
    v_new_qty := v_old_qty + v_qty;

    UPDATE stock SET qty = v_new_qty
    WHERE product_id = v_line.product_id AND location_id = v_head.location_id;

    INSERT INTO stock_ledger (product_id, location_id, ref_type, ref_id, in_qty, out_qty, cost_wac_after, note)
    VALUES (v_line.product_id, v_head.location_id, 'RET', v_ret.id, v_qty, 0, v_wac, 'Sale return');
  END LOOP;

  INSERT INTO audit_log(user_id, action, entity, entity_id, payload_json)
  VALUES (p_user_id, 'POST', 'sale_returns', p_return_id, jsonb_build_object('sale_doc', v_head.doc_no));
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 4) Generic change audit trigger (INSERT/UPDATE/DELETE)
-- =========================================================
CREATE OR REPLACE FUNCTION trg_audit()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log(action, entity, entity_id, payload_json)
    VALUES ('INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log(action, entity, entity_id, payload_json)
    VALUES ('UPDATE', TG_TABLE_NAME, NEW.id, jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)));
    RETURN NEW;
  ELSE
    INSERT INTO audit_log(action, entity, entity_id, payload_json)
    VALUES ('DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Attach audit to sensitive tables
CREATE TRIGGER audit_products      AFTER INSERT OR UPDATE OR DELETE ON products       FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_customers     AFTER INSERT OR UPDATE OR DELETE ON customers      FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_purchase_head AFTER INSERT OR UPDATE OR DELETE ON purchase_head  FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_sale_head     AFTER INSERT OR UPDATE OR DELETE ON sale_head      FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_stock_adj     AFTER INSERT OR UPDATE OR DELETE ON stock          FOR EACH ROW EXECUTE FUNCTION trg_audit();

-- =========================================================
-- 5) Convenience Views (reports & lookups)
-- =========================================================

-- 5.1 Sales Register (head + totals)
CREATE OR REPLACE VIEW v_sales_register AS
SELECT
  h.id, h.doc_no, h.doc_date, h.ts,
  c.name AS customer_name,
  u.username AS cashier,
  l.name AS location,
  h.gross, h.discount, h.tax, h.net, h.status
FROM sale_head h
LEFT JOIN customers c ON c.id = h.customer_id
LEFT JOIN users u ON u.id = h.cashier_id
JOIN locations l ON l.id = h.location_id;

-- 5.2 Sales Item-wise (lines exploded)
CREATE OR REPLACE VIEW v_sales_itemwise AS
SELECT
  h.doc_no, h.doc_date, h.ts, h.status,
  p.code product_code, p.name product_name,
  sl.qty, sl.unit_price, sl.line_discount, sl.line_tax_amt,
  (sl.qty * sl.unit_price) AS line_amount,
  (sl.qty * sl.unit_price) - sl.line_discount + sl.line_tax_amt AS line_total
FROM sale_line sl
JOIN sale_head h ON h.id = sl.head_id
JOIN products p  ON p.id = sl.product_id;

-- 5.3 Tax Summary (period wise)
CREATE OR REPLACE VIEW v_tax_summary AS
SELECT
  doc_date,
  sum(tax)  AS total_output_tax,
  sum(net)  AS total_net,
  sum(gross) AS total_gross
FROM sale_head
WHERE status = 'POSTED'
GROUP BY doc_date
ORDER BY doc_date;

-- 5.4 Stock On Hand (by product & location)
CREATE OR REPLACE VIEW v_stock_on_hand AS
SELECT s.product_id, p.code, p.name, s.location_id, l.name AS location,
       s.qty, p.cost_wac, (s.qty * p.cost_wac) AS stock_value
FROM stock s
JOIN products p ON p.id = s.product_id
JOIN locations l ON l.id = s.location_id;

-- 5.5 Customer Statement (ledger with running balance per customer per day)
-- (client app can compute running totals; this view returns raw lines)
CREATE OR REPLACE VIEW v_customer_ledger AS
SELECT cl.id, cl.ts::date AS dt, cl.customer_id, c.name customer_name,
       cl.debit, cl.credit, cl.ref_type, cl.ref_id, cl.note
FROM customer_ledger cl
JOIN customers c ON c.id = cl.customer_id
ORDER BY cl.customer_id, cl.ts;

-- 5.6 Purchase Register
CREATE OR REPLACE VIEW v_purchase_register AS
SELECT
  h.id, h.doc_no, h.doc_date, s.name supplier, l.name location,
  h.subtotal, h.tax_amount, h.expenses, h.grand_total, h.status
FROM purchase_head h
JOIN suppliers s ON s.id = h.supplier_id
JOIN locations l ON l.id = h.location_id;


-- Flag to mark which products are serial-tracked (IMEI/SN)
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS serial_tracked boolean NOT NULL DEFAULT false;

-- Batch table (if not already created)
CREATE TABLE IF NOT EXISTS product_batches (
  id            bigserial PRIMARY KEY,
  product_id    bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  batch_no      text NOT NULL,
  expiry_date   date,
  UNIQUE(product_id, batch_no)
);

CREATE OR REPLACE FUNCTION sp_batch_upsert(
  p_product_id  bigint,
  p_batch_no    text,
  p_expiry_date date DEFAULT NULL
) RETURNS bigint AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO product_batches(product_id, batch_no, expiry_date)
  VALUES (p_product_id, p_batch_no, p_expiry_date)
  ON CONFLICT (product_id, batch_no)
  DO UPDATE SET
    expiry_date = COALESCE(EXCLUDED.expiry_date, product_batches.expiry_date)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------
SELECT sp_batch_upsert(:product_id, :batch_no, :expiry_date) AS batch_id;
-- then set purchase_line.batch_id = :batch_id
------------------------------------------------------------

-- Common integer check
CREATE OR REPLACE FUNCTION fn_is_integer_qty(p_qty numeric)
RETURNS boolean AS $$
BEGIN
  RETURN p_qty IS NOT NULL AND p_qty = floor(p_qty);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Check a SALE line's serial count vs qty
CREATE OR REPLACE FUNCTION trg_check_sale_line_serials_fn(p_line_id bigint)
RETURNS void AS $$
DECLARE
  v_qty       numeric;
  v_prod_id   bigint;
  v_tracked   boolean;
  v_count     int;
BEGIN
  SELECT sl.qty, sl.product_id, p.serial_tracked
    INTO v_qty, v_prod_id, v_tracked
  FROM sale_line sl
  JOIN products p ON p.id = sl.product_id
  WHERE sl.id = p_line_id;

  IF NOT FOUND THEN
    -- Line removed; nothing to check
    RETURN;
  END IF;

  IF coalesce(v_tracked, false) IS FALSE THEN
    RETURN; -- Not a serial-tracked product, ignore
  END IF;

  IF NOT fn_is_integer_qty(v_qty) THEN
    RAISE EXCEPTION 'Serial-tracked product % must have integer quantity (got %).', v_prod_id, v_qty;
  END IF;

  SELECT count(*) INTO v_count
  FROM sale_line_serials
  WHERE line_id = p_line_id;

  IF v_count <> v_qty::int THEN
    RAISE EXCEPTION 'Sale line % requires % serial(s) but has %.', p_line_id, v_qty::int, v_count;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Check a PURCHASE line's serial count vs qty
CREATE OR REPLACE FUNCTION trg_check_purchase_line_serials_fn(p_line_id bigint)
RETURNS void AS $$
DECLARE
  v_qty       numeric;
  v_prod_id   bigint;
  v_tracked   boolean;
  v_count     int;
BEGIN
  SELECT pl.qty, pl.product_id, p.serial_tracked
    INTO v_qty, v_prod_id, v_tracked
  FROM purchase_line pl
  JOIN products p ON p.id = pl.product_id
  WHERE pl.id = p_line_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF coalesce(v_tracked, false) IS FALSE THEN
    RETURN;
  END IF;

  IF NOT fn_is_integer_qty(v_qty) THEN
    RAISE EXCEPTION 'Serial-tracked product % must have integer quantity (got %).', v_prod_id, v_qty;
  END IF;

  SELECT count(*) INTO v_count
  FROM purchase_line_serials
  WHERE line_id = p_line_id;

  IF v_count <> v_qty::int THEN
    RAISE EXCEPTION 'Purchase line % requires % serial(s) but has %.', p_line_id, v_qty::int, v_count;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- =========================
-- SALE: enforce serials == qty
-- =========================
DROP TRIGGER IF EXISTS ctrg_sale_line_serials_line ON sale_line;
DROP TRIGGER IF EXISTS ctrg_sale_line_serials_serials ON sale_line_serials;

-- Fire after any change to the sale line itself
CREATE CONSTRAINT TRIGGER ctrg_sale_line_serials_line
AFTER INSERT OR UPDATE OR DELETE ON sale_line
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION trg_check_sale_line_serials_fn( COALESCE(NEW.id, OLD.id) );

-- Fire after any change to the serial list
CREATE CONSTRAINT TRIGGER ctrg_sale_line_serials_serials
AFTER INSERT OR UPDATE OR DELETE ON sale_line_serials
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION trg_check_sale_line_serials_fn( COALESCE(NEW.line_id, OLD.line_id) );

-- =========================
-- PURCHASE: enforce serials == qty
-- =========================
DROP TRIGGER IF EXISTS ctrg_purchase_line_serials_line ON purchase_line;
DROP TRIGGER IF EXISTS ctrg_purchase_line_serials_serials ON purchase_line_serials;

CREATE CONSTRAINT TRIGGER ctrg_purchase_line_serials_line
AFTER INSERT OR UPDATE OR DELETE ON purchase_line
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION trg_check_purchase_line_serials_fn( COALESCE(NEW.id, OLD.id) );

CREATE CONSTRAINT TRIGGER ctrg_purchase_line_serials_serials
AFTER INSERT OR UPDATE OR DELETE ON purchase_line_serials
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION trg_check_purchase_line_serials_fn( COALESCE(NEW.line_id, OLD.line_id) );


-- Prevent the same serial from being entered twice on the same GRN
CREATE UNIQUE INDEX IF NOT EXISTS uq_purchase_line_serials_by_head
ON purchase_line_serials(serial_no, (SELECT head_id FROM purchase_line WHERE id = line_id));

-- Prevent entering a serial that already exists in product_serials (system-wide)
-- (Alternative to checking at post time; use a trigger for portability.)
CREATE OR REPLACE FUNCTION trg_reject_existing_serial_on_capture()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM product_serials ps WHERE ps.serial_no = NEW.serial_no) THEN
    RAISE EXCEPTION 'Serial % already exists in system.', NEW.serial_no;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_dup_serial_capture ON purchase_line_serials;
CREATE TRIGGER trg_block_dup_serial_capture
BEFORE INSERT ON purchase_line_serials
FOR EACH ROW
EXECUTE FUNCTION trg_reject_existing_serial_on_capture();


-- =========================================================
-- 6) Seed minimal data (optional)
-- =========================================================
INSERT INTO roles(name) VALUES ('admin') ON CONFLICT DO NOTHING;
INSERT INTO users(username, pw_hash, role_id)
SELECT 'admin', '$2a$10$replace_with_bcrypt', r.id
FROM roles r WHERE r.name='admin'
ON CONFLICT DO NOTHING;

INSERT INTO locations(name) VALUES ('Main') ON CONFLICT DO NOTHING;

INSERT INTO number_series(code, prefix, next_no, width) VALUES
  ('INV','INV-',1,6),
  ('GRN','GRN-',1,6),
  ('RET','RET-',1,6)
ON CONFLICT (code) DO NOTHING;

INSERT INTO tax_groups(name, is_inclusive) VALUES
  ('VAT5', true), ('Exempt', true)
ON CONFLICT DO NOTHING;

INSERT INTO tax_rates(tax_group_id, rate_percent)
SELECT tg.id, 5 FROM tax_groups tg WHERE tg.name='VAT5'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 7) Helpful secure app role (least privilege) - optional
-- =========================================================
-- CREATE ROLE ebs_app LOGIN PASSWORD 'change_me';
-- GRANT USAGE ON SCHEMA public TO ebs_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ebs_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ebs_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ebs_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO ebs_app;
