# Next Run Prompt

Updated: 2026-04-11 UTC (post-supplier-detail + routing fix run)

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
- The Customer detail page responsive slice is implemented.
- The Supplier detail page responsive slice is implemented.
- The "Supplier Management" dashboard routing fix is implemented.
- Both customer/supplier standardization waves are complete (management + detail pages).
- Remaining M1/M2 targets:
  - purchase_return_detail_page desktop standardization (from Purchases residual refinements)
  - residual Sales caller-owned return-workbench adoption (if a dedicated returns workbench or routing contradiction surfaces)
  - the `No route configured` fallback branch still exists for other unmapped labels

### Objective (pick the strongest slice):

Option A: `purchase_return_detail_page.dart` desktop responsive standardization
- Upgrade the purchase return detail page to denser responsive review patterns on desktop while keeping mobile stacked
- Use the existing Purchases document widgets and professional_document_widgets
- Mirror the pattern used in customer_detail_page.dart and supplier_detail_page.dart (coordinated async load, ProfessionalDocumentHeader on desktop)

Option B: Pivot toward M3 (backend/API hardening) if UI standardization is considered sufficient
- Focus on runtime schema tolerance removal in purchase_return_service.go
- Classify unused OpenAPI endpoints
- Review auth/settings/bootstrap posture

Pick whichever is strongest. Option A continues the M1/M2 UI standardization wave. Option B starts the M3 backend hardening phase.

### Subagent requirements:
- Use flutter-expert (or general-purpose fallback) for implementation review
- Use architect-reviewer (or general-purpose fallback) for cross-module consistency
- Use golang-pro and sql-pro if backend/API changes are required (Option B)

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
