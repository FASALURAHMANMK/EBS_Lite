# Next Run Prompt

Updated: 2026-04-11 UTC (post-M5-first-slice — settings/admin permission flow hardened)

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
- M1 is ready for exit (UI standardization wave complete; dashboard routing gap substantially reduced).
- M2 is ready for exit (shared widget family comprehensive across modules).
- M3 is ready for exit (5 slices covering all P0/P1 backend risks).
- M4 is ready for exit (3 slices covering highest-impact DB/performance risks).
- M5 is in progress — first slice complete (settings/admin permission flow reviewed and hardened).
- Remaining M5 targets:
  - verify release config guidance against actual code paths

### Objective (pick the strongest M5 slice):

Option A: Release config guidance verification
- Verify that RELEASE_READINESS_PLAN.md and config guidance match actual code paths
- Update docs where they diverge from implementation
- Ensure production config gates are properly documented

Option B: Evaluate M5 exit readiness
- Assess whether the 2 M5 slices (settings permission flow + config guidance verification) are sufficient for exit
- Document M5 exit assessment

Pick Option A (release config guidance verification) as the recommended path. This is the remaining M5 scope item that hasn't been covered yet.

### Subagent requirements:
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency
- Use golang-pro (or general-purpose fallback) for backend code review if needed

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
