# Next Run Prompt

Updated: 2026-04-11 UTC (post-dashboard route gap fix)

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
- M1 is in progress (UI standardization wave substantially complete; dashboard routing gap substantially reduced).
- M2 is in progress (shared widget family comprehensive across modules).
- M3 is substantially complete (5 slices covering all P0/P1 backend risks).
- M4 is in progress — 3 slices complete:
  - N+1 hotspots fixed in collection service (`GetCollections`, `GetOutstanding`)
  - Outbox idempotency hardened (client-side duplicate detection + unique index + backend unique constraints)
  - Migration hygiene cleaned (zero duplicate DDL in base migration)
- Remaining targets:
  - Evaluate M3/M4 exit readiness
  - Consider M5 transition (validation, permissions, and security posture)
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Evaluate M3/M4 exit readiness and plan M5
- Assess whether the 5 M3 slices and 3 M4 slices are sufficient for exit
- Document the current state and plan M5 (validation, permissions, and security posture)

Option B: Continue with remaining M4 targets
- Any remaining N+1 hotspots discovered through profiling
- Outbox claim race verification edge cases
- Dashboard route gap further reduction

Pick Option A (M3/M4 exit evaluation) as the recommended path. The M3 and M4 workstreams have accumulated substantial evidence of completion across 8 slices. It's time to evaluate exit readiness and plan the next phase.

### Subagent requirements:
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency review
- Use golang-pro (or general-purpose fallback) for backend code review if needed
- Use flutter-expert (or general-purpose fallback) for Flutter review if needed

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
