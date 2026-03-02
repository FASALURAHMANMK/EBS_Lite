# API Parity Report (Flutter <-> OpenAPI)

- Flutter unique paths: **129**
- OpenAPI unique paths: **197**

## Flutter paths missing from OpenAPI
- None

## Method mismatches (Flutter uses method not in OpenAPI)
- None

## OpenAPI paths unused by Flutter
(Often means the UI is still a placeholder, or endpoints can be removed if truly not needed.)
- `/auth/refresh-token`
- `/cash-registers/events`
- `/collections/outstanding`
- `/collections/{}`
- `/collections/{}/receipt`
- `/currencies/{}`
- `/customers/export`
- `/customers/import`
- `/customers/{}/credit`
- `/device-sessions`
- `/device-sessions/{}`
- `/employees`
- `/employees/{}`
- `/expenses`
- `/expenses/categories`
- `/expenses/categories/{}`
- `/expenses/{}`
- `/health`
- `/inventory/barcode`
- `/inventory/export`
- `/inventory/import`
- `/inventory/summary`
- `/invoice-templates`
- `/invoice-templates/{}`
- `/languages`
- `/languages/{}`
- `/loyalty-programs`
- `/loyalty-programs/{}`
- `/loyalty-redemptions`
- `/loyalty/award-points`
- `/numbering-sequences/{}`
- `/payrolls/{}/advances`
- `/payrolls/{}/components`
- `/payrolls/{}/deductions`
- `/permissions`
- `/pos/receipt/{}`
- `/products/{}/summary`
- `/promotions/check-eligibility`
- `/purchase-orders/{}`
- `/purchases/{}/receive`
- `/ready`
- `/roles`
- `/roles/{}`
- `/roles/{}/permissions`
- `/sale-returns/process/{}`
- `/sale-returns/summary`
- `/sales/history/export`
- `/sales/quick`
- `/sales/quotes/export`
- `/sales/{}/hold`
- `/settings`
- `/settings/device-control`
- `/settings/invoice`
- `/settings/printer`
- `/settings/printer/{}`
- `/settings/session-limit`
- `/settings/tax`
- `/suppliers/export`
- `/suppliers/import`
- `/support/bundle`
- `/translations`
- `/user-preferences`
- `/user-preferences/{}`
- `/users`
- `/users/{}`
- `/workflow-requests`
- `/workflow-requests/{}/approve`
- `/workflow-requests/{}/reject`
