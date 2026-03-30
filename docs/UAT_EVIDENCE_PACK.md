# EBS Lite UAT Evidence Pack

Date: 2026-03-30

## 1. Automated evidence completed

Backend:
- `go test ./...` passed
- `go vet ./...` passed
- `gofmt -l .` returned clean output

Flutter:
- `flutter analyze` passed
- `flutter test` passed
- `dart format --set-exit-if-changed .` passed

Parity:
- `python tools/api_parity_check.py --out tools/api_parity_report.md` passed
- Flutter paths missing from OpenAPI: none
- Method mismatches: none

## 2. Security hardening evidence added in this slice

Backend tests:
- `internal/utils/password_policy_test.go`
- `internal/config/config_test.go`
- `internal/handlers/settings_test.go`

Flutter test:
- `flutter_app/test/security_settings_page_test.dart`

Implemented behavior verified by automated evidence:
- stronger password policy validation
- production config validation for secrets, origins, and reset URL posture
- elevated verification requirement for security-sensitive settings changes
- security settings UI rendering and backend support-bundle inclusion in the Flutter bundle flow

## 3. Dataset evidence

Governed artifacts now present:
- `docs/DEMO_DATASET_AND_ONBOARDING.md`
- `docs/OPERATOR_SOPS.md`
- `docs/RELEASE_OPERATIONS_RUNBOOK.md`
- `docs/SECURITY_OPERATIONS_GUIDE.md`

Current gap:
- the repo documents the demo dataset and reset procedure, but does not yet provide a one-command full demo/UAT data loader

## 4. Manual UAT status against `docs/MODULE_UAT_MATRIX.md`

Not completed in this coding slice:
- full operator sign-off on auth, POS, purchases, inventory, collections, accounting, reports, HR, workflow, and admin scenarios
- seeded reconciliation proof for POS checkout, sales returns, purchases, collections, expenses, day close, and accounting reports

These remain release blockers even though automated gates are green.

## 5. Evidence conclusion

Automated engineering gates are green.  
Manual release-candidate UAT evidence is still incomplete, so the repo is not yet at final launch sign-off.
