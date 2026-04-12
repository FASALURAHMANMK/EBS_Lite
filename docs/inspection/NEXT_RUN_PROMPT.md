# Next Run Prompt

Updated: 2026-04-12 UTC (M6 UAT test plan created and validated — awaiting manual execution)

## Instructions

Continue the existing EBS Lite milestone workflow. Do not restart discovery.

### Mandatory first reads (verify current state):
- docs/inspection/EXECUTION_LEDGER.md
- docs/inspection/CURRENT_STATUS_SNAPSHOT.md
- docs/inspection/SMB_RELEASE_MILESTONES.md
- docs/inspection/UI_RESPONSIVE_AUDIT.md
- docs/inspection/M6_UAT_TEST_PLAN.md
- docs/inspection/NEXT_RUN_PROMPT.md (this file)

### Current milestone context:
- M0-M5 are all formally **completed**.
- M6 (QA/UAT) is **in progress** — test plan created with 59 scenarios (22 P0, 32 P1, 5 P2), validated against ERP requirements.
- M7 (Deployment) is blocked pending M6 completion.
- All automated quality gates pass:
  - Flutter: analyze (0 errors), test (15/15 pass), format (0 changes)
  - API parity: zero missing paths, zero method mismatches
  - Go backend: 42 test files covering ledger posting, idempotency, vouchers, auth, uploads, workflow
- Remaining blockers:
  - Manual UAT execution against governed demo dataset (M6 phase 2)
  - Missing `ebs_lite_win/Requirements.txt` (P0)

### Objective (pick the strongest remaining work):

Option A: Release candidate documentation package (Option B from previous run)
- Assemble RELEASE_NOTES.md with all M1-M5 changes
- Ensure RELEASE_READINESS_PLAN.md gates are documented as satisfied (except UAT)
- Cross-reference all release artifacts
- Prepare operator launch package (SOPs, quick-reference guides per role)

Option B: UAT execution support automation
- Create automated demo dataset reset verification script
- Create automated evidence collection template (screenshot naming convention, report export paths)
- Create automated UAT results tracker (spreadsheet or markdown)

Option C: Flutter test suite expansion (long-term quality investment)
- Add integration tests for top 3 P0 UAT scenarios (FIN-01 POS cash sale, AUTH-01 login, OFF-01 offline sync)
- Establish shared test fixture pattern with mock repositories

Pick Option A (release candidate documentation package) as the recommended path. This prepares the full release artifact set while M6 manual UAT is being executed by humans, keeping the pipeline moving.

### Subagent requirements:
- Use general-purpose agent to review existing release documentation and identify gaps in the operator launch package

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
