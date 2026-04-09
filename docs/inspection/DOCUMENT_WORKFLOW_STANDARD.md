# Document Workflow Standard

Updated: 2026-04-09 UTC
Reference decision: use the verified Sales B2B document stack as the current baseline, with exceptions noted below

## 1. Verified reference sources

Reference files:
- `flutter_app/lib/features/sales/presentation/pages/sales_history_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/quote_form_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/b2b_invoice_form_page.dart`
- `flutter_app/lib/features/sales/presentation/pages/sales_returns_page.dart`
- `flutter_app/lib/features/sales/presentation/widgets/professional_document_widgets.dart`

Non-reference files:
- `flutter_app/lib/features/pos/presentation/pages/pos_page.dart`
- `flutter_app/lib/features/pos/presentation/pages/payment_page.dart`
- `flutter_app/lib/features/purchases/presentation/pages/po_form_page.dart`
- `flutter_app/lib/features/purchases/presentation/pages/goods_receipts_page.dart`

Interpretation:
- the strongest current pattern is not “Sales overall”
- the strongest current pattern is the Sales B2B document workbench subset

## 2. Standard workflow types

Every document-heavy module should converge on the same flow family:

- `list/workbench`
- `create/edit`
- `detail/review`
- `approve/receive/close` when applicable
- `print/share/export`
- `status and audit trail`

## 3. Desktop standard

### List/workbench

Required:
- left/main panel for searchable document list
- persistent or quickly accessible filters
- desktop detail pane or split-pane review when volume justifies it
- visible status chips and totals

Reference:
- `sales_history_page.dart`

### Create/edit

Required:
- dense metadata row
- structured customer/vendor/account/commercial sections
- line-item workspace with add/edit controls
- right summary rail for totals, balance, and primary actions

Reference:
- `quote_form_page.dart`
- `b2b_invoice_form_page.dart`
- `sales_returns_page.dart`

### Detail/review

Required:
- not just a stretched mobile card list
- document header with number, status, party, dates, and totals
- action cluster for print/share/edit/status transitions
- visible source references and audit-relevant state

Current repo gap:
- several Sales detail pages still need this standard

### Approve/receive/close

Required:
- status progression is visible before the commit action
- operator sees blockers, source document, and resulting inventory/financial impact summary
- destructive or irreversible actions need explicit confirmation

### Print/share/export

Required:
- these are first-class actions on detail/workbench pages
- do not hide print/share behind undocumented secondary routes
- desktop should support batch-oriented review and export where relevant

## 4. Mobile standard

### List/workbench

Required:
- one-column list/cards
- fast search and essential filters only
- quick jump into create/detail

### Create/edit

Required:
- stacked sections
- short labels and touch-safe controls
- avoid simultaneous dense tables and side rails
- keep the primary submit action near the bottom completion point

### Detail/review

Required:
- summary card first
- action buttons grouped clearly
- line items collapsible or readable without desktop-only assumptions

## 5. Shared component rules

- Prefer `professional_document_widgets.dart` patterns over module-local duplicates.
- Avoid raw width checks like `width >= 1200` when the breakpoint intent belongs in shared layout helpers.
- New modules should not introduce another landing-page pattern when `FeatureMenu` or the document workbench pattern already fits.
- Routing for document flows should be centrally discoverable; avoid mixing label routing, direct widget pushes, and hidden branch behavior without a clear reason.

## 6. Priority rollout order

1. Sales gaps
   - add a true invoice listing/workbench
   - upgrade quote and return detail pages to the desktop standard
2. Purchases
   - apply the Sales workbench pattern to PO, GRN, and purchase returns
3. Accounts/reporting
   - use dense desktop review patterns for finance and report-heavy pages
4. Customer/vendor workbenches
   - collections, balances, and care hubs should align with the same desktop/mobile logic

## 7. Definition of done for a standardized document module

- desktop and mobile behavior are explicitly different or clearly responsive by rule
- list, create/edit, detail, and status actions follow one documented pattern
- print/share/export and status transitions are reachable without dead-end navigation
- the module uses shared layout/document primitives wherever possible
- the module is added to `docs/inspection/UI_RESPONSIVE_AUDIT.md` when changed
