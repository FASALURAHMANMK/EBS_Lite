# EBS Lite Demo Dataset And Onboarding Pack

Date: 2026-03-30

## 1. Demo dataset manifest

Use this governed dataset for UAT, demos, and operator training.

Company and locations:
- `EBS Demo Retail LLC`
- `HQ`
- `Main Store`
- `Secondary Store`

Users and roles:
- `admin.demo`
- `manager.demo`
- `cashier.demo`
- `purchaser.demo`
- `accountant.demo`
- `inventory.demo`
- `hr.demo`
- `viewer.demo`

Core master data:
- 2 tax profiles
- 5 payment methods
- 15 customers
- 10 suppliers
- 60 products across standard, serialized, batch-tracked, and barcode-rich groups

Transactional baseline:
- 20 purchase or GRN documents
- 2 purchase returns
- 50 sales including cash, split payment, quote conversion, hold/resume, and returns
- 10 collections
- 8 expenses
- 2 closed cash sessions and 1 open session
- 5 workflow requests and 5 notifications

## 2. Demo dataset reset guide

Reproducible reset expectation:
1. Start from a clean PostgreSQL database.
2. Run backend migrations.
3. Create the demo company through the supported bootstrap flow.
4. Load the governed master data set and role assignments used by the release team.
5. Execute the seeded transactional script or manual checklist in the same order for every UAT cycle.

Current repo note:
- the repo now contains the governed manifest and reset procedure, but not a one-command full seed loader yet
- repeatability therefore depends on the release team running the same controlled setup steps

## 3. Customer onboarding checklist

Pre-go-live:
- confirm company profile, tax number, currency, and locations
- set `API_BASE_URL` and backend production config
- load master data or import from templates
- configure payment methods, taxes, numbering, and printers
- configure password and session policy
- test one sale, one purchase, one collection, one report, and one support bundle

Role-based onboarding:
- cashier: POS, hold/resume, day close, receipt reprint
- manager: overrides, approvals, dashboard, reports
- purchaser: PO, GRN, returns, supplier flows
- accountant: vouchers, ledgers, reports, day close review
- inventory operator: product setup, adjustments, transfers, serial and batch handling
- admin: users, roles, security policy, sessions, support bundle

## 4. Environment templates

Repo-backed templates added for launch packaging:
- backend: `go_backend_rmt/.env.production.template`
- Flutter build defines: `flutter_app/dart_defines.production.example.json`

## 5. Support bundle checklist

Before escalating an issue:
1. Capture document number, company, location, and affected user.
2. Export the Flutter support bundle.
3. If backend access is available, capture the backend support bundle too.
4. Attach screenshots and exact timestamps.

## 6. Edition-ready feature packaging

SMB Core:
- auth and sessions
- dashboard
- POS and sales
- purchases and suppliers
- inventory
- customers and collections
- accounting essentials
- reports

SMB Plus differentiators:
- loyalty
- promotions
- warranty
- workflow and notifications
- import/export onboarding tools
