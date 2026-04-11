# Next Run Prompt

Updated: 2026-04-11 UTC (post-Suppliers run)

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
- M1 is in progress.
- M2 is in progress.
- The Customer Management workbench slice is implemented.
- The Supplier Management workbench slice is implemented.
- Both customer_detail_page.dart (770 lines) and supplier_detail_page.dart remain as follow-up targets for desktop responsive upgrade.
- The "Supplier Management" route is missing from dashboard_navigation.dart (architect flag: latent bug).

### Objective (pick the strongest slice):

Option A: `customer_detail_page.dart` desktop responsive standardization
- Upgrade the 770-line monolith to use denser responsive review patterns on desktop while keeping mobile stacked
- Extract the inline collection sheet to a separate widget file
- Use the existing customer_workbench_widgets.dart badges

Option B: `supplier_detail_page.dart` desktop responsive standardization
- Upgrade to denser responsive review patterns on desktop while keeping mobile stacked
- Extract the inline `_PaySheet` to `supplier_payment_sheet.dart`
- Use the existing supplier_workbench_widgets.dart badges

Pick whichever is strongest. Option A is slightly higher priority because the customer detail page is larger (770 lines vs ~500 lines) and has more complexity (loyalty resolution, collection sheet with invoice allocation).

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
