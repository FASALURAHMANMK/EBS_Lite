# Next Run Prompt

Updated: 2026-04-11 UTC (post-M3/M4 exit evaluation — M1, M2, M3, M4 ready for exit)

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
- M5 is pending — validation, permissions, and security posture.

### M5 Scope (from SMB_RELEASE_MILESTONES.md):
- tighten upload confidentiality (already addressed in M3)
- verify password reset deliverability and production-readiness checks (already addressed in M3)
- review permission-sensitive settings/admin flows
- verify release config guidance against actual code paths

### Objective (pick the strongest M5 slice):

Option A: Settings/admin permission flow review
- Review settings_page.dart and admin pages for proper permission checks
- Verify that sensitive admin operations require appropriate permissions
- Ensure role-based access control is enforced on settings endpoints

Option B: Release config guidance verification
- Verify that RELEASE_READINESS_PLAN.md and config guidance match actual code paths
- Update docs where they diverge from implementation
- Ensure production config gates are properly documented

Option C: M3/M4 formal exit documentation
- Formally mark M3 and M4 as completed in the milestone docs
- Prepare the M5 kickoff document

Pick Option A (settings/admin permission flow review) as the recommended path. This addresses the remaining M5 scope item that hasn't been covered yet.

### Subagent requirements:
- Use flutter-expert (or general-purpose fallback) for Flutter permission flow review
- Use golang-pro (or general-purpose fallback) for backend permission enforcement review
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
