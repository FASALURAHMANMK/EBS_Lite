# EBS Lite — Module-wise Feature List

This document summarizes **module-by-module features** available in **EBS Lite**, based on the current implementation of:
- Flutter client: `flutter_app/`
- Go backend API: `go_backend_rmt/`

Last reviewed: **2026-03-30**

Controlled scope note:

- This file is the descriptive feature inventory.
- Launch claims, acceptance criteria, and UAT obligations are governed by:
  - `RELEASE_READINESS_PLAN.md`
  - `docs/SMB_EDITION_SCOPE.md`
  - `docs/MODULE_UAT_MATRIX.md`

## Status legend

- **Available**: Implemented in Flutter UI and supported by backend.
- **Backend-ready**: Implemented in backend; UI may be limited or admin-only.
- **Partial**: Implemented, but with some constraints (often around offline mode).

---

## 1) Core platform (Cross-cutting)

### Authentication & session security
- **Available**: Email/password login, registration, logout.
- **Available**: Password reset flow (forgot/reset password endpoints).
- **Available**: JWT-based authentication with refresh token support.
- **Available**: **Device sessions** listing + session revocation (admin/user security page).

### Company & location (multi-tenant)
- **Available**: Multi-company support (company create/update, logo upload).
- **Available**: Multi-location support with a **location switcher** in the navigation UI.
- **Available**: Location-scoped operations for inventory, sales, purchases, cash register, and reporting.

### Roles, permissions, and access control
- **Available**: Role management (create/update/delete roles).
- **Available**: Permission catalog + assign permissions to roles.
- **Available**: Permission-gated UI actions (module visibility and privileged actions).

### Offline-first foundations (SQLite + queue)
- **Available**: Connectivity detection + server reachability probing.
- **Available**: **Outbox queue (SQLite)** for selected write operations (see per-module notes).
- **Available**: Offline **master-data sync** (periodic + on-demand) for:
  - POS product catalog (by location), POS customers
  - Payment methods + supported currencies + exchange rates (best-effort)
  - Suppliers, expense categories
  - Recent sales history (best-effort)
- **Available**: Offline **sale numbering reservation** (prefetch/reserve blocks for receipt numbers).
- **Available**: Sync monitoring UI (“Sync health”) to view/retry/discard queued items.

### UI/UX foundations
- **Available**: Responsive navigation (mobile bottom tabs + tablet/desktop sidebar).
- **Available**: Light/Dark theme.
- **Partial**: Multi-language UI currently implemented for **English + Arabic** (framework ready for expansion).

---

## 2) Dashboard module

- **Available**: Dashboard KPIs/metrics (backend dashboard endpoints).
- **Available**: Quick actions launcher (Sale, Purchase, Collection, Quick Expense).
- **Available**: Online/offline + sync status indicators (queued count, syncing state).
- **Available**: Notifications entry point + unread badge.
- **Available**: Dashboard customization (quick action configuration).

---

## 3) Sales module (POS + Invoices + Quotes + Returns)

### POS (Point of Sale)
- **Available**: Fast product search (name/barcode) and **camera barcode scanning**.
- **Available**: Cart operations (qty edits, line discount %, bill discount).
- **Available**: Server-side tax/total calculation (`/pos/calculate`).
- **Available**: Multiple payment methods + split payments, change calculation.
- **Available**: **Multi-currency payments** per payment method (exchange-rate based).
- **Available**: Attach customer (optional), credit-aware workflows, and receipt preview.
- **Available**: **Hold sale** and **resume held sales**.
- **Available**: **Void sale** with manager override support (where required by permissions).
- **Available**: Receipt/invoice print data retrieval + client-side printing.

### Invoices & sales history
- **Available**: Invoice list and detail views.
- **Available**: Sales history with filters (date range, customer, payment method, product, sale number).
- **Backend-ready**: Export invoices/history (backend export endpoints exist; not currently exposed in Flutter UI).
- **Partial (offline)**: Sales history can be searched offline from cached recent history (best-effort).

### Quotes
- **Available**: Quote create/update/delete; quote detail view.
- **Available**: Quote actions: print, share, convert to sale.

### Sales returns
- **Available**: Return flows:
  - Find returnable items by sale reference
  - Create return (by sale or by customer)
  - Return list/detail + summary

### Promotions
- **Available**: Promotions CRUD (create/update/delete/list).
- **Available**: Promotion eligibility checks (backend-supported).

---

## 4) Purchases module (PO + GRN + Returns)

### Purchase orders
- **Available**: Create purchase order with items, supplier, and optional reference/notes.
- **Available**: Approve purchase order.

### Goods Receipt Note (GRN)
- **Available**: Record goods receipt against a purchase (receive items/quantities).
- **Available**: “Quick purchase + GRN” flow (create purchase without PO then receive).
- **Available**: Attach/upload purchase invoice files.
- **Partial (offline)**: “Quick purchase + GRN” can be queued to outbox when offline (invoice upload occurs when online).

### Purchase returns
- **Available**: Purchase return create/update/delete, list/detail.
- **Available**: Upload purchase return receipt file.

---

## 5) Inventory module

### Stock & valuation views
- **Available**: Stock-on-hand listing by location.
- **Available**: Inventory summary (backend supported) and product stock details.
- **Available**: Product transaction history (stock movements per product).

### Stock operations
- **Available**: Stock adjustments (increase/decrease with reason).
- **Available**: Stock adjustment documents (create + list + detail).
- **Available**: Stock transfers:
  - Create transfer, view transfer
  - Approve and complete transfer (permission gated)
  - Cancel transfer

### Product master data
- **Available**: Products CRUD (create/edit/delete) including pricing and tax mapping.
- **Available**: Product summary endpoint support (usage depends on UI).
- **Available**: Category management (CRUD).
- **Available**: Brand management (CRUD + active flag support).
- **Available**: Units listing + unit create (admin-only).
- **Available**: Product attribute definitions (CRUD) with typed options (e.g., select/list).

### Barcode utilities
- **Backend-ready**: Barcode generation endpoint (UI coverage depends on where it’s exposed).

### Import/Export (Excel)
- **Available**: Inventory import (Excel `.xlsx`) and export (permission gated).

---

## 6) Customers module (CRM + Collections)

### Customer management
- **Available**: Customer CRUD with contact/tax fields and account controls (credit limit, payment terms, active flag).
- **Available**: Customer summary (balances/metrics) view support.
- **Available**: Customer detail view with linked sales and returns.
- **Available**: Customer import/export (Excel `.xlsx`) (permission gated).
- **Partial (offline)**: Customer search/list available offline after master-data sync.

### Collections (customer payments)
- **Available**: Record collections with optional allocation to invoices.
- **Backend-ready**: Collections outstanding report and receipt retrieval endpoints exist (UI coverage may vary).
- **Available (offline)**: Collection creation is queued to outbox with idempotency keys when offline.

---

## 7) Loyalty module

- **Available**: Loyalty settings management (points per currency, point value, expiry, redemption rules).
- **Available**: Loyalty tiers CRUD (tier thresholds + earning overrides).
- **Backend-ready**: Loyalty program/customer loyalty endpoints and redemptions/award-points endpoints exist (UI coverage depends on role/pages used).

---

## 8) Suppliers module (SRM + Payables operations)

- **Available**: Supplier CRUD + supplier summary.
- **Available**: Supplier-linked purchases and purchase returns views.
- **Available**: Supplier payments recording and payment listing.
- **Available**: Supplier import/export (Excel `.xlsx`) (permission gated).
- **Partial (offline)**: Supplier search/list available offline after master-data sync; supplier write operations require online.

---

## 9) Accounting module (Cash register + Banking + Vouchers + Close + Audit)

### Cash register
- **Available**: Open/close cash register by location.
- **Available**: Cash tally + denomination capture.
- **Available**: Cash movement (IN/OUT) with reason codes.
- **Available**: Force close register (permission gated).
- **Available**: Training mode enable/disable (permission gated).
- **Backend-ready**: Cash register event listing endpoint exists (UI coverage may vary).

### Expenses
- **Available**: Expense entry with categories (location aware).
- **Available (offline)**: Expense creation queued to outbox (idempotency protected).
- **Partial (offline)**: Expense categories readable offline after sync; category management requires online.

### Vouchers & ledgers
- **Available**: Voucher listing and creation for payment, receipt, and balanced journal vouchers.
- **Available**: Voucher settlement to cash or configured bank accounts.
- **Available**: Ledger balances + ledger entries with date range paging.
- **Available**: Chart-of-accounts management with account code, type, subtype, parent, active flag, and balance visibility.
- **Available**: Finance Integrity diagnostics page for backend outbox backlog, missing-ledger detection, replay, and repair.

### Banking & reconciliation
- **Available**: Bank account master linked to ledger accounts.
- **Available**: Structured bank statement entry with unmatched, matched, and review states.
- **Available**: Reconciliation actions for match, unmatch, review, and bank adjustments/charges.
- **Partial**: Statement entry is currently structured/manual; parser-driven import presets and auto-match suggestions are not yet implemented.

### Period close
- **Available**: Accounting period creation, close, reopen, and checklist visibility.
- **Available**: Close blockers for trial-balance imbalance, finance-integrity backlog, and unreconciled bank statements.
- **Partial**: Closed-period enforcement currently covers accounting-admin flows, vouchers, and bank statement activity; full all-module posting locks still need expansion.

### Fixed assets lite
- **Available**: Asset classes, asset register, asset capitalization posting, asset register reporting, and asset value summary.
- **Partial**: Depreciation schedules and depreciation journal automation are not yet implemented.

### Audit logs
- **Available**: Audit log listing with filters (user/action/date range).

---

## 10) HR module (Attendance + Payroll)

### Attendance
- **Available**: Check-in / check-out for employees.
- **Available**: Leave requests, holiday list, attendance records view.

### Payroll
- **Available**: Payroll creation and listing.
- **Available**: Mark payroll paid.
- **Available**: Payslip generation and display.

---

## 11) Reports module (Operational + Accounting reports)

- **Available**: Report categories (Sales, Purchases, Accounts, Inventory).
- **Available**: Built-in report endpoints including:
  - Sales summary, top products, top performers
  - Stock summary, item movement, valuation
  - Customer balances, outstanding
  - Expenses summary, income vs expense, daily cash, cash book, bank book
  - Supplier report
  - Tax report, tax review, reconciliation summary
  - General ledger, trial balance, profit & loss, balance sheet
- **Available**: Export/share reports as **PDF/Excel** from the app UI.

---

## 12) Administration module (Users + Roles)

- **Available**: User management (create/update/delete/list) with permission enforcement.
- **Available**: Role management + permission assignment UI.
- **Available**: Company/location administration entry points (permission gated).

---

## 13) Settings module (Company, tax, invoice, printers, security)

### Company settings
- **Available**: Company profile (name, address, phone, email, tax number).
- **Available**: Base currency selection (currency list backed by API).
- **Available**: Company logo upload and preview.
- **Available**: Location management (create/update/delete/list).

### Tax and payments
- **Available**: Taxes management (CRUD).
- **Available**: Payment methods management + per-method allowed currencies + exchange rates.

### Invoices and numbering
- **Available**: Numbering sequences (CRUD) and POS number reservation.
- **Available**: Invoice templates (CRUD) + invoice settings screens.

### Printers
- **Available**: Device printer settings (thermal/ESC-POS) + cash drawer kick option.
- **Available**: Printer profile management endpoints (create/update/delete/list) where enabled by permissions.

### Security controls
- **Available**: Session-limit controls (set/update/delete).
- **Available**: Device-control settings endpoint support (UI depends on permissions).
- **Available**: User preferences endpoints for per-user configuration.

### Supportability
- **Available**: Support bundle generation in-app (includes outbox health snapshot) for sharing with support.
- **Backend-ready**: `/support/bundle` endpoint exists (not currently used by Flutter UI).

---

## 14) Workflow & approvals module

- **Available**: Workflow request list and detail views.
- **Available**: Approve/reject requests (permission gated).
- **Backend-ready**: Create workflow request endpoint exists (UI coverage depends on flows that submit approvals).

---

## 15) Notifications module

- **Available**: Notifications list + unread count badge.
- **Available**: Mark read (single/all).
- **Available**: Notification types include (at least) low stock and approval pending.
- **Available**: Sync/outbox health entry from notifications screen.

---

## 16) Import/Export module (Bulk I/O)

- **Available**: Excel-based imports (`.xlsx`) for Customers, Suppliers, Inventory.
- **Available**: Exports for Customers, Suppliers, Inventory (permission gated).

---

## 17) Printing & document generation (cross-module)

- **Available**: ESC/POS receipt printing (thermal printers) and optional cash drawer kick.
- **Available**: PDF generation for documents where enabled (e.g., quote PDFs) + share workflows.
- **Available**: Backend “print data” endpoints (sale/quote) so the client can render/print consistently.
