# SMB Release Milestones

Updated: 2026-04-11 UTC (M4 third slice — migration hygiene cleanup)
Status model: `completed`, `in_progress`, `pending`, `blocked`

## Milestone table

| ID | Milestone | Status | Depends on | Exit criteria |
|---|---|---|---|---|
| M0 | Repo bootstrap and continuity baseline | completed | none | `docs/inspection/` is populated, stale workflow docs are archived, `.codex` continuity files are current |
| M1 | Responsive and document workflow baseline | in_progress | M0 | verified module audit exists, Sales reference pattern is documented, rollout priority for non-standard modules is agreed |
| M2 | Shared UI/layout standardization | in_progress | M1 | shared desktop/mobile document shell exists and is applied to priority modules beyond Sales |
| M3 | Backend/API hardening | in_progress | M0 | runtime schema tolerance removed from service code, OpenAPI endpoint classification started, auth/settings posture reviewed |
| M4 | DB, performance, and release safety hardening | in progress | M3 | top N+1 hotspots have batch-loading fixes; outbox idempotency has client-side duplicate detection + unique index + backend unique constraints; base migration DDL is clean with zero duplicates |
| M5 | Validation, permissions, and security posture | pending | M3 | production config gates, uploads, password reset delivery, and permission-sensitive paths are verified and documented |
| M6 | QA/UAT and operational readiness | blocked | M1, M3, M4, M5 | blocker UAT scenarios are executed, evidence is attached, release ops docs match reality |
| M7 | Deployment and final release gate | blocked | M6 | packaged environment verification is complete and a current go/no-go decision is evidence-backed |

## Milestone details

### M0. Repo bootstrap and continuity baseline

Scope:
- inspect repo structure and current docs
- archive stale one-off workflow docs
- create the inspection baseline and continuity protocol
- restore tracked `.codex/config.toml`

Completed in this run:
- `docs/inspection/*` continuity backbone created
- stale prompt/governance artifacts archived under `docs/archive/2026-04-09/`
- `.codex/README.md` refreshed
- `.codex/config.toml` restored

Residual notes:
- `AGENTS.md` still references a missing backlog file, but it now flags that gap explicitly

### M1. Responsive and document workflow baseline

Scope:
- audit desktop/mobile/responsive behavior across major modules
- identify the strongest current document workflow pattern
- define a standard for create/list/detail/edit/approve/print/share/status

Current evidence:
- Sales deeper document pages are the best current reference
- Sales first follow-up slice is now implemented:
  - `InvoicesPage` is a true B2B invoice workbench entry instead of a direct form alias
  - `B2BInvoiceFormPage` can now return a typed workflow result for workbench callers
  - `sale_detail_page.dart` now uses a denser shared document review layout
- Sales second follow-up slice is now implemented:
  - `quotes_page.dart` now uses the same desktop workbench contract as invoices and sales history while preserving mobile detail routing
  - `quote_form_page.dart` can now return a typed workflow result for workbench callers
  - `quote_detail_page.dart` now uses shared quote review sections and a denser responsive review shell
- Sales third follow-up slice is now implemented:
  - `sale_return_detail_page.dart` now uses shared sale-return review sections and a denser responsive review shell while preserving stacked mobile routing
  - `sales_returns_page.dart` now supports an optional typed workflow result for future caller-owned desktop/workbench follow-up without changing the default form-owned route
- Reports first follow-up slice is now implemented:
  - `reports_page.dart` now uses `FeatureMenu` for the desktop report-category launcher while mobile preserves the grid
  - `report_category_page.dart` now provides a desktop split report workbench with in-pane selection and review while mobile stays list-to-detail
  - `report_viewer_page.dart` now provides a desktop filter/action rail plus result pane while preserving stacked mobile report review
  - `accounting_page.dart` now routes `Accounting Reports` through the centralized Reports destination helper and also uses `FeatureMenu` on desktop
- Accounts deeper finance follow-up slices are now implemented:
  - `ledgers_page.dart` now provides a desktop split workbench with searchable ledger selection and in-pane selected-ledger review while mobile stays route-driven
  - `ledger_entries_page.dart` now provides a stronger standalone desktop ledger review shell with visible account context, filters, summaries, and linked document references
  - `flutter_app/lib/shared/widgets/workbench_pane.dart` now exists as a generic shared workbench shell first used by the Accounts ledger slice
  - `chart_of_accounts_page.dart` now provides a menu-aware desktop split workbench with searchable account selection and in-pane selected-account review while mobile stays stacked and dialog-driven
  - `vouchers_page.dart` now provides a menu-aware desktop split workbench with searchable voucher selection and in-pane selected-voucher review while mobile stays stacked with inline selected-voucher review
  - `flutter_app/lib/features/accounts/data/accounts_repository.dart` now consumes the existing voucher-detail endpoint for the workbench review surface
  - `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` now also provides reusable account title/status and voucher title/type/line helpers for the deeper Accounts review surfaces
- POS is not yet the desktop reference
- Purchases second follow-up slice is now implemented:
  - GRN creation/receipt returns into desktop workbench review and mobile detail when a real receipt id exists
  - purchase returns now have a desktop split-pane preview
  - shared Purchases supplier/product picker components reduce local duplication
- Customer Management workbench slice is now implemented:
  - `customer_management_page.dart` now provides a desktop split workbench with searchable customer queue and in-pane selected-customer review while mobile stays stacked with enhanced list cards and route-driven detail navigation
  - `flutter_app/lib/features/customers/presentation/widgets/customer_workbench_widgets.dart` now provides reusable customer type/status badges, credit chips, metric cards, and a comprehensive customer review card
  - outbox sync refresh behavior preserved and extended to refresh the selected-customer review pane on desktop
- Supplier Management workbench slice is now implemented:
  - `suppliers_page.dart` now provides a desktop split workbench with searchable supplier queue and in-pane selected-supplier review while mobile stays stacked with enhanced list cards and route-driven detail navigation
  - `flutter_app/lib/features/suppliers/presentation/widgets/supplier_workbench_widgets.dart` now provides reusable supplier type/status badges, credit chips, metric cards, and a comprehensive supplier review card
  - outbox sync refresh was added (was missing in original); client-side filtering replaced server-side re-fetch-on-keystroke
  - Supplier Balance Workbench button preserved in AppBar
- Customer detail page responsive slice is now implemented:
  - `customer_detail_page.dart` refactored from a 770-line monolith with six nested `FutureBuilder` chains to a coordinated async load with separate desktop and mobile build paths
  - desktop: denser review layout with `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` transaction rows
  - mobile: reuses `CustomerReviewCard` from `customer_workbench_widgets.dart`, adds `ProfessionalSummaryCard` for loyalty, and wraps transaction lists in `ProfessionalSectionCard`
  - inline `_CollectSheet` extracted to `widgets/customer_collection_sheet.dart` as a clean reusable widget
- Supplier detail page responsive slice is now implemented:
  - `supplier_detail_page.dart` refactored from a monolith with five nested `FutureBuilder` chains to a coordinated async load with separate desktop and mobile build paths
  - desktop: denser review layout with `ProfessionalDocumentHeader`, `ProfessionalOverviewCard`, `ProfessionalFieldGrid`, `ProfessionalSummaryCard`, and `ProfessionalBadge` transaction rows
  - mobile: reuses `SupplierReviewCard` from `supplier_workbench_widgets.dart` and wraps transaction lists in `ProfessionalSectionCard`
  - inline `_PaySheet` extracted to `widgets/supplier_payment_sheet.dart` as a clean reusable widget
- Dashboard routing fix for "Supplier Management" is now implemented:
  - added the missing case to `dashboard_navigation.dart` so label-based navigation to the supplier list no longer falls through to the "No route configured" fallback
- Purchase return detail hardening slice is now implemented:
  - `purchase_return_detail_page.dart` already used ProfessionalDocumentHeader, ProfessionalSectionCard, ProfessionalSummaryCard, ProfessionalFieldGrid, ProfessionalOverviewCard, and ProfessionalDocumentEmptyState with desktop/mobile branching
  - added proper error state handling with `AppErrorView` + retry (previously `_loading` stayed true forever on error)
  - added `RefreshIndicator` on mobile and Refresh AppBar action
  - denser desktop items display with compact DataTable-style rows
  - mobile retains ProfessionalOverviewCard per item pattern
- several back-office modules still remain mixed or mobile-first

Exit criteria:
- `docs/inspection/UI_RESPONSIVE_AUDIT.md` and `docs/inspection/DOCUMENT_WORKFLOW_STANDARD.md` stay current
- the next implementation slice is picked from the priority rollout order below

Priority rollout order:
1. Customer and supplier document-heavy workbenches
2. Purchases residual detail-level refinements only if a contradiction or regression is discovered
3. Residual Sales caller-owned return-workbench adoption only if a dedicated returns workbench or routing contradiction surfaces

### M2. Shared UI/layout standardization

Scope:
- turn Sales professional document widgets into a reusable pattern
- remove mixed desktop landing/page patterns
- centralize responsive rules instead of ad hoc width checks

Current evidence:
- `flutter_app/lib/shared/widgets/professional_document_widgets.dart` now exists as the shared document primitive layer
- Sales keeps continuity through a re-export file
- the shared document shell is now actively used in Purchases PO/GRN/receipt/return pages
- the shared document shell is now also used by Reports category/viewer pages for desktop review framing
- `flutter_app/lib/features/purchases/presentation/widgets/purchase_document_widgets.dart` now carries shared Purchases picker components as well as metric/list helpers
- `flutter_app/lib/features/sales/presentation/widgets/sales_workbench_widgets.dart` now provides a narrow shared Sales workbench shell and badge layer
- the shared Sales workbench shell is now reused by `sales_history_page.dart`, `invoices_page.dart`, and `quotes_page.dart`
- `flutter_app/lib/features/sales/presentation/widgets/quote_review_widgets.dart` now provides shared quote review/list widgets reused by the quote workbench and `quote_detail_page.dart`
- `flutter_app/lib/features/sales/presentation/widgets/sale_return_review_widgets.dart` now provides shared sale-return review widgets reused by `sale_return_detail_page.dart`
- `flutter_app/lib/features/reports/presentation/widgets/report_workbench_widgets.dart` now provides narrow shared report-workbench pane and capability widgets reused by `report_category_page.dart` and `report_viewer_page.dart`
- `flutter_app/lib/features/reports/presentation/report_navigation.dart` now centralizes report-category destination construction across Reports, Accounts, and dashboard routing
- `flutter_app/lib/shared/widgets/workbench_pane.dart` now exists as a generic shared workbench shell and is first used by the Accounts ledger slice
- `flutter_app/lib/features/accounts/presentation/widgets/accounts_workbench_widgets.dart` now also carries shared account title/status and voucher title/type/line helpers reused by the Chart of Accounts and Vouchers workbenches
- `flutter_app/lib/features/customers/presentation/widgets/customer_workbench_widgets.dart` now provides shared customer type/status badges, credit chips, metric cards, and a comprehensive customer review card reused by the Customer Management workbench and CustomerDetailPage mobile body
- `flutter_app/lib/features/customers/presentation/widgets/customer_collection_sheet.dart` now exists as a clean extracted collection sheet widget replacing the inline `_CollectSheet` in the detail page
- `flutter_app/lib/features/suppliers/presentation/widgets/supplier_workbench_widgets.dart` now provides shared supplier type/status badges, credit chips, metric cards, and a comprehensive supplier review card reused by the Supplier Management workbench and SupplierDetailPage mobile body
- `flutter_app/lib/features/suppliers/presentation/widgets/supplier_payment_sheet.dart` now exists as a clean extracted payment sheet widget replacing the inline `_PaySheet` in the detail page

Exit criteria:
- shared document components are reused across multiple modules
- module landing pages no longer split between old grid-only and newer list/workbench patterns without justification

### M3. Backend/API hardening

Scope:
- remove runtime schema drift tolerance
- move seed/bootstrap behavior out of startup-side services where possible
- classify unused OpenAPI endpoints
- reduce fragile runtime assumptions in auth, settings, and support flows

Exit criteria:
- no request path depends on schema probing as a fallback behavior
- auth/settings/bootstrap posture is migration-backed and environment-safe
- unused endpoints are classified as internal, future, or uncommercialized

### M4. DB, performance, and release safety hardening

Scope:
- eliminate major N+1 hotspots
- reduce dashboard fan-out cost
- strengthen finance outbox and ledger idempotency guarantees
- improve migration hygiene and schema confidence

Exit criteria:
- top hotspots have code fixes or documented exceptions
- outbox claim/idempotency protections are no longer purely best-effort
- release DB safety is stronger than current startup defaults

### M5. Validation, permissions, and security posture

Scope:
- tighten upload confidentiality
- verify password reset deliverability and production-readiness checks
- review permission-sensitive settings/admin flows
- verify release config guidance against actual code paths

Exit criteria:
- production readiness includes the real password reset dependency chain
- upload handling is compatible with document confidentiality expectations
- permission and security docs match implementation

### M6. QA/UAT and operational readiness

Scope:
- execute blocker UAT scenarios
- reconcile seeded data against reports and accounting outputs
- validate offline/outbox claims in the flows that are publicly claimed

Current blocker:
- manual release-candidate UAT sign-off remains incomplete

### M7. Deployment and final release gate

Scope:
- rerun automated gates
- verify packaged configuration
- update ship/no-go decision

Gate note:
- this milestone stays blocked until M6 evidence is complete
