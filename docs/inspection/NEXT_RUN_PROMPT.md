# Next Run Prompt

Updated: 2026-04-12 UTC (M1-M5 formally completed — ready for M6/UAT phase)

## Instructions

Continue the existing EBS Lite milestone workflow. Do not restart discovery.

### Mandatory first reads (verify current state):
- docs/inspection/EXECUTION_LEDGER.md
- docs/inspection/CURRENT_STATUS_SNAPSHOT.md
- docs/inspection/SMB_RELEASE_MILESTONES.md
- docs/inspection/UI_RESPONSIVE_AUDIT.md
- docs/inspection/NEXT_RUN_PROMPT.md (this file)

### Current milestone context:
- M0-M5 are all formally **completed**.
- M6 (QA/UAT) is the next active milestone — currently blocked pending manual release-candidate UAT sign-off.
- M7 (Deployment) is blocked pending M6 completion.
- All automated quality gates pass:
  - Flutter: analyze (0 errors), test (15/15 pass), format (0 changes)
  - API parity: zero missing paths, zero method mismatches
- Remaining blockers:
  - Manual release-candidate UAT sign-off (M6)
  - Missing `ebs_lite_win/Requirements.txt` (P0)
  - Go quality gates unverifiable in this environment (toolchain unavailable)

### Objective (pick the strongest remaining work):

Option A: M6 UAT test-plan preparation
- Create a structured UAT test plan covering all P0/P1 user journeys
- Define pass/fail criteria and evidence requirements for M6 exit
- Map test cases to existing Flutter test suite gaps

Option B: Release candidate documentation package
- Assemble RELEASE_NOTES.md with all M1-M5 changes
- Ensure RELEASE_READINESS_PLAN.md gates are documented as satisfied (except UAT)
- Cross-reference all release artifacts

Option C: Minor polish — consolidate Sales-local professional_document_widgets.dart
- Replace the Sales-local copy import in sales_returns_page.dart with the shared version
- Verify no behavioral change

Pick Option A (M6 UAT test-plan preparation) as the recommended path. This unblocks the M6 milestone with a concrete, executable test plan rather than waiting passively.

### Subagent requirements:
- Use architect-reviewer (or general-purpose fallback) to validate UAT test-plan coverage against the ERP requirements document

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
