# EBS Lite SMB Release Readiness Plan

Date: 2026-03-30
Scope baseline: Flutter client (`flutter_app/`), Go backend (`go_backend_rmt/`), limited office web shell (`next_frontend_web/`)
Status: Controlled release-program baseline for SMB Edition

## 1. Purpose

This document freezes the Phase 1 SMB release program baseline and turns the repo into the authoritative source for:

- release scope
- release gates
- module acceptance criteria
- UAT coverage
- governance/documentation ownership
- blocker and non-blocker prioritization

Authoritative companion documents created or governed by this plan:

- `docs/SMB_EDITION_SCOPE.md`
- `docs/RELEASE_GATES_CHECKLIST.md`
- `docs/MODULE_UAT_MATRIX.md`
- `docs/REPO_GOVERNANCE_ARTIFACTS.md`
- `docs/release_market_readiness_report.md`
- `docs/module_wise_feature_list.md`
- `docs/ACCOUNTING_MODULE_USER_MANUAL.md`
- `tools/api_parity_report.md`

## 2. Repo-backed baseline assumptions

The following assumptions were confirmed by repo inspection on 2026-03-30:

- Flutter is the primary operational SMB release surface.
- The Go backend supports a wider capability set than the currently commercialized Flutter and web UI surface.
- The Next.js web application exists and is useful as an office/admin shell, but `go_backend_rmt/internal/routes/FRONTEND_PARITY.md` still marks many backend route groups as reserved or intentionally unused there.
- `tools/api_parity_report.md` currently shows no Flutter-called endpoints missing from OpenAPI and no method mismatches.
- The read-first documents required by `AGENTS.md` now exist at the expected paths.
- The shipped Flutter help and support entry now resolves to live operational help content rather than a placeholder action.
- The Flutter app uses `String.fromEnvironment('API_BASE_URL')` correctly and now fails fast in release builds if that value still points at localhost.

## 3. Commercial release position

EBS Lite Phase 1 is an SMB retail and distribution release, not an enterprise release.

Safe Phase 1 claim:

> EBS Lite is an offline-capable SMB retail and distribution ERP centered on POS, inventory, purchases, customers, suppliers, accounting essentials, reporting, and store operations controls.

Unsafe Phase 1 claims:

- enterprise-ready
- multi-entity or intercompany finance
- bank reconciliation complete
- browser-first back-office parity with the Flutter app
- statutory or jurisdiction-complete accounting compliance
- fully automated approvals across all control-sensitive workflows

## 4. Release pillars by engineering dimension

### 4.1 Business logic

Release focus:

- transactional correctness for sales, POS checkout, purchases, collections, expenses, and returns
- consistent operational-to-ledger behavior
- stable module claims aligned with actual reachable UI

Open risks:

- financial integrity must remain the top release blocker until end-to-end transactional and reconciliation confidence is proven in UAT
- workflow and notification depth is still shallower than the code surface implies

### 4.2 Data model and migrations

Required release outcome:

- all required schema for shipped SMB modules is migration-backed under `go_backend_rmt/migrations`
- no manual production-only schema steps
- seeded accounting defaults remain aligned with accounting documentation

Current baseline:

- Go service and migration structure is present
- no new migration work is required for this documentation slice
- demo dataset and onboarding assets are now governed by `docs/DEMO_DATASET_AND_ONBOARDING.md`

### 4.3 API and OpenAPI

Required release outcome:

- `go_backend_rmt/openapi.yaml` remains accurate for all Flutter-called endpoints
- parity check remains green from repo root
- unused backend endpoints are treated as non-commercialized unless they have shipped UI coverage and UAT

Current baseline:

- parity is currently green
- backend routes exceed Flutter and web commercialization scope

### 4.4 Flutter repository, controller, and UI

Required release outcome:

- no reachable placeholder screens or dead-end production actions
- module claims limited to what is reachable and stable
- Flutter remains the primary shipped UI for SMB Edition

Current baseline:

- feature boundaries are largely preserved
- offline foundations are present
- the support/help flow is now a live workflow and no longer a placeholder-quality action

### 4.5 Permissions and security

Required release outcome:

- permission-gated control-sensitive actions remain enforced
- packaged production environments do not rely on default secrets or default URLs
- password reset uses a real configured frontend URL
- upload size/type validation remains enabled

Current baseline:

- auth, sessions, request IDs, rate limiting, upload validation, and audit logs are present
- production secret/config guidance now exists in repo docs and templates, but release sign-off still requires environment-specific verification

### 4.6 Offline, outbox, and idempotency

Required release outcome:

- shipped offline claims are restricted to flows already backed by outbox/idempotency
- outbox monitoring and retry are part of operator UAT
- receipt numbering reservation is validated in a reproducible demo/UAT dataset

Current baseline:

- offline outbox and idempotency are present in meaningful flows, especially POS, purchases/GRN, collections, and expenses
- not every module is offline-capable and claims must stay precise

### 4.7 Operator and admin documentation

Required release outcome:

- support, operations, training, and UAT docs exist for every launched module
- the repo clearly distinguishes:
  - launch scope
  - backend-ready but not commercialized capabilities
  - enterprise-only roadmap items

Current baseline:

- accounting documentation is materially ahead of the rest of the operator doc set
- launch runbooks, demo dataset pack, operator SOPs, and release templates now exist in repo and must be kept current with the release candidate

## 5. Frozen SMB scope summary

Phase 1 launch scope is defined in `docs/SMB_EDITION_SCOPE.md`.

Primary in-scope launch modules:

- auth, company bootstrap, locations
- roles, permissions, admin, and settings essentials
- dashboard and location-aware operations shell
- POS and sales
- purchases and suppliers
- inventory control
- customers and collections
- accounting essentials
- reports
- HR core
- workflow/approvals and notifications in limited scope
- loyalty/promotions/warranty as controlled differentiators
- bulk import/export for onboarding

Out-of-scope enterprise-only or non-launch claims are defined in `docs/SMB_EDITION_SCOPE.md`.

## 6. Gap register

Severity definitions:

- `P0`: release blocker, cannot launch SMB Edition with this unresolved
- `P1`: high-priority hardening or commercialization gap, can ship only with explicit narrowed claims and tracked plan
- `P2`: important backlog item, not a Phase 1 launch blocker

| ID | Severity | Gap | Repo-backed evidence | Exit criteria |
|---|---|---|---|---|
| GAP-01 | P0 | Finance integrity and reconciliation confidence must be proven end to end | Release report identifies financial integrity and banking/close operations as largest SMB gaps | UAT evidence covers sale, return, purchase, collection, expense, cash close, and accounting reports without drift |
| GAP-02 | P0 | Banking and reconciliation are not first-class launch workflows | `docs/release_market_readiness_report.md` identifies bank reconciliation and close controls as missing depth | SMB claim text excludes bank reconciliation; release notes and sales collateral do not imply treasury depth |
| GAP-03 | P0 | Governance baseline was incomplete and required read-first docs were missing | `AGENTS.md` referenced three missing documents before this change | Required baseline docs exist, cross-reference each other, and are kept current in repo |
| GAP-04 | P0 | Operator launch package must stay complete and current | Launch docs now exist, but UAT evidence and final sign-off still determine release readiness | Launch pack includes UAT matrix, demo dataset manifest, operator guides, backup/restore SOP, release checklist, and support triage guide |
| GAP-05 | P1 | Security hardening must be verified in the packaged deployment | Security policy, session timeout, and step-up controls now exist but must be validated in the actual release environment | Production verification evidence is attached to the release candidate |
| GAP-06 | P1 | Web app is not a parity-safe launch surface | `go_backend_rmt/internal/routes/FRONTEND_PARITY.md` marks many web route groups as reserved/intentionally unused; `next_frontend_web/README.md` says tests are not configured | Market web app as limited office shell only until its own gates exist |
| GAP-07 | P1 | Backend-ready endpoints exceed commercialized UI scope | `tools/api_parity_report.md` lists multiple OpenAPI paths unused by Flutter | Each unused endpoint is classified as internal, future, or intentionally uncommercialized |
| GAP-08 | P1 | Production config still depends on external discipline | `go_backend_rmt/.env.example` includes `JWT_SECRET=change_me_in_production`; Flutter fallback base URL is localhost | Release gate requires production env verification and packaged build review |
| GAP-09 | P1 | Workflow and notifications are present but lightly wired into high-risk flows | Current reports call out workflow depth as a gap | Limit claims to current approval list/review behavior until more flows are wired |
| GAP-10 | P1 | Demo dataset automation exists, but release-candidate teams must actually run it and archive the resulting evidence | Repo now contains the governed manifest, reset command, and generated report path | Run the reset command for the release candidate and attach the generated report to UAT evidence |
| GAP-11 | P2 | Flutter domain isolation is incomplete | Current market readiness report notes limited domain isolation | Track as architecture debt, not a launch blocker |
| GAP-12 | P2 | Asset/consumable and similar newer backend/UI slices are not yet commercialized | Inventory surface includes assets/consumables, but they are not part of current market narrative or module feature list | Decide ship, pilot, or hide before any public claim |

## 7. Blockers and non-blockers

### Release blockers

- Any failing required command gate
- Any Flutter-called endpoint missing from OpenAPI
- Any reachable placeholder or dead-end workflow in production for launched modules
- Missing launch governance documents called out in `docs/REPO_GOVERNANCE_ARTIFACTS.md`
- Lack of controlled UAT evidence for core financial and stock flows
- Production secrets/base URLs/password reset URL not validated for release configuration

### Non-blockers if claims remain narrow

- Unused backend endpoints that are clearly marked future/internal
- Limited web office shell parity, provided the web app is not sold as the primary SMB surface
- P2 architecture cleanups
- Enterprise-only backlog items frozen out of Phase 1 claims

## 8. Required demo dataset content

Before launch, the repo must contain or reproduce a demo dataset with:

- 1 demo company and 3 locations: HQ, Main Store, Secondary Store
- 8 named users across Admin, Manager, Cashier, Purchaser, Accountant, Inventory, HR, Viewer roles
- 2 tax profiles and 5 payment methods including one split-payment scenario
- 60 products:
  - 30 standard SKUs
  - 10 serialized items
  - 10 batch-tracked items
  - 10 variant or barcode-rich products
- 15 customers with mixed cash and credit behavior
- 10 suppliers
- 20 purchase documents including GRN and at least 2 purchase returns
- 50 sales documents including cash, split payment, quote conversion, hold/resume, and 3 sale returns
- 10 collections and 8 expenses
- 1 open day and 2 closed day-end cash sessions with variance examples
- loyalty settings, 3 loyalty tiers, and 2 promotions
- 5 warranty-linked sales
- 6 employees, attendance records, leave requests, and 1 payroll cycle
- 5 workflow requests and 5 notifications

## 9. Required onboarding and support assets

These artifacts are mandatory before launch:

- cashier quick-start guide
- day open/close SOP
- purchase receiving and return SOP
- stock adjustment and transfer SOP
- finance period-end and voucher usage SOP
- admin/security setup guide
- backup/restore runbook
- release install/upgrade checklist
- support triage and escalation guide
- demo dataset reset/reseed instructions

## 10. Milestones

### Milestone A: Scope freeze

- Baseline docs approved in repo
- safe claims frozen
- out-of-scope enterprise list frozen

### Milestone B: Hardening

- P0 gaps addressed or formally claim-fenced
- placeholder and dead-end flows removed from launch surface
- release config hardening verified

### Milestone C: UAT

- module UAT evidence completed using `docs/MODULE_UAT_MATRIX.md`
- demo dataset and onboarding pack available

### Milestone D: Launch sign-off

- `docs/RELEASE_GATES_CHECKLIST.md` fully satisfied
- parity report regenerated and clean
- all mandatory command gates pass

## 11. Change control

Any endpoint or flow changed after this baseline must update, in the same slice:

- backend logic and tests
- migrations if schema changes
- `go_backend_rmt/openapi.yaml`
- Flutter integration and UI where shipped
- `tools/api_parity_report.md`
- scope/UAT/docs if release claims change
