# Next Run Prompt

Updated: 2026-04-11 UTC (post-M4-first-slice — N+1 hotspots fixed)

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
- M3 is substantially complete (5 slices covering all P0/P1 backend risks).
- M4 is in progress — first slice complete:
  - N+1 hotspots fixed in collection service (`GetCollections`, `GetOutstanding`)
- Remaining M4 targets:
  - outbox claim/idempotency guarantees (currently application-level only)
  - migration hygiene review (base migration contains duplicate DDL blocks)
  - dashboard `No route configured` fallback — add missing routes
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Outbox claim/idempotency review (M4)
- Review the current outbox implementation in `flutter_app/lib/core/outbox/`
- Verify that idempotency keys are properly used end-to-end
- Identify any claim races where the same operation could be replayed
- Add DB-level uniqueness constraints if missing

Option B: Dashboard route gap fix (M1/M4)
- Add missing routes to `dashboard_navigation.dart` to eliminate the `No route configured` fallback
- This is a quick fix that improves the user experience

Option C: Migration hygiene review (M4)
- Review the base migration for duplicate DDL blocks
- Clean up redundant schema statements

Pick Option A (outbox idempotency) as the recommended path. The offline-first claims are a core differentiator for EBS Lite vs browser-first competitors, and ensuring they are robust is the highest-impact remaining M4 target.

### Subagent requirements:
- Use golang-pro (or general-purpose fallback) for backend code review
- Use flutter-expert (or general-purpose fallback) for Flutter outbox review
- Use sql-pro (or general-purpose fallback) if DB constraint changes are needed

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
