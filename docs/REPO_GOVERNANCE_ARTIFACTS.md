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
| Operator SOP pack | `docs/OPERATOR_SOPS.md` | Created in release hardening slice | Cashier, day close, purchase, and inventory SOPs |
| Release operations runbook | `docs/RELEASE_OPERATIONS_RUNBOOK.md` | Created in release hardening slice | Backup, restore, monitoring, incident, deployment, rollback, checklist |
| Security operations guide | `docs/SECURITY_OPERATIONS_GUIDE.md` | Created in release hardening slice | Secrets, origins, step-up controls, rate-limit posture |
| Demo dataset and onboarding pack | `docs/DEMO_DATASET_AND_ONBOARDING.md` | Created in release hardening slice | Dataset manifest, reset notes, onboarding checklist, support bundle guidance |
| SMB feature matrix | `docs/SMB_FEATURE_MATRIX.md` | Created in release hardening slice | Edition-ready packaging view |
| UAT evidence pack | `docs/UAT_EVIDENCE_PACK.md` | Created in release hardening slice | Records automated evidence and remaining manual UAT gap |
| Go / no-go summary | `docs/GO_NO_GO_SUMMARY.md` | Created in release hardening slice | Controlled launch decision summary |
| Known limitations register | `docs/KNOWN_LIMITATIONS_AND_ISSUES.md` | Created in release hardening slice | Accepted claim limits and launch caveats |
| Release notes template | `docs/RELEASE_NOTES_TEMPLATE.md` | Created in release hardening slice | Standardized release communication template |
| API parity report | `tools/api_parity_report.md` | Generated artifact | Must be regenerated when API claims change |
| Web route parity note | `go_backend_rmt/internal/routes/FRONTEND_PARITY.md` | Current | Describes web route coverage, not launch scope |
| Flutter requirements pointer | `flutter_app/ERP System Requirements Document.txt` | Created in this baseline | Fulfills `AGENTS.md` read-first path |
| Backend requirements pointer | `go_backend_rmt/Docs & Schema/ERP System Requirements Document.txt` | Created in this baseline | Fulfills `AGENTS.md` read-first path |
| Backend production env template | `go_backend_rmt/.env.production.template` | Created in release hardening slice | Deployment-safe backend template |
| Flutter production defines template | `flutter_app/dart_defines.production.example.json` | Created in release hardening slice | Packaged build template |

## 2. Missing launch-critical artifacts still required

These are still missing after this documentation slice and remain launch blockers or high-priority gaps.

| Priority | Required artifact | Expected purpose |
|---|---|---|
| P0 | Manual release-candidate UAT sign-off | Signed operator evidence against blocker scenarios in `docs/MODULE_UAT_MATRIX.md` |

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
