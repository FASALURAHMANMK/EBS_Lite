# Next Run Prompt

Updated: 2026-04-11 UTC (post-M3-fourth-slice — password reset delivery hardened)

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
- M3 is in progress — 4 slices complete:
  - Runtime schema tolerance removed from service code (3 probes eliminated)
  - OpenAPI endpoint classification done (35 endpoints classified, 7 annotated with x-status)
  - Upload authorization hardened (files now require JWT auth + company ownership verification)
  - Password reset delivery hardened (STARTTLS, SMTP health check, FrontendBaseURL validation, session invalidation, strict rate limiting, configurable token expiry)
- Remaining M3 targets:
  - settings permission seeding review (P1: assumes fixed role IDs)
- Remaining P0:
  - missing `ebs_lite_win/Requirements.txt`
  - manual release-candidate UAT sign-off

### Objective (pick the strongest slice):

Option A: Settings permission seeding review (P1)
- Review how settings permissions are seeded in app code
- Remove fixed role ID assumptions
- Tie permission seeding to migration-backed role definitions
- This is the last remaining M3 P1 target

Option B: Evaluate M3 exit and transition to M4
- Assess whether the 4 completed M3 slices are sufficient for exit
- Begin M4 (DB/performance/release safety hardening): N+1 hotspots, outbox idempotency, DB migration hygiene

Pick Option A if the settings permission seeding issue is still a concern. Pick Option B if M3 is considered sufficiently hardened and the team wants to pivot to M4.

### Subagent requirements:
- Use golang-pro (or general-purpose fallback) for backend code review
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency
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
