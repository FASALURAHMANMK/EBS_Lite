# Codex Prompt Runbook (exact execution order)

Use these prompts **in order**. Each prompt is intentionally scoped so Codex can complete it end-to-end (code + tests).

## 0) Baseline snapshot

**Prompt 0**
> Read `RELEASE_READINESS_PLAN.md`, then run the repo’s current checks you can run locally (Go tests/vet, parity check). Summarize failures and create a short “today’s work” checklist.

Acceptance:
- A checklist exists in the reply.
- Go: `go test ./...` passes.
- `python tools/api_parity_check.py --out tools/api_parity_report.md` runs.

## 1) Fix OpenAPI drift (must be 1:1)

**Prompt 1**
> Make `go_backend_rmt/openapi.yaml` match the implemented backend routes. Use `go_backend_rmt/internal/routes/routes.go` as the source of truth. Fix all paths/methods reported as missing/mismatched in `tools/api_parity_report.md` without changing runtime behavior. Re-run `python tools/api_parity_check.py --out tools/api_parity_report.md` until “Flutter paths missing from OpenAPI” and “Method mismatches” are empty.

Acceptance:
- Parity report shows **0 missing paths** and **0 method mismatches**.

**Prompt 2**
> Fix the `/health` documentation mismatch in `go_backend_rmt/openapi.yaml`: backend serves `/health` at the root (not under `/api/v1`). Update OpenAPI servers/paths accordingly and keep `/api/v1/*` unaffected.

Acceptance:
- OpenAPI correctly describes both `/health` and `/api/v1/*`.

## 2) Backend production hardening (security + ops)

**Prompt 3**
> Add request ID support end-to-end in the Go backend: enable the request-id middleware globally, include the request id in logs, and include it in error responses (without breaking existing response JSON contracts). Add a small test to validate header propagation.

**Prompt 4**
> Replace `fmt.Printf` debug prints in Go services with consistent logging. Ensure no sensitive tokens/passwords are logged. Run `go test ./...`.

**Prompt 5**
> Implement a real rate limiter for the Go backend (Redis-backed preferred since Redis is already in `docker-compose.yml`). Wire it globally and make it configurable via env vars. Add a minimal unit/integration test for the limiter behavior.

**Prompt 6**
> Harden the auth/session flow: if device session creation fails during login, return an error (do not continue with an empty session id). Ensure Flutter still logs in correctly (update Flutter if needed). Run Go tests.

**Prompt 7**
> Fix password reset links: introduce `FRONTEND_BASE_URL` env var in backend config, build reset links using it, and update `.env.example`. Ensure forgot/reset password flows still work (tests or a small harness).

## 3) Backend performance bottlenecks

**Prompt 8**
> Remove the N+1 query pattern in `ProductService.GetProducts` (barcodes + attributes). Replace it with batched queries and in-memory grouping. Add/adjust tests to cover correctness and run `go test ./...`.

**Prompt 9**
> Reduce per-request DB writes in auth middleware (device session `last_seen` updates). Implement a throttling strategy (e.g., only update once per N seconds per session) using Redis or an in-memory TTL map. Add a test.

## 4) Flutter production configuration

**Prompt 10**
> Remove hard-coded API base URLs from `flutter_app/lib/core/api_client.dart`. Implement a config provider reading `--dart-define=API_BASE_URL` with safe defaults for dev. Update any docs and ensure the app still boots.

**Prompt 11**
> Implement Flutter localization (English + Arabic minimum) with `flutter_localizations` and ARB files. Wire language selection to persisted user preferences and ensure receipt language can be different from UI language (store both).

## 5) Replace placeholder modules (UI + API wiring)

**Prompt 12**
> Replace the placeholder Accounts module screens with real implementations wired to backend endpoints: Cash Register (open/close/tally), Vouchers, Ledgers, Audit Logs. Keep UI consistent with existing theme and navigation patterns.

**Prompt 13**
> Replace the placeholder HR module screens with real implementations: Attendance (check-in/out + records + leave + holidays), Payroll (generate + payslip + mark paid). Wire to backend and add empty/loading/error states.

**Prompt 14**
> Replace the placeholder Reports module screens with real implementations using backend report endpoints. Add filters (date range, location) and export/share (PDF/Excel) using existing Flutter packages.

**Prompt 15**
> Replace Notifications demo data with a real backend-driven notifications feature. If backend has no notifications endpoints, implement them (DB table + CRUD + mark read) and update OpenAPI + parity checks.

**Prompt 16**
> Implement Sales “Invoices” and “Promotions” screens (replace placeholders) and wire to backend endpoints. Ensure printing/reprint/share flows work for invoices.

## 6) Offline-first (minimum viable)

**Prompt 17**
> Implement an offline outbox (SQLite) in Flutter for transaction writes (POS checkout, Purchases quick create, Collections). Queue requests when offline, replay on reconnect, and show a sync status UI (queued count + retry). Add idempotency keys to backend endpoints as needed.

## 7) Final quality gate

**Prompt 18**
> Add CI workflows to run Go + Flutter checks. Ensure the repo is warning-free. Run the full test suite and provide a final “release checklist” with any remaining manual steps (signing, store metadata, etc.).

