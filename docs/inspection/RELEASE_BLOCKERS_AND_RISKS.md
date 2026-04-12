# Release Blockers And Risks

Updated: 2026-04-11 UTC

## P0 blockers

- Manual release-candidate UAT sign-off is still incomplete.
- `ebs_lite_win/Requirements.txt` is referenced by repo guidance but is absent from the repo.
- ~~Runtime schema drift is still tolerated in request code~~ — **resolved** (M3 slice 1)
- ~~The dashboard navigation layer still contains a live `No route configured` fallback path~~ — **substantially reduced** (19 new routes added, 3 placeholders for not-yet-implemented features)

## P1 high-priority risks

- ~~Settings permission seeding happens in app code and assumes fixed role IDs~~ — **resolved** (M3 slice 5: app uses role names, startup verification added)
- ~~Uploaded business files are served from `/uploads` and rely on path secrecy rather than explicit authorization~~ — **resolved** (M3 slice 3: JWT auth + company ownership verification)
- ~~Password reset depends on real frontend URL plus SMTP delivery, but production-readiness checks do not verify SMTP posture~~ — **resolved** (M3 slice 4: STARTTLS, SMTP health check, FrontendBaseURL validation)
- ~~Flutter/API parity is good, but backend/OpenAPI surface still exceeds the shipped Flutter surface materially~~ — **resolved** (M3 slice 2: 35 endpoints classified, 7 annotated)
- `next_frontend_web/` remains manually governed and has no verified automated test baseline; it should stay outside SMB release scope.
- ~~POS is not yet the desktop/workbench reference despite being a core launch workflow~~ — **accepted as-is** for Phase 1 (POS has different UX requirements; desktop treatment planned for later)
- ~~Purchases document flows lag behind the Sales reference pattern~~ — **resolved** (M1/M2 standardization complete)

## P2 structural and performance debt

- ~~`GET /collections` performs N+1 invoice loading~~ — **resolved** (M4 slice 1)
- ~~stock adjustment and several dashboard paths remain query-heavy~~ — **accepted** for Phase 1 (further optimization should be profiling-driven)
- ~~purchase creation and receipt flows still perform per-line lookups inside transactions~~ — **accepted** for Phase 1 (not a hot path at SMB scale)
- ~~finance outbox claims and ledger idempotency rely too much on application-level safeguards~~ — **resolved** (M4 slice 2: client-side duplicate detection + unique index + backend unique constraints)
- ~~base migration hygiene is weak because duplicate DDL blocks still exist~~ — **resolved** (M4 slice 3: zero duplicate DDL remaining)
- Flutter feature architecture is only partially aligned with the repo's `data/domain/presentation` target.

## Release interpretation

Current state:
- M0 (repo bootstrap): completed
- M1 (responsive/document workflow): ready for exit
- M2 (shared UI/layout standardization): ready for exit
- M3 (backend/API hardening): ready for exit (5 slices complete)
- M4 (DB/performance/release safety): ready for exit (3 slices complete)
- M5 (validation/permissions/security): in progress (first slice complete — settings/admin permission flow hardened)
- the product is not ready for a final release claim without UAT closure and M5 exit
