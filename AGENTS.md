# Codex Agent Guide — EBS Lite (Flutter + Go)

## Scope

This repo is a multi-project ERP:
- Flutter client: `flutter_app/`
- Go backend: `go_backend_rmt/`

Primary goal: make both projects **release-ready** and keep them **API 1:1 matched**.

## Always read first (requirements + current gaps)

- `RELEASE_READINESS_PLAN.md`
- `flutter_app/ERP System Requirements Document.txt`
- `go_backend_rmt/Docs & Schema/ERP System Requirements Document.txt`
- `ebs_lite_win/Requirements.txt` (feature backlog reference)
- `tools/api_parity_report.md` (generated snapshot; regenerate when needed)

## Non-negotiables (Definition of Done)

- No failing checks:
  - Go: `go test ./...`, `go vet ./...`, `gofmt -l`
  - Flutter: `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed .`
- OpenAPI is accurate and complete: `go_backend_rmt/openapi.yaml`
- Flutter and backend are in sync:
  - No Flutter-called endpoints missing from OpenAPI
  - No “placeholder” screens remain reachable in production builds
- Performance: remove obvious N+1 patterns and expensive per-request DB writes on hot paths.
- Security: no default secrets in production; password reset uses a real configured URL; uploads are size/type validated.

## Parity workflow (run this often)

From repo root:
- `python tools/api_parity_check.py --out tools/api_parity_report.md`

If the report shows missing paths/methods:
- Update `go_backend_rmt/openapi.yaml` (or the generation process if you add one)
- Re-run the checker until “missing from OpenAPI” is empty

## Go backend workflow

From `go_backend_rmt/`:
- `go test ./...`
- `go vet ./...`
- `gofmt -w <changed files>`

Rules:
- Avoid `fmt.Printf` in services/handlers; use consistent logging.
- Prefer stable API responses via `internal/utils/*Response`.
- Add timeouts, request IDs, and rate limiting for production.
- Prefer batched queries over N+1 patterns in list endpoints.

## Flutter workflow

From `flutter_app/`:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `dart format --set-exit-if-changed .`

Rules:
- No hard-coded base URLs. Use `--dart-define` / flavors and a config provider.
- Keep feature boundaries clean:
  - `features/<module>/{data,domain,presentation}`
  - UI should not contain raw HTTP logic.
- Replace placeholder modules (Accounts/HR/Reports/Notifications/Invoices/Promotions) with real screens wired to backend.
- Implement offline outbox (SQLite) for transaction-critical flows (POS/Purchases/Collections minimum).

## Change discipline

- Keep PR-sized changes: one module or one cross-cutting concern per change.
- If you add or modify an endpoint:
  - Update backend handler/service + tests
  - Update OpenAPI
  - Update Flutter repository + DTOs + UI
  - Re-run `tools/api_parity_check.py`

