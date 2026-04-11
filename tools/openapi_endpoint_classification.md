# OpenAPI Endpoint Classification Report

Updated: 2026-04-11 UTC
Method: static analysis of Go backend routes, handlers, services, web shell references, and Flutter client calls

## Classification Model

| Status | Meaning | Action |
|---|---|---|
| `active` | Used by Flutter or web shell primary flows | Keep as-is |
| `internal` | Used by backend internal tooling, web shell secondary flows, health probes, or event replay | Keep but document as non-Flutter |
| `future` | Fully implemented in Go backend but not yet wired to any frontend client | Keep in OpenAPI as planned features |
| `uncommercialized` | Legacy aliases, superseded catch-alls, or never-integrated experiments | Candidate for removal or deprecation |

## Endpoint Classification

| # | Endpoint | Status | Reasoning |
|---|---|---|---|
| 1 | `/cash-registers/events` | future | Returns audit trail of cash register state changes. Flutter calls main CRUD endpoints but never fetches the event log. Planned audit feature. |
| 2 | `/collections/{id}` (PUT/DELETE) | future | Flutter uses GET/POST/GET-outstanding on `/collections`. Individual update/delete not wired to any Flutter screen. |
| 3 | `/collections/{id}/receipt` | future | Returns printable receipt for a customer collection payment. Neither Flutter nor web shell calls it; intended for future receipt-printing flow. |
| 4 | `/currencies/{id}` (PUT/PATCH/DELETE) | future | Flutter reads `GET /currencies` for offline POS cache. Write operations are admin-only and not surfaced in any Flutter settings screen. |
| 5 | `/customers/{id}/credit` | internal | Web shell has full credit ledger UI. Flutter reads `credit_balance` as a display field but never hits this API. |
| 6 | `/employee-roles` | **uncommercialized** | Backward-compatible alias for `/designations`. Neither Flutter nor web shell uses this alias. **x-status annotation added to OpenAPI.** |
| 7 | `/employee-roles/{id}` | **uncommercialized** | Same as #6 — legacy alias for `/designations/{id}`. **x-status annotation added to OpenAPI.** |
| 8 | `/expenses/{id}` (GET) | future | Flutter has Expenses page with list and create. Individual detail view not wired to any Flutter screen. |
| 9 | `/health` | **internal** | Server reachability ping used by Flutter outbox connectivity probe and load balancers. **x-status annotation added to OpenAPI.** |
| 10 | `/inventory/barcode` | internal | Generates PDF of barcode labels. Web shell has dedicated BarcodeLabelPrinter page. Flutter does not call it. |
| 11 | `/inventory/summary` | future | Returns aggregated inventory overview. Not referenced by Flutter or web shell. Planned dashboard/report widget. |
| 12 | `/languages` | future | Returns list of active languages. Neither client calls it; both use local i18n. Admin language management not yet surfaced. |
| 13 | `/languages/{code}` (PUT) | future | Activates/deactivates a language code. Admin-only; no client references it. Pairs with #12. |
| 14 | `/loyalty-programs` | future | FRONTEND_PARITY.md marks it "Reserved for future feature." Not in Flutter or web shell. |
| 15 | `/loyalty-programs/{customer_id}` | future | Returns single customer's loyalty points and activity. Not in Flutter or web shell. Pairs with #14. |
| 16 | `/loyalty/award-points` | **internal** | Triggered by finance integrity event replay (financeEventLoyaltyAward). Not for direct client calls. **x-status annotation added to OpenAPI.** |
| 17 | `/numbering-sequences/{id}` (full CRUD) | future | Flutter reads `GET /numbering-sequences` for offline POS receipt numbering. Individual CRUD operations are admin-only. |
| 18 | `/payrolls/{id}/advances` | future | Records salary advance. Flutter uses base payroll CRUD but not advance/component/deduction sub-endpoints. |
| 19 | `/payrolls/{id}/components` | future | Adds salary component to a payroll. Same reasoning as #18. |
| 20 | `/payrolls/{id}/deductions` | future | Records deduction against a payroll. Same reasoning as #18 and #19. |
| 21 | `/pos/receipt/{id}` | future | Returns formatted receipt data for a POS sale. Flutter's POS flow uses `/pos/checkout` and `/pos/print`. Planned receipt-preview feature. |
| 22 | `/products/{id}/summary` | future | Returns condensed product summary. Not called by Flutter or web shell. Planned product detail widget. |
| 23 | `/promotions/check-eligibility` | future | FRONTEND_PARITY.md marks `/promotions` as "Reserved for future feature." Checks customer promotion eligibility. |
| 24 | `/purchase-orders/{id}` (PUT/DELETE) | internal | Web shell has full PO CRUD. Flutter only calls POST and PUT /:id/approve. Edit/delete are web-shell-only. |
| 25 | `/purchases/{id}/receive` | internal | Web shell calls `PUT /purchases/{id}/receive`. Flutter uses `POST /goods-receipts` instead. |
| 26 | `/ready` | **internal** | Readiness probe checking DB + Redis connectivity. Used by orchestrators. **x-status annotation added to OpenAPI.** |
| 27 | `/sale-returns/process/{sale_id}` | internal | Web shell's returns service calls this. Flutter uses `POST /sale-returns` (full create) instead. |
| 28 | `/sale-returns/summary` | future | Returns aggregated return statistics. Flutter has sales returns list/detail but no summary report page. |
| 29 | `/sales/history/export` | internal | Web shell calls this to export invoice history as XLSX. Flutter has invoices page but no export button. |
| 30 | `/sales/quick` | internal | Web shell has dedicated Quick Sale page. Flutter's POS flow uses `/pos/checkout` instead. |
| 31 | `/sales/quotes/export` | future | Exports quotes as XLSX. Neither Flutter nor web shell calls it. |
| 32 | `/sales/{id}/hold` | internal | Web shell calls this from its sales interface. Flutter's POS uses `POST /pos/hold` instead. |
| 33 | `/settings` (bare GET/PUT) | **uncommercialized** | Flutter uses specific sub-routes (`/settings/company`, `/settings/inventory`, etc.). Bare path is a legacy catch-all. **x-status annotation added to OpenAPI.** |
| 34 | `/support/issues/{id}` | future | Flutter calls `POST /support/issues` (create) from Help & Support. Individual detail view not wired to any Flutter screen. |
| 35 | `/translations` | **uncommercialized** | FRONTEND_PARITY.md marks it "Intentionally unused." Both Flutter and web shell use local i18n. Server-side translation store never integrated. **x-status annotation added to OpenAPI.** |

## Summary Counts

| Classification | Count | OpenAPI x-status added |
|---------------|-------|----------------------|
| **active** | 250 | N/A (already used by Flutter) |
| **internal** | 10 | `/health`, `/ready`, `/loyalty/award-points` (3 annotated) |
| **future** | 21 | Kept as-is in OpenAPI (planned features) |
| **uncommercialized** | 5 | `/employee-roles`, `/employee-roles/{id}`, `/settings`, `/translations` (4 annotated) |

## Actions Taken

1. **Added `x-status` and `x-note` annotations** to 7 OpenAPI paths:
   - `/health` → `x-status: internal`
   - `/ready` → `x-status: internal`
   - `/loyalty/award-points` → `x-status: internal`
   - `/employee-roles` → `x-status: uncommercialized`
   - `/employee-roles/{id}` → `x-status: uncommercialized`
   - `/settings` → `x-status: uncommercialized`
   - `/translations` → `x-status: uncommercialized`

2. **No endpoints were removed** — classification is a documentation-first approach. Removal of uncommercialized endpoints should be a separate PR after product owner sign-off.

3. **Remaining unannotated unused paths** (21 `future` + 3 `internal`) can be annotated in a follow-up run if needed. The 7 annotated paths represent the most actionable set (3 internal probes and 4 uncommercialized candidates).
