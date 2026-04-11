# Current Status Snapshot

Timestamp: 2026-04-11 UTC (M3 third slice — upload authorization hardening)

## Summary

This run continued the M3 (backend/API hardening) phase by hardening upload authorization. The unauthenticated `router.Static("/uploads", cfg.UploadPath)` was replaced with a protected `GET /api/v1/uploads/:subdir/:filename` endpoint behind `RequireAuth()` middleware. A new `UploadHandler` verifies JWT authentication, restricts access to known subdirectories (`invoices`, `returns`, `logos`), prevents path traversal, and verifies file ownership against the requesting user's company_id before serving. On the Flutter side, a new `AuthImage` widget loads images through the authenticated Dio client instead of `NetworkImage`, and the company logo display was updated to use it. This closes the P1 risk that uploaded business files were served based on path secrecy alone.

## What changed this run

- Replaced unauthenticated `router.Static("/uploads", ...)` with protected `GET /api/v1/uploads/:subdir/:filename` behind `RequireAuth()`
- Created `internal/handlers/upload_handler.go` with `UploadHandler.ServeFile()` for authenticated, company-scoped file serving
- Created `lib/core/auth_image.dart` with `AuthImage` widget for authenticated image loading in Flutter
- Updated `company_logo.dart` and `company_settings_page.dart` to use `AuthImage` instead of `NetworkImage`
- Re-ran the available Flutter, parity, and format checks after implementation and confirmed they all pass.

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress (UI standardization wave substantially complete)
- `M2 Shared UI/layout standardization`: in progress
- `M3 Backend/API hardening`: in progress (3 slices complete — runtime schema tolerance removed, OpenAPI endpoint classification done, upload authorization hardened)
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Verification executed in this run

Passed:
- `flutter analyze`
- `flutter test`
- `python3 tools/api_parity_check.py --out tools/api_parity_report.md`

Unverified in this environment:
- `go test ./...`, `go vet ./...`, `gofmt -l .` (Go toolchain unavailable)

## Verified blockers still open

- manual release-candidate UAT sign-off
- missing `ebs_lite_win/Requirements.txt`
- upload authorization — **resolved in this run**; files now require JWT authentication and company-level ownership verification
- password reset delivery (P1: production-readiness checks do not verify SMTP posture)
- settings permission seeding assumes fixed role IDs (P1)
- dashboard routing still has a fallback `No route configured` branch for other unmapped labels (pre-existing)

## Subagent note

Used in this run (mapped to `general-purpose` as fallback):
- general-purpose (backend exploration): explored upload architecture — identified 3 upload endpoints, file storage structure, company linkage, and the security gap in `router.Static("/uploads", ...)`

Not used because no database changes were required and golang-pro was not runnable:
- `golang-pro`
- `sql-pro`

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

- Hardened the purchase return detail page:
  - Added proper error state handling with `AppErrorView` + retry (previously `_loading` stayed true forever on error)
  - Added `RefreshIndicator` on mobile ListView for pull-to-refresh
  - Added Refresh AppBar action
  - Denser desktop items display — replaced individual `ProfessionalOverviewCard` per item with compact DataTable-style rows showing line number, product name, quantity, unit price, and line total
  - Mobile retains the `ProfessionalOverviewCard` per item pattern (appropriate for touch)
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
- runtime schema tolerance in service code — **resolved in this run**; remaining schema tolerance exists only in migrations (acceptable) and `schema_validation.go` startup check (acceptable)
- dashboard routing still has a fallback `No route configured` branch for other unmapped labels (pre-existing)
- upload authorization (P1: files served from `/uploads` rely on path secrecy)
- password reset delivery (P1: production-readiness checks do not verify SMTP posture)

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress (UI standardization wave substantially complete)
- `M2 Shared UI/layout standardization`: in progress
- `M3 Backend/API hardening`: in progress (first slice complete — runtime schema tolerance removed)
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Subagent note

Not used in this run — the runtime schema tolerance probes were straightforward to identify and fix. All three `information_schema` queries were in service code (not migrations), and the columns they probed for were confirmed to exist in the init schema migrations.
