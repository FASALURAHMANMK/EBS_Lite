# Next Run Prompt

Updated: 2026-04-11 UTC (post-M3-first-slice — runtime schema tolerance removed)

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
- M3 is in progress — first slice complete:
  - Runtime schema tolerance removed from service code (3 probes eliminated)
  - Remaining M3 targets: classify unused OpenAPI endpoints, review auth/settings/bootstrap posture
- Remaining P1 risks:
  - upload authorization (files served from `/uploads` rely on path secrecy)
  - password reset delivery (production-readiness checks do not verify SMTP posture)
  - settings permission seeding assumes fixed role IDs

### Objective (pick the strongest slice):

Option A: Classify unused OpenAPI endpoints
- Review the 35+ unused OpenAPI paths in the current parity report
- Tag each as: internal, future/uncommercialized, or candidate for removal
- Update openapi.yaml with x-internal or x-status annotations where applicable

Option B: Upload authorization hardening (P1)
- Review how `/uploads` serves files
- Add authorization checks so files are not served based on path secrecy alone
- Tie file access to user/company context

Option C: Password reset delivery hardening (P1)
- Review the password reset flow end-to-end
- Add production SMTP posture checks to the readiness endpoint
- Verify the real frontend URL is configured and usable

Pick Option A (OpenAPI classification) as the recommended path. It's the most systematic M3 target and addresses a key exit criterion: "unused endpoints are classified as internal, future, or uncommercialized."

### Subagent requirements:
- Use golang-pro (or general-purpose fallback) for backend/OpenAPI review
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
