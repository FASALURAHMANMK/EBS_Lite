# Release Blockers And Risks

Updated: 2026-04-09 UTC

## P0 blockers

- Manual release-candidate UAT sign-off is still incomplete.
- `ebs_lite_win/Requirements.txt` is referenced by repo guidance but is absent from the repo.
- Runtime schema drift is still tolerated in request code in `go_backend_rmt/internal/services/purchase_return_service.go`.
- The dashboard navigation layer still contains a live `No route configured` fallback path in `flutter_app/lib/features/dashboard/presentation/dashboard_navigation.dart`.

## P1 high-priority risks

- Settings permission seeding happens in app code and assumes fixed role IDs.
- Uploaded business files are served from `/uploads` and rely on path secrecy rather than explicit authorization.
- Password reset depends on real frontend URL plus SMTP delivery, but production-readiness checks do not verify SMTP posture.
- Flutter/API parity is good, but backend/OpenAPI surface still exceeds the shipped Flutter surface materially.
- `next_frontend_web/` remains manually governed and has no verified automated test baseline; it should stay outside SMB release scope.
- POS is not yet the desktop/workbench reference despite being a core launch workflow.
- Purchases document flows lag behind the Sales reference pattern.

## P2 structural and performance debt

- `GET /collections` performs N+1 invoice loading.
- stock adjustment and several dashboard paths remain query-heavy.
- purchase creation and receipt flows still perform per-line lookups inside transactions.
- finance outbox claims and ledger idempotency rely too much on application-level safeguards.
- base migration hygiene is weak because duplicate DDL blocks still exist.
- Flutter feature architecture is only partially aligned with the repo’s `data/domain/presentation` target.

## Release interpretation

Current state:
- the repo now has a continuity baseline
- the release-governance workflow is stronger than before this run
- the product is not ready for a final release claim without targeted implementation and UAT closure
