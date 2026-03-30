# EBS Lite Repo Governance Artifacts

Date: 2026-03-30
Purpose: inventory release-governance documents, identify missing or stale artifacts, and track what must exist before SMB launch

## 1. Available authoritative artifacts

| Artifact | Path | Status | Notes |
|---|---|---|---|
| Release readiness plan | `RELEASE_READINESS_PLAN.md` | Created in this baseline | Root read-first program plan |
| SMB edition scope | `docs/SMB_EDITION_SCOPE.md` | Created in this baseline | Commercial scope and safe claims |
| Release gates | `docs/RELEASE_GATES_CHECKLIST.md` | Created in this baseline | Launch sign-off checklist |
| Module UAT matrix | `docs/MODULE_UAT_MATRIX.md` | Created in this baseline | Module-by-module UAT scenarios |
| Governance inventory | `docs/REPO_GOVERNANCE_ARTIFACTS.md` | Created in this baseline | This document |
| Market readiness analysis | `docs/release_market_readiness_report.md` | Current but analytical | Input to baseline, not the release checklist itself |
| Module feature inventory | `docs/module_wise_feature_list.md` | Updated to reference baseline | Descriptive feature inventory |
| Accounting manual | `docs/ACCOUNTING_MODULE_USER_MANUAL.md` | Current | Governs current accounting behavior claims |
| API parity report | `tools/api_parity_report.md` | Generated artifact | Must be regenerated when API claims change |
| Web route parity note | `go_backend_rmt/internal/routes/FRONTEND_PARITY.md` | Current | Describes web route coverage, not launch scope |
| Flutter requirements pointer | `flutter_app/ERP System Requirements Document.txt` | Created in this baseline | Fulfills `AGENTS.md` read-first path |
| Backend requirements pointer | `go_backend_rmt/Docs & Schema/ERP System Requirements Document.txt` | Created in this baseline | Fulfills `AGENTS.md` read-first path |

## 2. Missing launch-critical artifacts still required

These are still missing after this documentation slice and remain launch blockers or high-priority gaps.

| Priority | Required artifact | Expected purpose |
|---|---|---|
| P0 | POS cashier SOP | Open sale, hold/resume, split payment, offline behavior, receipt reprint, void/override handling |
| P0 | Day open/close SOP | Register open, tally, movement, variance review, day close |
| P0 | Purchase receiving and return SOP | PO, GRN, quick purchase, attachments, return handling |
| P0 | Inventory control SOP | Product setup, stock adjustment, transfer, serial/batch handling |
| P0 | Backup/restore runbook | Operator-safe backup, restore, retention, and recovery validation |
| P0 | Demo dataset manifest and reset guide | Reproducible launch demo/UAT data with reset instructions |
| P0 | Support triage and escalation guide | Support bundle usage, first response, escalation path, issue classification |
| P1 | Release install/upgrade runbook | Deployment, upgrade order, smoke checks, rollback notes |
| P1 | Known issues register | Controlled record of accepted non-blockers at launch |
| P1 | Release notes template | Standardized release communication artifact |
| P1 | Sales/operator onboarding pack | Role-based onboarding for cashiers, managers, accountant, purchaser |
| P1 | Security operations checklist | Secret rotation, password reset URL validation, support bundle posture, upload policy verification |

## 3. Stale or insufficient artifacts

| Artifact | Path | Why it is stale or insufficient | Action |
|---|---|---|---|
| Flutter README | `flutter_app/README.md` | Still generic Flutter starter text and does not describe EBS Lite architecture, build flags, or release usage | Replace with product-specific README before launch |
| Web README | `next_frontend_web/README.md` | Notes that automated tests are not configured and does not define release ownership/scope | Keep as engineering note, but add web release posture if web becomes customer-facing |
| Market readiness report | `docs/release_market_readiness_report.md` | Strong analysis document but not by itself a governed launch baseline | Cross-reference controlled baseline docs and keep as supporting analysis |

## 4. Governance rules for future changes

- If scope changes, update `RELEASE_READINESS_PLAN.md`, `docs/SMB_EDITION_SCOPE.md`, and `docs/MODULE_UAT_MATRIX.md`.
- If API or route coverage changes, update `go_backend_rmt/openapi.yaml`, regenerate `tools/api_parity_report.md`, and revise any affected scope or UAT claims.
- If a placeholder is removed or a secondary surface becomes launch-critical, update this document and the release gates in the same slice.
