# Next Run Prompt

Updated: 2026-04-11 UTC (post-purchase-return-detail hardening run)

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
- M1 is in progress — UI standardization wave substantially complete:
  - Sales: invoices, quotes, sale returns, sales history all standardized
  - Purchases: PO, GRN, receipt, returns, purchase return detail all standardized
  - Accounts: ledgers, chart of accounts, vouchers all standardized
  - Customers: management workbench + detail page standardized
  - Suppliers: management workbench + detail page standardized + "Supplier Management" route fixed
  - Reports: category viewer + report viewer standardized
  - purchase_return_detail_page was the last remaining detail-page target — now hardened
- M2 is in progress — shared widget family comprehensive across modules
- Remaining M1/M2 residual gaps:
  - `No route configured` fallback branch still exists for other unmapped labels
  - POS desktop treatment still light
  - residual Sales caller-owned return-workbench adoption (low priority, no contradiction surfaced)
- M3 (backend/API hardening) has not been started

### Objective (pick the strongest slice):

Option A: Transition to M3 — Backend/API hardening
- Fix runtime schema tolerance in `go_backend_rmt/internal/services/purchase_return_service.go`
- Classify unused OpenAPI endpoints (internal, future, or uncommercialized)
- Review auth/settings/bootstrap posture
- This is the highest-impact path toward a release-ready backend

Option B: Address residual UI gaps
- Add "Suppliers" or other missing routes to dashboard_navigation.dart
- POS desktop payment path treatment
- Both are lower priority than M3 given the UI standardization wave is complete

Pick Option A (M3 transition) as the recommended path. The M1/M2 UI standardization wave has been running for multiple runs and is now substantially complete across all major modules. The P0 runtime schema tolerance in purchase_return_service.go should be the first M3 target.

### Subagent requirements:
- Use golang-pro (or general-purpose fallback) for backend code review
- Use sql-pro (or general-purpose fallback) if query/schema changes are needed
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
