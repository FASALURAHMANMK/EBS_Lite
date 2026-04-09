# EBS Lite Repo Overview

Updated: 2026-04-09 UTC
Scope verified by inspection: `flutter_app/`, `go_backend_rmt/`, `next_frontend_web/`, `tools/`, `docs/`, `.codex/`

## 1. Actual top-level surfaces

- `flutter_app/`: primary SMB launch client and the main responsive/mobile/desktop surface
- `go_backend_rmt/`: Go backend, OpenAPI source, PostgreSQL migrations, Redis-backed middleware, and most business logic
- `next_frontend_web/`: enterprise-directed future web project with manual parity tracking and no verified automated test baseline; not part of current SMB release scope
- `tools/`: parity and drift scripts
- `docs/`: release, operator, market, and supporting docs
- `.codex/`: project-specific agent definitions plus the local subagent source catalog

## 2. Flutter structure and boundaries

Verified structure:
- feature packages live under `flutter_app/lib/features/*`
- shared and cross-cutting layers live under `flutter_app/lib/core` and `flutter_app/lib/shared`
- app entry is `flutter_app/lib/main.dart`
- the responsive shell is centered on `flutter_app/lib/features/dashboard/presentation/dashboard_screen.dart`

Observed pattern:
- most features are `data + presentation + optional controllers`
- the repo standard in `AGENTS.md` calls for `data/domain/presentation`, but domain isolation is not yet the dominant implementation pattern

Key UI/navigation files:
- `flutter_app/lib/features/dashboard/presentation/dashboard_screen.dart`
- `flutter_app/lib/features/dashboard/presentation/dashboard_navigation.dart`
- `flutter_app/lib/core/layout/app_breakpoints.dart`
- `flutter_app/lib/shared/widgets/feature_menu.dart`

Critical UX observation:
- Sales contains the strongest current desktop/mobile document pattern, especially:
  - `flutter_app/lib/features/sales/presentation/pages/sales_history_page.dart`
  - `flutter_app/lib/features/sales/presentation/pages/quote_form_page.dart`
  - `flutter_app/lib/features/sales/presentation/pages/b2b_invoice_form_page.dart`
  - `flutter_app/lib/features/sales/presentation/pages/sales_returns_page.dart`
- POS is not yet the desktop reference pattern
- Purchases, Accounts, HR, and Reports are more mixed and not yet standardized on the same workbench pattern

## 3. Go backend structure and boundaries

Verified structure:
- app startup: `go_backend_rmt/cmd/server/main.go`
- route composition: `go_backend_rmt/internal/routes/routes.go`
- domain packages: `internal/handlers`, `internal/services`, `internal/models`, `internal/utils`
- DB and migration startup: `internal/database/*`
- config and production-readiness checks: `internal/config/config.go`

Observed pattern:
- the backend is a modular monolith
- boundaries are package-based, not service-isolated
- OpenAPI lives at `go_backend_rmt/openapi.yaml`

Critical backend observations:
- Redis is a real runtime dependency for readiness checks, rate limiting, and session throttling
- runtime schema tolerance still exists in some request paths
- several hot endpoints show query fan-out or N+1 behavior
- finance outbox processing remains retryable but still synchronous on write paths

## 4. PostgreSQL and migration posture

Verified:
- executable migrations live under `go_backend_rmt/migrations`
- legacy/note migrations also exist under `go_backend_rmt/Docs & Schema/migrations`
- startup applies migrations by default when `RUN_MIGRATIONS=true`

Current concerns:
- base migration contains duplicate DDL blocks
- shallow schema validation means some drift can still survive until runtime
- at least one service (`purchase_return_service.go`) still probes `information_schema` during request handling
- ledger idempotency and finance outbox claims are not fully protected by DB-level uniqueness/locking

## 5. Redis usage and necessity

Verified uses:
- readiness endpoint: `go_backend_rmt/internal/routes/routes.go`
- rate limiting: `go_backend_rmt/internal/middleware/rate_limiter.go`
- session last-seen throttling: `go_backend_rmt/internal/middleware/session_last_seen_throttle.go`

Release interpretation:
- Redis is not optional for the intended production posture
- defaults still allow degraded or fail-open behavior unless production config tightens them

## 6. Web shell posture

Verified:
- `next_frontend_web/` contains a real route tree and service layer
- route-group coverage is tracked manually in `go_backend_rmt/internal/routes/FRONTEND_PARITY.md`
- the web README states automated tests are not configured

Governance conclusion:
- the repo is a three-surface system, but the current SMB release surface is still Flutter + Go only
- future milestones must track web ownership explicitly as enterprise-later work to avoid scope drift

## 7. Tooling and governance

Verified tooling:
- Flutter/OpenAPI parity: `tools/api_parity_check.py`
- backend/OpenAPI drift: `tools/openapi_route_drift_check.py`

Verified governance gaps before this run:
- `docs/inspection/` existed but was empty
- `.codex/config.toml` was missing from the worktree even though it was tracked
- some local agent files are empty placeholders
- several one-off prompt docs were competing with a single evolving workflow

## 8. Highest-signal technical observations

- The strongest current product direction is a Flutter-first SMB release with an enterprise-later web project, not a unified dual-frontend SMB release.
- Sales provides the best current document workflow reference, but only for deeper B2B create/list/return flows, not for every Sales page.
- Dashboard navigation is a routing hotspot because label-driven dispatch and direct page pushes are mixed.
- API parity for Flutter is currently strong, but unused backend/OpenAPI surface remains large and should stay explicitly classified.
- Release governance now needs to live under `docs/inspection/` to avoid re-discovery on future runs.
