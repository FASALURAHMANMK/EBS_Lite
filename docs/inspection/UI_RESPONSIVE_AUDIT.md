# UI Responsive Audit

Updated: 2026-04-11 UTC (Supplier detail page + routing fix run)
Audit mode: static repo inspection plus subagent-assisted Flutter audit
Runtime device testing: not performed in this run

## 1. Verified global patterns

- The app shell has a real mobile vs wide-screen split in `flutter_app/lib/features/dashboard/presentation/dashboard_screen.dart`.
- Breakpoint logic is centralized but minimal in `flutter_app/lib/core/layout/app_breakpoints.dart`.
- Module landing pages are inconsistent:
  - newer pattern: `flutter_app/lib/shared/widgets/feature_menu.dart`
  - older pattern: `flutter_app/lib/shared/widgets/feature_grid.dart`
- Routing is fragmented between label-based dispatch and direct page pushes in `flutter_app/lib/features/dashboard/presentation/dashboard_navigation.dart` and module widgets.
- Reports entry routing is more centralized than before because report category destinations now flow through `flutter_app/lib/features/reports/presentation/report_navigation.dart` and are reused by both dashboard routing and module launchers.
- Sales label routing is slightly less fragmented than before because `dashboard_navigation.dart` now resolves invoice, quote, and sale-history labels directly.

## 2. Module audit

| Module | Current state | Desktop status | Mobile status | Key verified gaps |
|---|---|---|---|---|
| Dashboard shell | distinct mobile and wide layouts | strong | strong | label-based routing fallback can still hit `No route configured` |
| Sales | strongest current document pattern plus invoice, quote, and sale-return follow-up slices | strong | strong | no dedicated sale-return workbench caller is using the new typed result yet; broader desktop standardization is now a non-Sales priority |
| POS | operationally strong, desktop-light | weak | strong | body remains mostly one vertical flow; payment path lacks richer desktop treatment |
| Purchases | second standardized follow-up slice implemented | strong | strong | purchase return detail is still a separate full-page review; source-purchase / source-PO selection dialogs are still route-local rather than fully shared |
| Inventory | responsive hooks widely present | mixed | acceptable | not fully audited page by page; standard still inconsistent |
| Customers | responsive management workbench plus detail page standardization | strong | strong | management page follows desktop workbench contract; detail page now uses denser responsive review on desktop with ProfessionalDocumentHeader/SectionCard/SummaryCard and reuses CustomerReviewCard on mobile; inline collection sheet extracted to separate widget file |
| Accounts | landing and report handoff are stronger, and the deeper finance rollout now includes ledgers, chart-of-accounts, and vouchers workbench standardization | mixed | acceptable | the deeper finance trio now follows the stronger desktop review direction, but other finance/admin pages still need the same standard applied consistently |
| Reports | dense workbench slice implemented | strong | strong | result rendering is still generic-table driven for many endpoints even though the desktop shell is now much stronger |
| HR | responsive hooks present | mixed | acceptable | landing page still uses older card-grid pattern |
| Workflow/Notifications | wide-nav handling exists | mixed | acceptable | no verified dense desktop review workbench standard yet |
| Suppliers | responsive management workbench plus detail page standardization | strong | strong | management page follows desktop workbench contract; detail page now uses denser responsive review on desktop with ProfessionalDocumentHeader/SectionCard/SummaryCard and reuses SupplierReviewCard on mobile; inline payment sheet extracted to separate widget file; "Supplier Management" route added to dashboard_navigation.dart |
| Web shell | separate product surface | unverified for responsive parity in this run | unverified | tracked manually; outside Flutter responsive baseline |

## 3. Verified Sales reference pattern

Best current reference files:
- `flutter_app/lib/features/sales/presentation/pages/sales_history_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/quotes_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/quote_detail_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/quote_form_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/b2b_invoice_form_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/sales_returns_page.dart`
- `flutter_app/lib/features/sales/presentation/widgets/professional_document_widgets.dart`

Why these matter:
- they explicitly branch between mobile and desktop bodies
- desktop layouts use summary rails, dense metadata blocks, and structured line-item work areas
- mobile layouts collapse to stacked cards and shorter action paths

Important caveat:
- Sales is the best current reference only for these deeper B2B/list/return pages
- Sales is not universally standardized yet

Known Sales gaps:
- `flutter_app/lib/features/sales/presentation/pages/invoices_page.dart` is now a real B2B invoice workbench with desktop split-pane review and mobile list-to-detail routing
- `flutter_app/lib/features/sales/presentation/pages/sale_detail_page.dart` now follows the shared document-shell family more closely
- `flutter_app/lib/features/sales/presentation/pages/quotes_page.dart` now follows the same desktop workbench/list-selection contract as invoices and sales history while mobile stays stacked
- `flutter_app/lib/features/sales/presentation/pages/quote_detail_page.dart` now uses shared quote review sections and a denser desktop review shell
- `flutter_app/lib/features/sales/presentation/pages/sale_return_detail_page.dart` now uses shared sale-return review sections and the same denser desktop review contract family while preserving mobile full-detail routing
- `flutter_app/lib/features/sales/presentation/pages/sales_returns_page.dart` now exposes an optional typed follow-up result, but no dedicated sale-return workbench caller consumes that contract yet

## 4. Desktop findings by pattern

Strong desktop candidates:
- `sales_history_page.dart`
- `invoices_page.dart`
- `quotes_page.dart`
- `quote_detail_page.dart`
- `sale_detail_page.dart`
- `sale_return_detail_page.dart`
- `quote_form_page.dart`
- `b2b_invoice_form_page.dart`
- `sales_returns_page.dart`
- `purchase_orders_page.dart`
- `po_detail_page.dart`
- `goods_receipts_page.dart`
- `grn_detail_page.dart`
- `purchase_receipt_page.dart`
- `purchase_returns_page.dart`
- `ledgers_page.dart`
- `ledger_entries_page.dart`
- `chart_of_accounts_page.dart`
- `vouchers_page.dart`
- `customer_management_page.dart`
- `customer_detail_page.dart`
- `suppliers_page.dart`
- `supplier_detail_page.dart`

Mixed desktop candidates:
- `grn_form_page.dart`
- `purchase_return_detail_page.dart`

Weak desktop candidates:
- `pos_page.dart`
- `payment_page.dart`
- older landing pages still using grid-heavy surfaces for desktop

## 5. Mobile findings by pattern

Strong mobile characteristics already present:
- stacked card/list flows
- bottom-tab shell
- shorter action paths in Sales create/edit flows
- touch-friendly list tiles and sheet/dialog usage in many modules
- Purchases PO, GRN, receipt, and return flows still stay stacked instead of forcing desktop split panes on small screens

Mobile risks still unverified:
- keyboard flow quality on long forms
- runtime overflow on smaller phones
- dense filter behavior on older devices

## 6. Verified placeholder and reachability risks

Verified code risks:
- `flutter_app/lib/features/dashboard/presentation/dashboard_navigation.dart` contains a live fallback scaffold with `No route configured`
- `flutter_app/lib/shared/pages/feature_detail_page.dart` remains a placeholder screen in the codebase, though no active references were found in this run

Conclusion:
- placeholder risk is lower than it was in older docs, but not fully eliminated from code paths

## 7. Standard layout rules to enforce

Desktop:
- use a true workbench, not a stretched mobile page
- keep filters visible without burying them under stacked cards
- reserve a right rail or side panel for summary, status, and final actions
- keep line-item work in a dense table/workspace

Mobile:
- keep creation flows stacked and scrollable
- place primary actions near the task completion point
- avoid dense multi-column grids unless the content truly fits
- prioritize touch targets over desktop density

## 8. Audit confidence

Verified:
- shell behavior
- core breakpoint helper
- module landing-page inconsistency
- Sales reference pattern
- Sales follow-up slice for:
  - true B2B invoice workbench entry
  - shared Sales workbench shell reuse between history and invoice review
  - stronger responsive `sale_detail_page.dart`
  - slightly better centralized Sales label routing
- Sales quote follow-up slice for:
  - true desktop quote workbench entry with in-pane list/review/item selection
  - typed quote form return contract for desktop reselect behavior
  - shared quote review widget reuse between `quotes_page.dart` and `quote_detail_page.dart`
  - stronger responsive `quote_detail_page.dart` while mobile stays route-driven
- Sales sale-return follow-up slice for:
  - stronger responsive `sale_return_detail_page.dart` with shared snapshot/header/overview/summary/items/reason sections
  - preserved dense desktop return authoring in `sales_returns_page.dart`
  - optional typed sale-return form result for future caller-owned desktop/workbench follow-up control
- Reports standardization slice for:
  - `reports_page.dart` moving to `FeatureMenu` for the desktop report-category launcher
  - `report_category_page.dart` becoming a desktop split workbench with selected-report review while mobile stays list-to-detail
  - `report_viewer_page.dart` gaining a desktop filter/action rail plus result pane while keeping stacked mobile behavior
  - `report_navigation.dart` centralizing report-category destination construction across Reports, Accounts, and dashboard entry points
- Accounts ledgers slice for:
  - `ledgers_page.dart` gaining a true desktop split workbench with persistent queue context and in-pane selected-ledger review while mobile stays route-driven
  - `ledger_entries_page.dart` gaining a stronger standalone desktop review shell with visible account context, filters, summaries, and linked voucher/sale/purchase references
  - `flutter_app/lib/shared/widgets/workbench_pane.dart` providing a generic shared workbench shell for this slice instead of another feature-local pane clone
  - `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` providing the narrow Accounts-specific review widgets reused by both ledger pages
- Accounts chart-of-accounts slice for:
  - `chart_of_accounts_page.dart` gaining a menu-aware desktop split workbench with persistent account queue and in-pane selected-account review while mobile stays stacked and dialog-driven
  - `dashboard_navigation.dart` now passing the `Chart of Accounts` route through the same optional menu-aware scaffold contract as the stronger Accounts finance pages
  - `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` now also providing reusable account title/status helpers for the chart workbench
- Accounts vouchers slice for:
  - `vouchers_page.dart` gaining a desktop split workbench with a searchable voucher queue and pinned selected-voucher review while mobile stays stacked with inline selected-voucher review
  - `flutter_app/lib/features/accounts/data/accounts_repository.dart` now consuming the existing voucher-detail endpoint so the review surface can load line-level debit/credit detail without a backend contract change
  - `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` now also providing reusable voucher title, voucher-type badge, and voucher-line review helpers for the workbench
- Purchases first standardization slice for PO, GRN, receipt, and purchase return flows
- Purchases second follow-up slice for:
  - GRN desktop create-to-review and mobile create-to-detail behavior
  - purchase returns desktop split-pane preview
  - shared Purchases supplier/product picker reuse in PO, GRN, and return forms
  - dashboard quick purchase action now routes into the receipt workbench entry path instead of directly bypassing it
- Customer Management workbench slice for:
  - `customer_management_page.dart` gaining a desktop split workbench with a searchable customer queue and pinned selected-customer review pane while mobile remains stacked with enhanced list cards (now including type badges) and route-driven detail navigation
  - the review pane loading customer detail + summary via existing `getCustomer` + `getCustomerSummary` endpoints so the workbench can show contact details, financial terms, business summary metrics, and credit status without a backend contract change
  - `_syncDesktopSelection` auto-selecting the first customer on desktop and re-syncing when the filtered queue changes
  - outbox sync refresh behavior preserved and extended to refresh the selected-customer review pane on desktop
  - `flutter_app/lib/features/customers/presentation/widgets/customer_workbench_widgets.dart` providing reusable customer type/status badges, credit chips, metric cards, and a comprehensive customer review card for the workbench
- Supplier Management workbench slice for:
  - `suppliers_page.dart` gaining a desktop split workbench with a searchable supplier queue and pinned selected-supplier review pane while mobile remains stacked with enhanced list cards (now including type badges) and route-driven detail navigation
  - the review pane loading supplier detail + summary via existing `getSupplier` + `getSupplierSummary` endpoints so the workbench can show contact details, financial terms, business summary metrics, payment summary, and credit status without a backend contract change
  - `_syncDesktopSelection` auto-selecting the first supplier on desktop and re-syncing when the filtered queue changes
  - outbox sync refresh behavior added (was missing in original implementation)
  - client-side search filtering replaced the original server-side re-fetch-on-keystroke pattern
  - `flutter_app/lib/features/suppliers/presentation/widgets/supplier_workbench_widgets.dart` providing reusable supplier type/status badges, credit chips, metric cards, and a comprehensive supplier review card for the workbench
  - Supplier Balance Workbench button preserved in AppBar
- Supplier detail page responsive slice for:
  - `supplier_detail_page.dart` refactored from a monolith with five nested `FutureBuilder` chains to a coordinated async load with separate desktop and mobile build paths
  - desktop: denser review layout with `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` transaction rows
  - mobile: reuses `SupplierReviewCard` from `supplier_workbench_widgets.dart` and wraps transaction lists in `ProfessionalSectionCard`
  - inline `_PaySheet` extracted to `widgets/supplier_payment_sheet.dart` as a clean reusable widget
- Dashboard routing fix for "Supplier Management" — added the missing case to `dashboard_navigation.dart` so label-based navigation to the supplier list no longer falls through to the "No route configured" fallback
- Customer detail page responsive slice for:
  - `customer_detail_page.dart` refactored from a 770-line monolith with six nested `FutureBuilder` chains to a coordinated async load with separate desktop and mobile build paths
  - desktop: denser review layout with `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` transaction rows
  - mobile: reuses `CustomerReviewCard` from `customer_workbench_widgets.dart`, adds `ProfessionalSummaryCard` for loyalty, and wraps transaction lists in `ProfessionalSectionCard`
  - inline `_CollectSheet` extracted to `widgets/customer_collection_sheet.dart` as a clean reusable widget
  - loyalty tier resolution collapsed from triple-nested `FutureBuilder` into a single guard with pre-resolved data

Partially verified:
- Inventory, Accounts, HR, Workflow, Notifications deeper subpages were sampled but not exhaustively audited file by file

Unverified:
- runtime behavior on real phones/tablets/desktops
- hidden routes that may still reach the dashboard fallback page
