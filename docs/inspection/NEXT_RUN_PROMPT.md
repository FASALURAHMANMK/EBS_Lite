# Next Run Prompt

Updated: 2026-04-11 UTC (post-M4-second-slice — outbox idempotency hardened)

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
- M4 is in progress — 2 slices complete:
  - N+1 hotspots fixed in collection service (`GetCollections`, `GetOutstanding`)
  - Outbox idempotency hardened (client-side duplicate detection + unique index + backend unique constraints)
- Remaining M4 targets:
  - migration hygiene review (base migration contains duplicate DDL blocks)
  - dashboard `No route configured` fallback — add missing routes
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Migration hygiene review (M4)
- Review the base migration (`202601010000_init_schema.sql`) for duplicate DDL blocks
- Clean up redundant schema statements
- Ensure all migrations are idempotent and non-conflicting

Option B: Dashboard route gap fix (M1/M4)
- Add missing routes to `dashboard_navigation.dart` to eliminate the `No route configured` fallback
- This is a quick fix that improves the user experience

Pick Option A (migration hygiene) as the recommended path. The base migration is the foundation of the database and ensuring it's clean is important for production deployments.

### Subagent requirements:
- Use sql-pro (or general-purpose fallback) for migration/schema review
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
