# Current Status Snapshot

Timestamp: 2026-04-11 UTC

## Summary

This run continued the existing `M1` plus `M2` workflow and implemented the next highest-priority customer slice after the Accounts vouchers rollout: the Customer Management desktop workbench/detail-review standardization. `customer_management_page.dart` now follows the Accounts workbench contract on desktop with a searchable customer queue, pinned selected-customer review pane, and detail loading through the existing `getCustomer` + `getCustomerSummary` endpoints, while mobile stays stacked with enhanced list cards (now including type badges) and route-driven navigation to `CustomerDetailPage`. The slice also created `customer_workbench_widgets.dart` with reusable customer type/status badges, metric cards, credit chips, and a comprehensive customer review card. Subagent delegation used `general-purpose` as the fallback mapping for `flutter-expert` and `architect-reviewer` since the verified local agent definitions are not runnable in this ChatGPT-backed Codex account.

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

- Standardized the next deeper Customer slice after the Accounts vouchers rollout:
  - `customer_management_page.dart` now has a desktop split workbench with a searchable customer queue on the left and a persistent selected-customer review pane on the right, while mobile stays stacked with enhanced list cards (now including type badges) and route-driven detail navigation
  - the review pane loads the existing `getCustomer` + `getCustomerSummary` endpoints so the workbench can show contact details, financial terms, business summary metrics, and credit status without a backend/API contract change
  - `_syncDesktopSelection` auto-selects the first customer on desktop and re-syncs when the filtered queue changes
  - outbox sync refresh behavior is preserved and extended to refresh the selected-customer review pane on desktop
  - Quick Collection shortcut remains available on mobile via `showQuickCollectionSheet`
- Created `flutter_app/lib/features/customers/presentation/widgets/customer_workbench_widgets.dart` with reusable customer type badge, customer status badge, customer credit chip, customer metric card, and customer review card for the Customer Management slice.
- Re-ran the available Flutter, parity, and format checks after implementation and confirmed they all pass.
- Attempted Go quality gates and confirmed the Go toolchain is still unavailable in this environment.

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
- dashboard routing still has a fallback `No route configured` branch for labels not yet mapped centrally
- supplier document-heavy workbenches are now the clearest next `M1` plus `M2` rollout target after the Customer Management slice
- customer_detail_page.dart remains a 770-line monolith without desktop responsive adaptation (flagged as follow-up by architect-reviewer)
- purchase return detail still remains a separate full-page review rather than fully matching the densest Sales review contract

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress
- `M2 Shared UI/layout standardization`: in progress
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Subagent note

Used in this run (mapped to `general-purpose` as fallback):
- `flutter-expert` → `general-purpose`: reviewed the remaining Customer candidates, confirmed Customer Management as the strongest next slice after Accounts Vouchers, and recommended a desktop customer queue plus pinned review pane using existing getCustomer + getCustomerSummary endpoints for profile/metrics review
- `architect-reviewer` → `general-purpose`: reviewed cross-module layout and routing consistency, confirmed the existing Customer routing/menu contract (FeatureMenu hub, not sidebar) should be preserved in this slice, flagged customer_detail_page.dart as a follow-up (770-line monolith), and recommended keeping the workbench change inside customer_management_page.dart without changing routes or labels

Fallback mapping:
- `flutter-expert` → `general-purpose` (verified local agent not runnable in this ChatGPT-backed Codex account)
- `architect-reviewer` → `general-purpose` (verified local agent not runnable in this ChatGPT-backed Codex account)

Not used because backend/API/data changes were not required by the chosen implementation:
- `golang-pro`
- `sql-pro`
