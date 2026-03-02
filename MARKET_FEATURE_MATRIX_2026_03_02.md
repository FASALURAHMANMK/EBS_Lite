# Market Feature Matrix (SMB POS + Lightweight ERP) — 2026-03-02

Purpose:
- Capture “table stakes” features and robust implementation patterns seen in comparable SMB products.
- Use as an extra input to `RELEASE_READINESS_IMPROVEMENTS_2026_03_02.md` and the Codex runbook.

## Reference products (quick notes)

These notes are not “requirements”; they’re reality checks for what operators expect and what tends to break in production.

- Lightspeed Retail POS: emphasizes store operations (register/cash management, X/Z reports) and offline mode.
- Shopify POS: supports offline mode but with explicit limitations; online sync + reporting expectations remain high.
- Square POS: supports offline payments with limits and operator warnings; reconciliation and “what happens when back online” matters.
- Odoo POS: has community/offline approaches; ensure any offline strategy is robust and testable (not “best effort”).
- ERPNext: POS exists; offline typically requires add-ons or custom app approaches — treat offline as a first-class design problem.

## Table-stakes modules (v1 expectations)

### POS

Checklist:
- Fast item lookup (barcode/PLU/name), category browse
- Cart editing: qty, price override (permissioned), line/bill discounts, tax inclusive/exclusive
- Split payments (multiple tenders), change calc, refunds/returns, voids with reasons
- Hold/resume, reprint/share receipt, “quick sale” / non-inventory items
- Customer attach + credit sale rules + credit limit checks (permissioned overrides)
- Promotions + loyalty earn/redeem
- Offline: sell while offline, sync later without duplicates (idempotency + reconciliation)

Robust patterns:
- “POS session / shift” concept: open/close per device + cashier, with cash movements tracked.
- Role limits for discounts/returns/voids; manager override required beyond limits.
- Training mode: non-posting transactions that don’t touch inventory/cash totals.

### Cash management

Checklist:
- Opening float, end-of-day cash count, variance
- Cash drops/payouts with reason codes and approvals
- X/Z-style reports (preview vs final close)
- Forced close by admin (device lost / app crashed)

### Inventory

Checklist:
- Purchase orders + receiving (GRN), supplier returns
- Stock counts/adjustments with reasons and audit
- Transfers (request → approve → complete) across locations
- Reorder points + low stock alerts
- Variants/attributes; optional serial/batch/expiry
- Valuation reporting (Avg/WAC at minimum, FIFO optional)

### Customers / Loyalty / Promotions

Checklist:
- Customer master + statement/ledger view
- Points ledger (earn/redeem) and redemption rules
- Promotions engine with clear eligibility and auditability

### Admin / Security

Checklist:
- Users/roles/permissions UI; device session limits; revoke device sessions
- Audit log viewer with filters and “who/when/where”
- Backups/export: CSV/XLSX exports + a documented restore path

### Reports

Checklist:
- Sales summary + tax + cashier/day
- Stock on hand + valuation + movement + low stock
- Purchases register + supplier performance
- Customer balances/outstanding
- Exports (PDF/XLSX) and predictable filters

## Common gaps to explicitly prevent

- Offline duplicates and stock drift after reconnect (missing idempotency + reconciliation)
- “Stuck open” cash sessions and missing forced-close workflows
- Weak permissions around discounts/returns/voids (shrinkage risk)
- No usable audit trail (can’t investigate disputes)
- Poor onboarding: no import templates, no backup story, no data export

## Implementation decisions to standardize in EBS Lite

- Define “critical write endpoints” (POS checkout, purchase create, collection create, returns, stock adjustments):
  - Must accept idempotency keys
  - Must return stable IDs in success responses
  - Must log `request_id` + `idempotency_key` + created entity IDs
- Define “high-risk actions” and guard them:
  - Discounts, voids, returns, cash drops/payouts, day close
  - Require reasons + audit log
  - Require manager override when beyond cashier limits

## Actionable “must vs defer” (EBS Lite v1)

Use this to turn the market baseline into shipping scope decisions.

### Must-have v1 (ship)

- POS selling: returns-by-reference, split payments, hold/resume, receipt print/share/reprint, offline queue + safe recovery.
- Cash sessions: opening float, cash drops/payouts, end-of-day cash count + variance, X/Z close outputs, forced-close by admin.
- Guardrails: RBAC, discount/void/return limits, manager override, reason capture, audit log viewer.
- Inventory basics: GRN/receiving, stock adjustments + reasons, stock counts, transfers (even if simple), low-stock alerts.
- Exports: CSV/XLSX exports for core lists + “support bundle” export (logs + failed sync + env metadata).
- Offline safety: idempotency keys on critical write endpoints + operator-visible sync status.

### Defer (unless contractually required)

- “Offline card processing” / integrated payments in offline mode (build cash-only offline first, with explicit UX guardrails).
- Deep customization layers (custom report builders, complex promotion rule designers) until core correctness is proven.
- Advanced inventory valuation (FIFO/LIFO) beyond Avg/WAC for v1.
