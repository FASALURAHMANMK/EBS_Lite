# Phase 1 Codex Prompt Set

Goal: deliver a complete SMB release-ready EBS Lite product on the current stack.

Use these prompts in order. Do not skip a prompt. Each prompt assumes the prior one is completed, committed, and documented.

## Global Rules For Every Phase 1 Prompt

You are working in E:\PROJECTS\EBS_Lite.

Mandatory read-first context:
- AGENTS.md
- docs/release_market_readiness_report.md
- docs/ACCOUNTING_MODULE_USER_MANUAL.md
- docs/module_wise_feature_list.md
- ebs_lite_win/Requirements.txt
- tools/api_parity_report.md
- go_backend_rmt/internal/routes/FRONTEND_PARITY.md

Mandatory completion rules:
- Maintain an explicit update plan and keep it current.
- Before editing, inspect the existing implementation and document assumptions.
- Do not leave placeholder UI reachable in production.
- If you add or modify an endpoint, update backend logic, tests, OpenAPI, Flutter integration, and parity artifacts.
- Prefer small cohesive slices, but complete the requested scope end to end.
- For every prompt, explicitly cover:
  - business logic
  - data model and migrations
  - API and OpenAPI
  - Flutter repository/controller/UI impact
  - permissions and security impact
  - offline/outbox/idempotency impact where relevant
  - operator/admin documentation impact
- Always finish with:
  - code changes
  - tests
  - documentation updates
  - a risk list
  - exact commands run
  - exact remaining gaps if anything could not be completed

Mandatory quality gates before claiming completion:
- From go_backend_rmt: go test ./..., go vet ./..., gofmt -l .
- From flutter_app: flutter analyze, flutter test, dart format --set-exit-if-changed .
- From repo root: python tools/api_parity_check.py --out tools/api_parity_report.md

Mandatory engineering expectations:
- Preserve Flutter feature boundaries.
- Keep UI free of raw HTTP logic.
- Prefer stable API responses.
- Protect financial flows with idempotency and transactional correctness.
- Add or update tests for positive, negative, authorization, validation, and regression paths.
- Update operator-facing and developer-facing docs when behavior changes.
- Include a UI plan and test matrix before implementation when the slice affects user-visible flows.
- Include seeded or reproducible test data where reports, finance, or approval flows are involved.
```

## Prompt 1: SMB Edition Freeze And Release Control Baseline

```text
Act as a principal product architect and release lead.

Objective:
Freeze a commercially defensible SMB Edition scope for EBS Lite and convert the current repo into a governed release program baseline.

Tasks:
1. Read the required docs and inspect the current Flutter, Go, and web app module surface.
2. Produce or update the following docs:
   - RELEASE_READINESS_PLAN.md
   - a clear SMB edition scope document
   - a release gates checklist
   - a module-by-module UAT matrix
   - a doc listing all missing or stale repo governance artifacts
3. Define in-scope SMB modules, out-of-scope enterprise-only items, and release claims that are safe to make.
4. Reconcile the current report, module list, accounting manual, and backlog into one consistent release baseline.
5. Identify every production-risk placeholder, dead route, partial feature, or backend-ready-but-uncommercialized capability.
6. Create a prioritized gap register with P0/P1/P2 severity.
7. Update relevant docs so the repo becomes the single source of truth for the SMB release program.

Output requirements:
- The output must be concrete and repo-backed, not generic.
- Include exact module acceptance criteria.
- Include exact UAT scenarios per module.
- Include release blockers and non-blockers separately.
- Include required demo dataset content and onboarding assets.
- Include support/readiness docs that must exist before launch.

Validation:
- Ensure all new docs are referenced consistently.
- Ensure no release claim contradicts the current implementation.
- Re-run parity if doc changes depend on endpoint status claims.
```

## Prompt 2: Financial Integrity Hardening Program

```text
Act as a principal backend engineer with finance-domain responsibility.

Objective:
Make the core financial and inventory-affecting workflows commercially trustworthy for SMB release.

Work scope:
1. Audit and harden these flows:
   - POS checkout
   - sales creation
   - held sale and void sale
   - purchase creation
   - goods receipt
   - collections
   - expenses
   - supplier payments
   - sale returns
   - purchase returns
   - loyalty redemption side effects
   - coupon redemption side effects
   - raffle issuance side effects
   - cash register event side effects
   - ledger posting side effects
2. Classify each side effect as:
   - must be atomic with the transaction
   - may be async but guaranteed through outbox
   - may be best-effort and observable
3. Implement a transactional outbox pattern where needed.
4. Remove any accounting drift risk between operational truth and ledger truth.
5. Add reconciliation utilities and admin-visible diagnostics for mismatch detection.
6. Tighten numbering, idempotency, and retry semantics for offline-first flows.
7. Update OpenAPI and all relevant docs.

Tests required:
- success path
- duplicate/idempotent replay
- rollback on required posting failure
- async outbox enqueue and replay
- authorization failures
- invalid payload validation
- offline retry compatibility
- concurrency and document number collision protection where applicable

UI expectations:
- Do not degrade cashier or operator speed.
- Add visible states where async processing or retries matter.
- Add error messaging that is operationally actionable.

Completion definition:
- No known path can leave the system in an unreconciled state without surfacing a supportable diagnostic trail.
```

## Prompt 3: SMB Accounting, Banking, And Close Readiness

```text
Act as a principal ERP finance engineer and accountant-friendly product designer.

Objective:
Raise EBS Lite accounting from adequate to strong SMB release quality, with clear advantages over lightweight competitors and fewer trust gaps versus Tally-style expectations.

Implement and complete:
1. Banking and cash controls:
   - bank account master and usage model if missing
   - bank statement import or structured statement entry
   - bank reconciliation workflow
   - unmatched/matched/review states
   - bank charges and adjustment handling
2. Accounting operations:
   - stronger voucher controls
   - true journal design plan and implementation if feasible in current data model; if not fully feasible, implement the safest incremental path and document the next slice
   - richer chart-of-accounts management
   - period-close checklist and close-status visibility
   - improved audit drill-down from reports to source documents
3. Asset and finance support:
   - fixed-assets-lite with depreciation basics if achievable in Phase 1
   - stronger expense categorization and finance tagging
   - clearer tax reporting and tax review flows
4. Reporting:
   - cash book
   - bank book
   - reconciliation summary
   - improved GL / TB / P&L / balance sheet usability and exportability

UI expectations:
- Finance pages must be usable by accountants, not only developers.
- Navigation and terminology must be consistent with the accounting manual.
- Dense pages must preserve clarity and traceability.

Tests required:
- accounting entry correctness
- tax split correctness
- reconciliation match/unmatch cases
- period-close permissions and constraints
- report correctness for representative seeded scenarios

Docs required:
- update docs/ACCOUNTING_MODULE_USER_MANUAL.md
- update release/readiness docs
- add operator guidance for bank reconciliation and close routines
```

## Prompt 4: Workflow, Inventory Execution, And Operational Differentiation

```text
Act as a senior ERP product engineer focused on real-world SMB operations.

Objective:
Close the highest-value operational gaps that improve adoption, reduce manual work, and sharpen EBS Lite’s advantage over Tally and Zoho for retail/distribution SMBs.

Implement and complete:
1. Workflow and approvals:
   - wire workflow requests into procurement approvals, returns, overrides, sensitive settings changes, and master-data changes where appropriate
   - add approval statuses, reasons, escalation visibility, and audit traceability
2. Notifications:
   - make notifications actionable, role-aware, and tied to real workflows
   - include unread, pending, overdue, and exception-driven states
3. Inventory execution:
   - bin/location control where feasible
   - cycle count program basics
   - replenishment or reorder rules
   - better barcode/stock utility exposure in Flutter
4. AR/AP operations:
   - collections and supplier balance workflows with stronger drill-down
   - expose currently backend-ready but commercially useful endpoints if they strengthen release value
5. Commercial differentiation:
   - tighten loyalty, promotions, warranty, and customer-service workflows into one coherent operator experience

UI expectations:
- remove dead ends and vague “coming soon” patterns
- ensure every surfaced action has a complete backend-backed path
- preserve fast store workflows on smaller screens

Tests required:
- approval state transitions
- permission gating
- notification generation and mark-read flows
- inventory execution edge cases
- regression tests for exposed backend-ready endpoints
```

## Prompt 5: Release Operations, Security Hardening, And Final SMB Ship

```text
Act as release manager, security engineer, SRE, QA lead, and documentation owner.

Objective:
Turn the repo into an SMB release-ready product package, not just a codebase with passing tests.

Implement and complete:
1. Security:
   - admin MFA or equivalent elevated-operation protection
   - stronger password and session policies
   - explicit production secret/config guidance
   - rate-limiting fallback behavior review
   - CORS/origin deployment guidance
2. Release operations:
   - backup SOP
   - restore SOP
   - monitoring and alerting SOP
   - incident/support SOP
   - deployment and rollback SOP
   - release checklist
3. Productization:
   - sample/demo dataset
   - customer onboarding checklist
   - environment templates
   - support bundle guidance
   - pricing/edition-ready feature matrix if appropriate for docs
4. QA completion:
   - run and fix all required checks
   - regenerate parity report
   - complete UAT evidence pack
   - produce a final blocker list and go/no-go summary

Final output required:
- updated code
- updated docs
- exact checks run and results
- remaining known limitations
- explicit statement whether the SMB product is release-ready
- if not fully ready, list the exact residual blockers only
```
