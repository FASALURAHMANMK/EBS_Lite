# EBS Lite — Release Readiness Improvements (as of 2026-03-02)

This is a consolidated gap list for making `flutter_app/` + `go_backend_rmt/` release-ready and **API 1:1 matched**.

## 0) Market baseline (what comparable SMB POS/ERP products ship)

This section is based on a quick market scan of mainstream SMB retail POS + lightweight ERP offerings (examples: Lightspeed Retail, Odoo POS, ERPNext POS docs, and common POS “cash drawer/session” operational guides). Use it as a **pragmatic v1 baseline**, in addition to the repo’s own requirements docs.

See also: `MARKET_FEATURE_MATRIX_2026_03_02.md`.

### Must-have v1 (customer expectations)

- POS selling
  - Barcode scan/search, fast cart UX, discounts (line + invoice), refunds/exchanges/returns-by-reference, store credit.
  - Split payments (multiple tenders per sale) and change calculation.
  - Quotes and “special order” style flows (sell when out-of-stock) if you support it in scope.
  - Receipt/invoice share + reprint flows that work reliably (PDF/thermal receipt).
- Cash drawer / session management
  - Start-of-day float, end-of-day count, variance, X/Z-style reports.
  - Cash drops/payouts (“cash pull” to safe) with auditing and manager approval.
  - Ability to open drawer with permission gating (not everyone).
  - “Training mode” so staff can practice without impacting real totals/inventory.
  - Recovery for lost/broken devices: admin ability to force-close stuck open registers/sessions.
- Inventory + purchasing
  - Purchase orders + receiving, supplier returns, stock counts, stock transfers, reorder points + low-stock alerts.
  - Variants/bundles/serial/batch where applicable; inventory valuation and clear stock ledger.
- Customer + loyalty/promotions
  - Customer profiles, purchase history, loyalty earn/redeem, promotions engine (BOGO/%/$ rules), and permissions around discount overrides.
- Multi-location + roles
  - Multi-location inventory and (if needed) multi-location pricing.
  - Role-based permissions for high-risk actions (discounts, voids, returns, cash drops, day close).
- Reporting + exports
  - Drilldown reports + export (CSV/XLSX/PDF), scheduling later (nice-to-have).
  - Operational export bundles for support (logs + failed sync items + environment metadata).

### Typical hardware expectations (POS reality)

- Thermal receipt printers (ESC/POS), cash drawer kick, barcode scanners, and optional customer display.
- “Works on Windows + Android” in real stores with intermittent networks.

### Common market gaps (what to avoid)

- Offline mode that “works” but creates duplicates or inconsistent stock when reconnecting (lack of idempotency + conflict rules). → Prompts: `08`, `08A`
- Offline behavior that quietly changes “what you can do” (e.g., payments/shipping/reporting limitations), causing staff confusion and bad reconciliations. → Prompts: `08A`, `18`
- Cash session lifecycle bugs (registers stuck open forever; no admin override to close/zero). → Prompt: `09A`
- Weak “day end” operational flow (no guided cash count → variance → close; no Z close artifacts). → Prompt: `09A`
- Discount/void/return permissions that are too loose (shrinkage and fraud risk). → Prompt: `18A`
- Missing audit trail (who did what, when, from which device). → Prompts: `13`, `18A`, `09A`
- Receipt/printing reliability gaps (printer pairing, reprint/share consistency, template drift). → Prompts: `12`, `18B`
- Hardware assumptions not validated (cash drawer kick, scanner behavior, Windows/Android differences). → Prompt: `18B`
- Poor onboarding: no import/export templates, no backup/restore story, no data portability/export bundle for support. → Prompts: `16`, `07A`
- Reporting that looks “present” but fails in practice (filters inconsistent, exports flaky, bytes vs JSON errors). → Prompt: `17`

### Robust solutions to implement (high leverage)

- Offline-first safety:
  - Idempotency keys on all write endpoints used by the outbox.
  - Clear conflict strategy (server-authoritative for stock/cash; LWW only for low-risk fields).
  - Sync telemetry (attempt count, payload size, failures) and visible user-facing sync status.
- Cash management safety:
  - Server-side register/session model with forced-close and audit log.
  - Denomination counting + cash drops/payouts with manager approval and receipts.
  - Training mode (separate “non-posting” transactions).
- Security:
  - Strict RBAC + manager override workflow for risky actions.
  - Device session management (revoke, enforce limits) and safe offline entitlement expiry behavior.

## 1) Tooling / CI (must be green)

- Add CI checks (and make them required):
  - Go: `go test ./...`, `go vet ./...`, `gofmt -l .`
  - Flutter: `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed .`
  - Contract drift: `python -m pip install -r tools/requirements.txt` then `python tools/api_parity_check.py --out tools/api_parity_report.md`
- Make API parity tooling reproducible on a clean machine (Python deps, docs, CI wiring).

## 2) API contract parity (Flutter ↔ OpenAPI ↔ Backend)

- Fix `tools/api_parity_check.py` false-positive for dynamic report paths (`/reports/$endpoint`) by:
  - Replacing dynamic concatenation with explicit constants (preferred), OR
  - Teaching the checker to resolve the allowed report endpoints list from Flutter code.
- Add a **backend vs OpenAPI** parity check:
  - Dump actual Gin routes (source of truth) and compare to `go_backend_rmt/openapi.yaml` (normalize `:id` ↔ `{id}`).
  - Fail CI on drift.
- Ensure OpenAPI models reflect real request/response payloads (not just paths/methods).

## 3) Backend security / ops hardening

- Secrets hygiene:
  - Remove committed `go_backend_rmt/.env` from version control.
  - Add `go_backend_rmt/.env.example` and ensure `.env` is ignored.
  - Ensure production refuses to start with default/weak secrets (already partially enforced for JWT).
- File uploads:
  - Enforce max request size (middleware) using `MAX_UPLOAD_SIZE`.
  - Validate file types (content-type + extension allowlist).
  - Store uploads with non-guessable names; prevent path traversal.
- Response consistency:
  - Include request ID in **all** responses (success + error) so clients can report issues (implemented for success/created/paginated in `go_backend_rmt/internal/utils/response.go`).

## 4) DB schema + migrations

- Move from “schema validation only” to a real migrations workflow:
  - Apply `Docs & Schema/migrations/*.sql` automatically (or adopt `golang-migrate`, `goose`, etc.).
  - Keep `PostgrSQL.sql` (full schema) and migrations consistent and tested.
- Idempotency keys:
  - Ensure DB columns + unique indexes exist in the real DB for `purchases` and `collections` (migration exists: `2026_03_02_add_idempotency_purchases_collections.sql`).
  - Add regression tests for duplicate idempotency keys returning the original record.

## 5) Flutter production config + code quality

- Formatting gate: `dart format --set-exit-if-changed .` currently reports changes (format drift).
- Production base URL:
  - Keep `--dart-define=API_BASE_URL=...` but remove unsafe hard-coded defaults for release builds (use flavors / build-time asserts).
- Ensure offline outbox behavior is correct and complete:
  - Confirm queued POS checkout / purchases / collections cover all transaction-critical flows.
  - Ensure UX clearly communicates queued/failed sync and supports retry.
  - Add a conflict/error review screen for failed items (why it failed, retry, discard, contact support).

## 6) Flutter UX gaps (customer-facing)

- Fix drawer/rail navigation wiring for submenu items (currently subitems can route to a generic “label page” instead of real screens).
- Quick actions: wire Purchase/Collection/Expense quick actions (currently only Sale is wired).
- Notifications: replace demo list with backend-driven notifications (or hide module until implemented).
- Settings: implement real settings screens for tax/invoice/printer/payment methods/device control/session limits (many tiles are placeholders).
  - Add a “Day End” guided flow (cash count → variance → Z report → close session) to reduce operator error.

## 7) Module completeness vs SMB ERP requirements

Use `flutter_app/ERP System Requirements Document.txt` and `ebs_lite_win/Requirements.txt` as the product checklist. The big remaining “completeness” risk areas:

- Administration: Users/Roles/Permissions UI, device session management, audit viewer polish, workflow approvals.
- Imports/Exports: inventory/customers/suppliers import/export flows (endpoints exist; UI coverage must be confirmed).
- POS: verify split payments, multi-currency tenders, printing flows, returns-by-reference, day open/close.
- Reporting: ensure all required reports exist, filterable, and export/share works reliably on all platforms.
