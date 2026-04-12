# Next Run Prompt

Updated: 2026-04-11 UTC (post-M5-second-slice — release config guidance verified)

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
- M5 is in progress — second slice complete (release config guidance verified and RELEASE_BLOCKERS_AND_RISKS.md updated).
- Remaining M5 targets:
  - evaluate M5 exit readiness (settings/admin permission flow + release config guidance)

### Objective (pick the strongest M5 slice):

Option A: M5 exit evaluation and documentation
- Assess whether the 2 M5 slices are sufficient for exit
- Document M5 exit assessment in EXECUTION_LEDGER.md and CURRENT_STATUS_SNAPSHOT.md
- Update SMB_RELEASE_MILESTONES.md M5 status accordingly

Option B: Further M5 hardening
- Import/Export page permission check (no backend permission enforcement for bulk import/export)
- Additional permission-sensitive settings review

Pick Option A (M5 exit evaluation) as the recommended path. The 2 completed M5 slices cover the core M5 scope items: settings/admin permission flow reviewed and release config guidance verified. Further hardening (Import/Export permissions) can be tracked as M5 follow-up or deferred to M6.

### Subagent requirements:
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency

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
