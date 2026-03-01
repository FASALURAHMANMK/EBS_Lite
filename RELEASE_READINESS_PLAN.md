# EBS Lite — Release Readiness Plan (Flutter + Go backend)

This repo contains:
- `flutter_app/` (Flutter client)
- `go_backend_rmt/` (Go/Gin + PostgreSQL backend)

## Current status (audit highlights)

### Go backend (`go_backend_rmt/`)
- Builds and tests pass (`go test ./...`).
- Docker setup was incomplete (missing `Dockerfile`, `mosquitto.conf`, DB init script mount); fixed by adding missing files and wiring schema mounting in `docker-compose.yml`.
- Production hardening gaps remain (timeouts were added; several security/ops items below are still pending).
- OpenAPI spec exists (`go_backend_rmt/openapi.yaml`) but is not fully aligned with implemented routes (missing paths/methods that Flutter uses).

### Flutter app (`flutter_app/`)
- Core modules (Auth, POS, Inventory, Customers, Suppliers, Purchases) appear implemented and call many backend endpoints via Dio.
- Major modules are placeholders or demo-only:
  - Accounts (`lib/features/accounts/...`) → placeholder screens
  - HR (`lib/features/hr/...`) → placeholder screens
  - Reports (`lib/features/reports/...`) → placeholder screens
  - Notifications (`lib/features/notifications/...`) → hard-coded demo data
  - Sales: “Invoices” and “Promotions” are placeholders
- Production config gaps:
  - API base URL is hard-coded in `lib/core/api_client.dart`.
  - Offline-first requirement (SQLite caching + replay) is not implemented (no DB layer in dependencies).
  - Localization implemented (English/Arabic) using `flutter_localizations` + ARB workflow.

### API parity status (Flutter vs OpenAPI)
- A parity checker was added: `tools/api_parity_check.py`.
- Latest report: `tools/api_parity_report.md` (generated).
- Key finding: Flutter calls endpoints/methods that exist in backend code, but are missing from `openapi.yaml` (docs drift).

## Definition of Done (DoD) for “production-ready”

1) Backend
- `go test ./...`, `go vet ./...` clean.
- Docker compose works end-to-end on a clean machine (DB schema + API boots).
- Strict, documented env configuration (`.env.example`), no default secrets in production.
- OpenAPI is complete and matches actual routes (and includes auth + all modules used by Flutter).
- Observability: request IDs, structured logs, basic metrics/health/readiness.
- Security: JWT, password reset, file uploads, CORS, rate limiting, and audit logging hardened.
- Performance: no obvious N+1 patterns on list endpoints; hot paths profiled.

2) Flutter
- `flutter analyze` clean; tests (at least smoke/widget tests) cover auth + key flows.
- API base URL and build flavors configured for dev/stage/prod.
- Offline transactions queue (SQLite) implemented for POS + Purchases + Collections (minimum).
- i18n implemented (primary + secondary language, incl. receipt language).
- Placeholder modules replaced by real screens wired to backend.
- App UX consistent across phone/tablet/desktop (NavigationRail + responsive layouts).

3) Parity
- Flutter screens cover every “kept” backend module (or backend endpoints removed/deprecated).
- A single source of truth exists for API contracts (OpenAPI), with CI checks.

## Critical blockers (must fix before release)

1) OpenAPI drift
- `openapi.yaml` is missing multiple endpoints/methods used by Flutter (see `tools/api_parity_report.md`).
- Fix: make OpenAPI generation/maintenance a first-class build step.

2) Offline-first requirement not implemented
- Requirements explicitly call for “cache transactions in sqlite when offline and replay when online”.
- Fix: introduce a local queue + conflict strategy + idempotency keys.

3) Placeholder modules
- Accounts/HR/Reports/Notifications/Invoices/Promotions must be implemented or removed from navigation.

4) Password reset flow uses a placeholder URL
- Backend generates reset links for `https://example.com/...`.
- Fix: configure a real `FRONTEND_BASE_URL` and implement the matching Flutter deep-link flow.

## Work plan (recommended execution order)

### Phase 0 — Stabilize tooling + repo hygiene (1–2 days)
- Add CI (GitHub Actions or equivalent) to run:
  - Go: `go test ./...`, `go vet ./...`, `gofmt -l`
  - Flutter: `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed .`
- Ensure secrets are not committed; standardize `.env` usage (backend already has `.env.example`).
- Add a single “dev quickstart” doc at repo root (how to run DB + API + Flutter).

### Phase 1 — Backend contract + docs become source of truth (2–4 days)
- Make `go_backend_rmt/openapi.yaml` match implemented routes:
  - Add missing paths/methods: brands PUT/DELETE, customers GET by id, POS hold/void/calculate, loyalty tiers CRUD, payment-method currencies, stock adjustments docs endpoints, etc.
  - Fix the `/health` server base mismatch (backend serves `/health` at root, not under `/api/v1`).
- Add a “contract check” in CI using `tools/api_parity_check.py` (fail if drift).
- Optional but recommended: generate OpenAPI from Go route definitions (or move to “OpenAPI-first” and enforce).

### Phase 2 — Backend production hardening (3–7 days)

**Security**
- Replace `fmt.Printf` debug prints with structured logging (no stdout noise, no secrets).
- Add real rate limiting (Redis-backed, per IP/user/session) and wire `middleware.RateLimiter()`.
- Add stricter CORS policy for production and document it.
- File uploads:
  - Enforce `MaxUploadSize` at middleware level.
  - Validate file types; store with non-guessable names; scan if required.
- Auth:
  - Make device session creation errors fatal (don’t silently continue with empty `session_id`).
  - Add optional “device_name” from client.
- Password reset:
  - Add `FRONTEND_BASE_URL` env and build reset link from it.

**Ops/observability**
- Add request ID middleware globally and include it in logs and responses.
- Add readiness endpoint (e.g., `/ready`) that verifies DB + redis connectivity.
- Add pprof/metrics in non-prod builds (guarded by env).

**DB + schema**
- Introduce a real migrations system (Go migrate tool) instead of relying solely on schema validation.
- Add constraints and indexes for hot paths (POS product search, sales history, stock lookups).

**Performance (high impact)**
- Remove N+1 query patterns:
  - Example: `GetProducts` loads barcodes + attributes per product.
  - Replace with batch queries or joins and rehydrate in memory.
- Avoid per-request DB writes in auth middleware (device session “last_seen” update):
  - Batch updates, rate-limit them (e.g., once per 60s), or use Redis.

### Phase 3 — Flutter production configuration (2–5 days)
- Base URL:
  - Use `--dart-define=API_BASE_URL=...` and expose it via a config provider.
  - Add dev/stage/prod flavors.
- Error handling:
  - Centralize Dio error mapping into typed failures.
  - Provide consistent UX: empty states, retry, offline banners.
- Authentication UX:
  - Add “device_name” and “include_preferences” support.
  - Implement password reset deep-link flow.

### Phase 4 — Implement missing Flutter modules (7–20 days)

**Accounts (replace placeholders)**
- Cash register: open/close, tally, variance, cashier/day reports.
- Vouchers + ledgers: chart of accounts, ledger entries view, export.
- Audit log viewer.

**HR**
- Attendance: check-in/out, attendance records, holidays, leave requests/approvals.
- Payroll: generate payroll, payslip view/export, mark paid.

**Reports**
- Implement the key reports already exposed by backend:
  - sales summary, tax, stock summary, valuation, outstanding, profit/loss, trial balance, etc.
- Add export/share workflows (PDF/Excel) with consistent UI.

**Notifications**
- Replace demo list with real server-driven notifications:
  - low-stock, payment received, approvals, failed sync, etc.
  - Add unread badge + mark read.

**Sales**
- Invoices list/detail (reprint/share).
- Promotions UI (CRUD + eligibility tests) matching backend.

### Phase 5 — Offline-first + sync (10–25 days)
- Add a local SQLite store (recommended: `drift` or `sqflite` + a small queue table).
- Implement an “outbox” pattern:
  - Queue write transactions with idempotency keys.
  - Replay when online; resolve conflicts by server timestamps + per-entity “last_updated”.
- Minimum offline scope:
  - POS checkout + hold/resume
  - Purchases quick create
  - Collections (customer payments)
- Add UX:
  - Online/offline indicator, queued count, manual sync button, conflict resolver.

## Cleanup / alignment decisions (must be explicit)

For every backend endpoint not implemented in Flutter, choose one:
1) Implement UI + flows (preferred if it’s in requirements).
2) Mark as “admin-only” and move to a separate web console.
3) Deprecate/remove the endpoint (and delete unused code).

Use `tools/api_parity_check.py` to keep this decision list honest.

## Release checklist (final gate)

- Backend
  - Fresh DB bootstrap works from `docker-compose up`.
  - OpenAPI validated and published.
  - Logs, timeouts, rate limiting, secrets all configured.
- Flutter
  - Builds for Android/iOS/Windows with correct flavor configs.
  - No placeholder screens accessible in prod builds.
  - Offline mode tested with forced airplane mode.
- Parity
  - Contract tests and parity script pass in CI.
