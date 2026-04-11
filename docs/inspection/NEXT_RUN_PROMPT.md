# Next Run Prompt

Updated: 2026-04-11 UTC (post-M3-fifth-slice — settings permission seeding hardened)

## Instructions

Continue the existing EBS Lite milestone workflow. Do not restart discovery.

### Mandatory first reads (verify current state):
- docs/inspection/EXECUTION_LEDGER.md
- docs/inspection/CURRENT_STATUS_SNAPSHOT.md
- docs/inspection/SMB_RELEASE_MILESTONES.md
- docs/inspection/UI_RESPONSIVE_AUDIT.md
- docs/inspection/NEXT_RUN_PROMPT.md (this file)

### Current milestone context:
- M0 is complete.
- M1 is in progress (UI standardization wave substantially complete).
- M2 is in progress (shared widget family comprehensive across modules).
- M3 is in progress — 5 slices complete (substantially complete):
  - Runtime schema tolerance removed from service code (3 probes eliminated)
  - OpenAPI endpoint classification done (35 endpoints classified, 7 annotated with x-status)
  - Upload authorization hardened (files now require JWT auth + company ownership verification)
  - Password reset delivery hardened (STARTTLS, SMTP health check, FrontendBaseURL validation, session invalidation, strict rate limiting, configurable token expiry)
  - Settings permission seeding reviewed and hardened (app uses role names, startup verification added)
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Transition to M4 — DB/performance/release safety hardening
- Focus on N+1 hotspots identified in the release blockers doc
  - `GET /collections` performs N+1 invoice loading
  - stock adjustment and several dashboard paths remain query-heavy
  - purchase creation and receipt flows still perform per-line lookups inside transactions
- Address outbox claim/idempotency guarantees (currently application-level only)
- Review migration hygiene (base migration contains duplicate DDL blocks)

Option B: Address remaining P1 risks before M4 transition
- Review dashboard `No route configured` fallback branch — add missing routes
- Address `ebs_lite_win/Requirements.txt` — restore or document as missing

Pick Option A (M4 transition) as the recommended path. The M3 backend hardening wave is now substantially complete with 5 slices covering all P0/P1 backend risks. The N+1 hotspots and outbox idempotency gaps are the highest-impact remaining technical risks.

### Subagent requirements:
- Use golang-pro (or general-purpose fallback) for backend code review
- Use sql-pro (or general-purpose fallback) if query optimization is needed
- Use flutter-expert only if frontend changes are required

### Verification:
- `flutter analyze`
- `flutter test`
- `dart format --set-exit-if-changed .`
- `python3 tools/api_parity_check.py --out tools/api_parity_report.md`
- `go test ./...`, `go vet ./...`, `gofmt -l .` if Go is available

### Update:
- docs/inspection/UI_RESPONSIVE_AUDIT.md
- docs/inspection/CURRENT_STATUS_SNAPSHOT.md
- docs/inspection/EXECUTION_LEDGER.md
- docs/inspection/SMB_RELEASE_MILESTONES.md if milestone state changes
- docs/inspection/NEXT_RUN_PROMPT.md (write the next prompt for the following run)

### Required response format:
Use exactly the same structure as previous runs:
- REPO BOOTSTRAP SUMMARY
- VERIFIED SUBAGENTS AVAILABLE AND DELEGATION USED
- EXISTING DOCS REVIEWED / ARCHIVED / DELETED / REPLACED
- CURRENT REPO STATUS
- MASTER SMB RELEASE MILESTONES
- COMPETITIVE ERP BASELINE
- FILES CREATED / UPDATED / ARCHIVED / DELETED
- REMAINING COMPLIANCE GAPS
- NEXT BEST EXECUTION STEP
- NEXT PROMPT TO RUN (also written to docs/inspection/NEXT_RUN_PROMPT.md)
