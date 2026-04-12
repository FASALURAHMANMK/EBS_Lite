# Next Run Prompt

Updated: 2026-04-11 UTC (post-M5 exit evaluation — M1, M2, M3, M4, M5 all ready for exit)

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
- M5 is ready for exit (2 slices covering validation, permissions, and security posture).
- All M1-M5 milestones are now ready for exit.
- Remaining blockers:
  - M6 (QA/UAT): blocked pending manual release-candidate UAT sign-off
  - M7 (Deployment): blocked pending M6 completion
  - P0: missing `ebs_lite_win/Requirements.txt`
  - P0: manual release-candidate UAT sign-off

### Objective (pick the strongest remaining work):

Option A: Formally mark M1-M5 as completed
- Update SMB_RELEASE_MILESTONES.md to change M1-M5 status from "ready for exit" to "completed"
- Update CURRENT_STATUS_SNAPSHOT.md to reflect all implementation milestones complete
- Prepare release candidate documentation summary

Option B: Release candidate package preparation
- Ensure all release documentation is current and cross-referenced
- Verify RELEASE_READINESS_PLAN.md gates are satisfied (except UAT)
- Prepare release notes template

Option C: Import/Export permission hardening (optional)
- Add backend permission checks for bulk import/export endpoints
- Add Flutter-side permission checks for Import/Export page

Pick Option A (formally mark M1-M5 as completed) as the recommended path. This is the final implementation milestone before the M6/UAT phase.

### Subagent requirements:
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency review

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
