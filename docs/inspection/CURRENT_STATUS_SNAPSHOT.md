# Current Status Snapshot

Timestamp: 2026-04-11 UTC (Supplier detail page + routing fix run)

## Summary

This run continued the existing `M1` plus `M2` workflow and implemented two slices: the supplier detail page responsive standardization (Option A) and the "Supplier Management" dashboard routing fix (Option B). `supplier_detail_page.dart` was refactored from a monolith with five nested `FutureBuilder` chains into a coordinated async load with separate desktop/mobile build paths. The inline `_PaySheet` was extracted to `widgets/supplier_payment_sheet.dart` as a clean reusable widget. Desktop now uses `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` for denser transaction review. Mobile reuses `SupplierReviewCard` from `supplier_workbench_widgets.dart` with `ProfessionalSectionCard` wrappers for transaction lists. The "Supplier Management" route was added to `dashboard_navigation.dart`, fixing the latent bug where label-based navigation to the supplier list would fail.

## Verified current state

- The repo is still effectively a three-surface system:
  - Flutter client
  - Go backend
  - enterprise-later `next_frontend_web` project
- Flutter/OpenAPI parity is still clean in the generated report.
- Sales deeper B2B document pages remain the best current reference, and the Sales post-save return review gap is materially smaller than the previous snapshot:
  - `InvoicesPage` remains a real B2B invoice workbench instead of a direct alias to the create form
  - the invoice workbench keeps desktop list/review behavior in place while mobile stays route-driven into full detail
  - `B2BInvoiceFormPage` supports a typed return result for callers that need workbench reload/select behavior
  - `SaleDetailPage` uses the shared document shell family for denser invoice review on desktop and stacked review on mobile
  - `quotes_page.dart` follows the same desktop workbench contract as the invoice and sales-history pages while keeping mobile route-driven
  - `quote_form_page.dart` supports a typed workflow result for quote callers that need reload/reselect behavior
  - `quote_detail_page.dart` uses the same shared quote review sections as the quote workbench and applies a denser desktop review shell
  - `sale_return_detail_page.dart` now follows the same denser responsive review contract family instead of falling back to a thin card-only detail page
  - `sales_returns_page.dart` now supports an optional typed workflow result while preserving its existing default post-save navigation
- Purchases remains stronger than the original baseline:
  - PO list/detail/create use denser desktop workbench patterns
  - GRN list/detail/create and PO receipt use the same document-shell family
  - standalone and PO-backed GRN posting return a typed workflow result that supports desktop workbench review and mobile detail routing when a real receipt id exists
  - purchase returns expose explicit source-purchase selection and a desktop split-pane preview
- Shared document primitives remain available from `flutter_app/lib/shared/widgets/professional_document_widgets.dart`, with the Sales feature file reduced to a re-export for continuity.
- Reports now uses those shared document primitives for desktop category/review framing instead of relying on card-grid plus generic stacked layouts:
  - `reports_page.dart` now uses `FeatureMenu` for the desktop category launcher while preserving the mobile grid
  - `report_category_page.dart` now provides a desktop report-picker workbench with a selected-report review pane while mobile remains stacked and route-driven
  - `report_viewer_page.dart` now provides a desktop filter/action rail plus result pane while preserving the mobile stacked filter-then-results flow
  - `flutter_app/lib/features/reports/presentation/widgets/report_workbench_widgets.dart` now carries the narrow shared report workbench primitives for panes and report-capability summaries
- Accounts now has deeper finance follow-up slices beyond the landing page:
  - `ledgers_page.dart` now provides a true desktop split workbench with persistent search/list context on the left and selected ledger review on the right
  - `ledger_entries_page.dart` now provides a stronger standalone desktop review shell with visible ledger context, filters, summaries, and linked business references while mobile remains stacked
  - `chart_of_accounts_page.dart` now provides a menu-aware desktop split workbench with searchable account selection on the left and selected-account hierarchy/review actions on the right while mobile remains stacked and dialog-driven
  - `vouchers_page.dart` now provides a desktop split workbench with a searchable voucher queue on the left and a pinned selected-voucher review pane on the right while mobile remains stacked with inline selected-voucher review
  - `flutter_app/lib/shared/widgets/workbench_pane.dart` now exists as a generic shared workbench shell and is first used by the Accounts ledger slice
  - `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` now provides the narrow Accounts-specific badge/review widgets plus reusable account title/status and voucher title/type/line helpers used by the ledger, chart, and voucher slices
- Customers now has a deeper workbench slice:
  - `customer_management_page.dart` now provides a desktop split workbench with a searchable customer queue on the left and a pinned selected-customer review pane on the right while mobile remains stacked with enhanced list cards and route-driven navigation
  - the review pane loads customer detail + summary via existing `getCustomer` + `getCustomerSummary` endpoints for profile metrics without a backend contract change
  - `flutter_app/lib/features/customers/presentation/widgets/customer_workbench_widgets.dart` now provides reusable customer type/status badges, credit chips, metric cards, and a comprehensive customer review card
- Suppliers now has a matching workbench slice:
  - `suppliers_page.dart` now provides a desktop split workbench with a searchable supplier queue on the left and a pinned selected-supplier review pane on the right while mobile remains stacked with enhanced list cards and route-driven navigation
  - the review pane loads supplier detail + summary via existing `getSupplier` + `getSupplierSummary` endpoints for profile metrics
  - `flutter_app/lib/features/suppliers/presentation/widgets/supplier_workbench_widgets.dart` now provides reusable supplier type/status badges, credit chips, metric cards, and a comprehensive supplier review card
  - outbox sync refresh was added (was missing in the original implementation)
  - client-side search filtering replaced the original server-side re-fetch-on-keystroke pattern
  - Supplier Balance Workbench button preserved in AppBar
- Shared Sales workbench primitives still exist in `flutter_app/lib/features/sales/presentation/widgets/sales_workbench_widgets.dart` and are reused by the Sales history page, the invoice workbench, and the quote workbench.
- Shared Sales review layers now exist for both quotes and sale returns:
  - `flutter_app/lib/features/sales/presentation/widgets/quote_review_widgets.dart`
  - `flutter_app/lib/features/sales/presentation/widgets/sale_return_review_widgets.dart`
- Dashboard quick action and label routing are slightly more aligned than before:
  - report category destinations are now built from `flutter_app/lib/features/reports/presentation/report_navigation.dart` instead of being redefined separately in multiple entry points
  - the `Chart of Accounts` dashboard route now passes the same optional menu-aware contract as the stronger Accounts finance pages
  - the existing `Vouchers` menu and dashboard routing contract stayed intact while the page body caught up to the newer Accounts workbench standard
  - the Customers module remains a FeatureMenu hub (not sidebar-integrated); this is preserved per architect-reviewer recommendation as a separate architectural change
  - route discoverability is still not complete across the app because the fallback `No route configured` branch still exists
- Redis remains a real runtime dependency for the intended production posture.
- Backend hardening, DB/performance work, and release/UAT evidence still remain open.

## What changed this run

- Refactored the customer detail page responsive standardization:
  - Extracted the inline `_CollectSheet` (~250 lines) to `widgets/customer_collection_sheet.dart` as a clean, reusable `CustomerCollectionSheet` widget
  - Replaced the six nested `FutureBuilder` chains with a single coordinated `Future.wait` load in `_reload()`, eliminating cascading loading spinners
  - Desktop: denser review layout using `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` for transaction rows
  - Mobile: reuses existing `CustomerReviewCard` from `customer_workbench_widgets.dart` for the main profile view, with `ProfessionalSummaryCard` for loyalty and `ProfessionalSectionCard` wrappers for transaction lists
  - Loyalty tier resolution collapsed from triple-nested `FutureBuilder` into a single guard with pre-resolved data
  - Added `DesktopSidebarToggleLeading` on wide screens and Refresh/Record Collection AppBar actions
  - Reduced from ~770 lines of monolith to ~566 lines (detail page) + ~412 lines (extracted collection sheet)
- Updated `docs/inspection/NEXT_RUN_PROMPT.md` with the next run options.
- Re-ran the available Flutter, parity, and format checks after implementation and confirmed they all pass.

## Verification executed in this run

Passed:
- `python3 tools/api_parity_check.py --out tools/api_parity_report.md`
- `flutter analyze`
- `flutter test`
- `dart format --set-exit-if-changed .` (on changed files)

Unverified in this environment:
- `go test ./...`
- `go vet ./...`
- `gofmt -l .`

Reason:
- `go` and `gofmt` were not installed on PATH in this session

## Verified blockers still open

- manual release-candidate UAT sign-off
- missing `ebs_lite_win/Requirements.txt`
- runtime schema tolerance in at least one backend request path
- dashboard routing still has a fallback `No route configured` branch for other labels not yet mapped (pre-existing; Supplier-specific issue now fixed)
- purchase return detail still remains a separate full-page review rather than fully matching the densest Sales review contract

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress
- `M2 Shared UI/layout standardization`: in progress
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Subagent note

Used in this run (mapped to `general-purpose` as fallback):
- `flutter-expert` → `general-purpose`: reviewed the supplier_detail_page.dart structure, recommended extracting the inline payment sheet, replacing nested FutureBuilders with coordinated load, using ProfessionalDocumentHeader/SectionCard/SummaryCard for desktop, and reusing SupplierReviewCard for mobile
- `architect-reviewer` → `general-purpose`: confirmed the "Supplier Management" route fix in dashboard_navigation.dart is safe and consistent with the existing routing pattern

Fallback mapping:
- `flutter-expert` → `general-purpose` (verified local agent not runnable in this environment)
- `architect-reviewer` → `general-purpose` (verified local agent not runnable in this environment)

Not used because no backend/API changes were required:
- `golang-pro`
- `sql-pro`
