# UI Responsive Audit

Updated: 2026-04-09 UTC
Audit mode: static repo inspection plus subagent-assisted Flutter audit
Runtime device testing: not performed in this run

## 1. Verified global patterns

- The app shell has a real mobile vs wide-screen split in `flutter_app/lib/features/dashboard/presentation/dashboard_screen.dart`.
- Breakpoint logic is centralized but minimal in `flutter_app/lib/core/layout/app_breakpoints.dart`.
- Module landing pages are inconsistent:
  - newer pattern: `flutter_app/lib/shared/widgets/feature_menu.dart`
  - older pattern: `flutter_app/lib/shared/widgets/feature_grid.dart`
- Routing is fragmented between label-based dispatch and direct page pushes in `flutter_app/lib/features/dashboard/presentation/dashboard_navigation.dart` and module widgets.

## 2. Module audit

| Module | Current state | Desktop status | Mobile status | Key verified gaps |
|---|---|---|---|---|
| Dashboard shell | distinct mobile and wide layouts | strong | strong | label-based routing fallback can still hit `No route configured` |
| Sales | strongest current document pattern | mixed-to-strong | strong | invoice listing missing, some detail pages stay single-column |
| POS | operationally strong, desktop-light | weak | strong | body remains mostly one vertical flow; payment path lacks richer desktop treatment |
| Purchases | responsive landing page, mixed documents | weak-to-mixed | acceptable | PO and GRN flows are mostly same-layout-on-all-sizes |
| Inventory | responsive hooks widely present | mixed | acceptable | not fully audited page by page; standard still inconsistent |
| Customers | responsive landing page | mixed | acceptable | management/detail pages are mostly wide-nav plus same body |
| Accounts | important pages use wide-nav | mixed | acceptable | landing page still uses older card-grid pattern |
| Reports | category routing exists | mixed | acceptable | desktop density/workbench treatment is still limited |
| HR | responsive hooks present | mixed | acceptable | landing page still uses older card-grid pattern |
| Workflow/Notifications | wide-nav handling exists | mixed | acceptable | no verified dense desktop review workbench standard yet |
| Web shell | separate product surface | unverified for responsive parity in this run | unverified | tracked manually; outside Flutter responsive baseline |

## 3. Verified Sales reference pattern

Best current reference files:
- `flutter_app/lib/features/sales/presentation/pages/sales_history_page.dart`
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
- `flutter_app/lib/features/sales/presentation/pages/invoices_page.dart` is only the B2B invoice form entry, not a document listing workbench
- `flutter_app/lib/features/sales/presentation/pages/quotes_page.dart` stays largely one-column across sizes
- detail pages such as `sale_detail_page.dart`, `quote_detail_page.dart`, and `sale_return_detail_page.dart` do not yet match the dense desktop workbench pattern

## 4. Desktop findings by pattern

Strong desktop candidates:
- `sales_history_page.dart`
- `quote_form_page.dart`
- `b2b_invoice_form_page.dart`
- `sales_returns_page.dart`

Mixed desktop candidates:
- `purchase_orders_page.dart`
- `goods_receipts_page.dart`
- `customer_management_page.dart`
- `report_category_page.dart`

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
- Sales reference pattern and major Sales/POS/Purchases findings

Partially verified:
- Inventory, Accounts, HR, Workflow, Notifications, and Suppliers deeper subpages were sampled but not exhaustively audited file by file

Unverified:
- runtime behavior on real phones/tablets/desktops
- hidden routes that may still reach the dashboard fallback page
