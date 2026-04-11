# Next Run Prompt

Updated: 2026-04-11 UTC (post-M4-third-slice — migration hygiene cleaned)

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
- M4 is in progress — 3 slices complete:
  - N+1 hotspots fixed in collection service (`GetCollections`, `GetOutstanding`)
  - Outbox idempotency hardened (client-side duplicate detection + unique index + backend unique constraints)
  - Migration hygiene cleaned (zero duplicate DDL in base migration)
- Remaining targets:
  - dashboard `No route configured` fallback — add missing routes
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Dashboard route gap fix (M1/M4)
- Add missing routes to `dashboard_navigation.dart` to eliminate the `No route configured` fallback
- This is a quick fix that improves the user experience

Option B: Evaluate M4 exit readiness and plan M5
- Assess whether the 3 completed M4 slices are sufficient for exit
- Begin M5 (validation, permissions, and security posture)

Pick Option A (dashboard route gap fix) as the recommended path. It's a quick win that eliminates the `No route configured` fallback for additional routes, improving the user experience and addressing a pre-existing gap.

### Subagent requirements:
- Use flutter-expert (or general-purpose fallback) for implementation review
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency
- Use golang-pro and sql-pro only if backend/API changes are required

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
