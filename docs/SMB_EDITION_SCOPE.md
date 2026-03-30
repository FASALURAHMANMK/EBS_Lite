# EBS Lite SMB Edition Scope

Date: 2026-03-30
Status: Frozen commercial scope for Phase 1 SMB release

## 1. Scope intent

This document defines what EBS Lite SMB Edition is allowed to claim at launch and what is explicitly excluded from launch marketing, launch UAT, and launch support promises.

Primary launch surface:

- Flutter application in `flutter_app/`
- Go backend in `go_backend_rmt/`

Secondary surface:

- `next_frontend_web/` is an office/admin shell and pilot surface only. It is not the authoritative parity surface for the SMB launch.

## 2. In-scope launch modules

### 2.1 Auth, company bootstrap, and locations

Safe claim:

- secure login, registration, password reset, company creation, session handling, and location-aware operations

Acceptance criteria:

- user can register/login/logout/reset password using configured backend URLs
- authenticated user can create or access company and switch among assigned locations
- device sessions are visible and revocable for security review
- launched flows respect company and location scope

Not safe to claim:

- enterprise identity, SSO, SCIM, or MFA completeness

### 2.2 Roles, permissions, admin, and settings essentials

Safe claim:

- SMB-grade users, roles, permissions, company settings, tax/payment/printer/session controls

Acceptance criteria:

- admins can create/update/delete users and roles
- permission-gated actions are hidden or blocked when the user lacks the required right
- company profile, locations, invoice settings, taxes, payment methods, printer profiles, and session controls are editable through shipped UI
- support bundle generation and sync-health visibility exist for operators

Not safe to claim:

- segregation-of-duties governance, enterprise policy management, or identity lifecycle automation

### 2.3 Dashboard and operations shell

Safe claim:

- location-aware dashboard with KPIs, quick actions, notifications entry, sync state, and navigation to operational modules

Acceptance criteria:

- dashboard loads KPIs for selected location
- quick actions open live operational flows
- unread notification count updates
- online/offline and queue state are visible to the operator

Not safe to claim:

- advanced analytics or executive planning dashboards

### 2.4 POS and sales

Safe claim:

- offline-capable POS and sales operations with barcode search, hold/resume, quotes, invoice history, returns, multi-payment, and receipt/print workflows

Acceptance criteria:

- cashier can search or scan products and complete checkout
- hold/resume, split payments, tax/total calculation, customer attach, and printing work in production build
- offline checkout queues using reserved numbering and syncs back successfully
- quote create, convert, and sale history views work
- sale returns are executable and visible in history/detail views

Not safe to claim:

- fully automated refund payout handling for returns
- unrestricted offline coverage for all sales administration tasks

### 2.5 Purchases and suppliers

Safe claim:

- supplier management, purchase orders, goods receipt, quick purchase plus GRN, purchase returns, and supplier payments

Acceptance criteria:

- operator can create purchase order, receive goods, and record purchase returns
- supplier details and supplier-linked history are visible
- quick purchase plus GRN can queue when offline where documented
- supplier payments post successfully and remain traceable

Not safe to claim:

- enterprise procurement orchestration, vendor portals, or complex approval chains

### 2.6 Inventory control

Safe claim:

- product master, categories, brands, attributes, stock views, adjustments, transfers, barcode-rich products, serial/batch/variant support, and import/export onboarding tools

Acceptance criteria:

- operator can manage products and supporting masters through the shipped UI
- stock on hand, movements, adjustments, and transfers remain location aware
- serial/batch/variant inventory behaves consistently in sale and purchase flows
- Excel import/export for inventory works with controlled templates

Not safe to claim:

- directed warehouse management, bin optimization, replenishment engine, or cycle counting program maturity

### 2.7 Customers, collections, loyalty, and warranty

Safe claim:

- customer master, customer balances, collections, loyalty settings and redemptions in shipped UI, and warranty-linked customer workflows

Acceptance criteria:

- operator can create and manage customers and collect against outstanding balances
- offline collection queue works where documented
- loyalty settings, tiers, and redemption flows available in Flutter behave consistently
- warranty-linked records are viewable and printable where applicable

Not safe to claim:

- CRM automation, omnichannel customer journeys, or full loyalty back-office parity on the web surface

### 2.8 Accounting essentials and cash control

Safe claim:

- cash register, day open/close, expenses, payment/receipt vouchers, ledgers, audit logs, and accounting reports for SMB operations

Acceptance criteria:

- register can be opened, tallied, moved, closed, and force-closed with permissions
- expenses and vouchers post and are visible in ledgers and reports
- trial balance, P&L, balance sheet, daily cash, outstanding, and general ledger reports are accessible
- launched accounting behavior matches `docs/ACCOUNTING_MODULE_USER_MANUAL.md`

Not safe to claim:

- full bank reconciliation
- multi-line journal vouchers
- statutory filing completeness for every jurisdiction

### 2.9 Reports

Safe claim:

- operational and accounting reports with filter, export/share support for core SMB workflows

Acceptance criteria:

- sales, inventory, purchase, customer, expense, tax, and accounting reports open successfully from Flutter
- exports/share paths complete without dead-end navigation
- report numbers reconcile against the corresponding operational documents in demo/UAT data

Not safe to claim:

- scheduled reporting jobs, BI-grade drill-down, or forecasting/planning

### 2.10 HR core

Safe claim:

- employees, departments/designations, attendance, leave management, payroll listing/processing, and payslips for SMB internal operations

Acceptance criteria:

- employee master and organizational setup are manageable
- attendance and leave workflows complete successfully
- payroll can be created, marked paid, and surfaced to authorized users

Not safe to claim:

- enterprise HR suite depth, self-service portal maturity, or compliance-localized payroll coverage

### 2.11 Workflow and notifications

Safe claim:

- approval request listing, approve/reject actions, and notification inbox for current wired events

Acceptance criteria:

- workflow request list, detail, approve, and reject actions work for authorized users
- notification list, unread count, and mark-read behavior work
- launch messaging explicitly describes these as limited approval and alerting capabilities

Not safe to claim:

- full approval orchestration across pricing, procurement, finance, master-data governance, and exception handling

### 2.12 Bulk import/export

Safe claim:

- customer, supplier, and inventory bulk onboarding/export support

Acceptance criteria:

- controlled templates exist and imports succeed on valid files
- exports match visible UI data
- permission checks are enforced

Not safe to claim:

- generalized ETL or background import orchestration

## 3. In-scope but not lead marketing claims

These capabilities may be shown in demos but should not be the primary promise of SMB Edition:

- promotions management
- loyalty differentiation
- warranty workflows
- web office shell
- workflow approvals
- notifications
- support bundle generation

## 4. Out-of-scope enterprise-only items

These are explicitly out of Phase 1 SMB scope even if some backend groundwork exists:

- multi-entity, intercompany, and consolidation finance
- treasury, bank reconciliation, and banking integration depth
- SSO, SAML, OIDC, SCIM, MFA, and enterprise IAM posture
- advanced warehouse management, bins, replenishment, and cycle count programs
- asynchronous platform services and integration hub maturity
- browser-first back-office parity across all operational modules
- self-service portals for partners, customers, or employees
- enterprise observability, compliance, and SoD governance
- budgets, planning, forecasting, and enterprise analytics

## 5. Backend-ready but not commercialized enough for launch claims

The following areas are visible in backend/OpenAPI or parity artifacts but should not be sold as mature launch scope until they are fully surfaced, documented, and UAT-covered:

- `/cash-registers/events`
- `/collections/outstanding`
- `/collections/{id}/receipt`
- `/inventory/barcode`
- `/inventory/summary`
- `/loyalty-programs`
- `/loyalty/award-points`
- `/promotions/check-eligibility`
- `/sales/history/export`
- `/sales/quotes/export`
- `/support/bundle`
- translations/languages management
- several payroll sub-routes and settings detail routes

## 6. Production-risk placeholders, dead routes, and partial features

### Release blockers or claim blockers

- Flutter `Help & support` drawer action is a placeholder-quality snackbar, not a support workflow.
- The Flutter default API base URL falls back to localhost unless `API_BASE_URL` is supplied at build time.
- Missing demo dataset and launch operator pack mean even complete code is not yet commercially packaged.

### Partial features allowed only with narrow wording

- sale returns are documented as credit-note style behavior unless a separate refund/payout process is used
- manual journals are intentionally blocked because only single-counterpart vouchers exist
- the web application should be presented as limited office/admin coverage, not as a parity client
- offline claims should remain limited to the modules explicitly documented in `docs/module_wise_feature_list.md`

## 7. Required release claims

Claims the launch site, demos, proposals, and operator training may safely use:

- offline-capable POS for store operations
- strong inventory control for SMB retail/distribution
- purchasing and receiving with supplier operations
- customer, supplier, and accounting essentials in one product
- role-based access, audit trail, and cash-control support
- API-documented backend aligned with shipped Flutter flows

## 8. Required demo dataset and onboarding assets

Required demo dataset and onboarding assets are governed by `RELEASE_READINESS_PLAN.md` and exercised through `docs/MODULE_UAT_MATRIX.md`.
