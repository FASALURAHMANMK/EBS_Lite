# Release Checklist (EBS Lite) — 2026-03-03

This checklist is for producing a release-candidate build of:
- Go backend: `go_backend_rmt/`
- Flutter app: `flutter_app/`

## Quality gates (must be green)

Run from repo root:
- `python tools/api_parity_check.py --out tools/api_parity_report.md`
- `python tools/openapi_route_drift_check.py --out tools/backend_openapi_drift_report.md`

Run from `go_backend_rmt/`:
- `go test ./...`
- `go vet ./...`
- `gofmt -l .` (must print nothing)

Run from `flutter_app/`:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `dart format --output=none --set-exit-if-changed .`

## Backend environment (production-safe)

Required:
- `DATABASE_URL` (Postgres URL)
- `JWT_SECRET` (must be a real secret in production)
- `ENVIRONMENT` (`production` for prod)
- `REDIS_URL` (if using Redis-backed last_seen throttling and readiness checks)
- `MAX_UPLOAD_SIZE` (e.g. `10MB`)
- `UPLOAD_PATH` (absolute or known-safe directory)
- `FRONTEND_BASE_URL` (used in emails/links)
- SMTP: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `FROM_EMAIL`

Recommended (ops / hardening):
- `ALLOWED_ORIGINS` (comma-separated)
- `RATE_LIMIT_ENABLED`, `RATE_LIMIT_REQUESTS`, `RATE_LIMIT_WINDOW`
- `RUN_MIGRATIONS=true` (recommended on boot)
- `MIGRATIONS_DIR=migrations`
- `SUPPORT_BUNDLE_ENABLED=false` (keep disabled in production unless explicitly needed)
- `READY_CHECK_REDIS=true` (if Redis is required)

## Database migrations (Goose)

The backend uses `pressly/goose` and expects migrations under `go_backend_rmt/migrations/`.

Deployment expectation:
- On a brand-new DB, start the server with `RUN_MIGRATIONS=true` so schema is created/upgraded automatically.
- Ensure the release includes migrations:
  - `go_backend_rmt/migrations/202601010000_init_schema.sql`
  - `go_backend_rmt/migrations/202601210000_fix_missing_schema_columns.sql`
  - `go_backend_rmt/migrations/202603020000_add_idempotency_purchases_collections.sql`

## Backups (minimal operator runbook)

Suggested baseline (adjust host/db/user):
- Backup: `pg_dump --format=custom --no-owner --no-acl --file=backup.dump "$env:DATABASE_URL"`
- Restore: `pg_restore --no-owner --no-acl --clean --if-exists --dbname="$env:DATABASE_URL" backup.dump`

Operational suggestions:
- Automated daily backups + 7–30 day retention.
- Test restores periodically (at least monthly) to a staging database.

## Flutter build inputs

Set API base URL via `--dart-define`:
- `--dart-define=API_BASE_URL=https://YOUR_DOMAIN/api/v1`

Example release builds:
- Windows: `flutter build windows --release --dart-define=API_BASE_URL=...`
- Android: `flutter build apk --release --dart-define=API_BASE_URL=...`

## Operational endpoints (deployment checks)

Verify after deploy:
- `/ready` returns success (DB + optional Redis checks).
- File upload endpoints enforce size/type/name rules:
  - `/companies/{id}/logo`
  - `/purchases/{id}/invoice`
  - `/purchase-returns/{id}/receipt`

## Prompt 19 performance notes (hot paths)

Measured by query-count reduction (per request):
- Sale totals + sale create: product meta and tax percentage lookups are batched (no per-line DB queries).
- POS held sale + finalize: uses the same batched tax/product meta helpers.
- Auth middleware: throttled `device_sessions.last_seen` update is best-effort and async (reduces request latency on hot routes).
