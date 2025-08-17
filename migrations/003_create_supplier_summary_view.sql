-- Create view to aggregate supplier purchases, payments, returns and outstanding balance
CREATE OR REPLACE VIEW supplier_summary AS
SELECT s.supplier_id,
       s.company_id,
       COALESCE(SUM(p.total_amount), 0) AS total_purchases,
       COALESCE(SUM(pay.amount), 0) AS total_payments,
       COALESCE(SUM(pr.total_amount), 0) AS total_returns,
       COALESCE(SUM(p.total_amount), 0) - COALESCE(SUM(pay.amount), 0) - COALESCE(SUM(pr.total_amount), 0) AS outstanding_balance
FROM suppliers s
LEFT JOIN purchases p ON p.supplier_id = s.supplier_id AND p.is_deleted = FALSE
LEFT JOIN payments pay ON pay.supplier_id = s.supplier_id AND pay.is_deleted = FALSE
LEFT JOIN purchase_returns pr ON pr.supplier_id = s.supplier_id AND pr.is_deleted = FALSE
GROUP BY s.supplier_id, s.company_id;

-- Indexes to support supplier_summary view
CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_returns_supplier ON purchase_returns(supplier_id);
CREATE INDEX IF NOT EXISTS idx_payments_supplier ON payments(supplier_id);
