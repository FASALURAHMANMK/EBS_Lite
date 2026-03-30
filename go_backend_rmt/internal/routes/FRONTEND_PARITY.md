# Frontend Coverage of Backend Routes

The table below tracks whether each backend route group in `routes.go` has a corresponding frontend service module.

| Route Group | Frontend Module | Notes |
|-------------|----------------|-------|
| `/auth` | `src/services/auth.ts` | |
| `/device-sessions` | `src/services/deviceSessions.ts` | |
| `/dashboard` | `src/services/dashboard.ts` | |
| `/users` | `src/services/users.ts` | Added for parity |
| `/companies` | `src/services/companies.ts` | |
| `/locations` | `src/services/locations.ts` | Added for parity |
| `/roles` | `src/services/roles.ts` | Added for parity |
| `/permissions` | `src/services/roles.ts` | Exposed via getPermissions |
| `/products` | `src/services/products.ts` | |
| `/categories` | `src/services/categories.ts` | |
| `/brands` | `src/services/brands.ts` | |
| `/units` | `src/services/units.ts` | |
| `/product-attribute-definitions` | `src/services/productAttributes.ts` | |
| `/inventory` | `src/services/inventory.ts` | |
| `/sales` | `src/services/sales.ts` | Quote helpers pending |
| `/pos` | — | POS UI not implemented |
| `/loyalty-programs` | — | Reserved for future feature |
| `/loyalty-redemptions` | — | Reserved for future feature |
| `/loyalty` | — | Reserved for future feature |
| `/promotions` | — | Reserved for future feature |
| `/sale-returns` | — | Reserved for future feature |
| `/purchases` | `src/services/purchases.ts` | |
| `/purchase-orders` | `src/services/purchases.ts` | |
| `/goods-receipts` | `src/services/purchases.ts` | |
| `/purchase-returns` | `src/services/purchases.ts` | |
| `/customers` | `src/services/customers.ts` | |
| `/employees` | `src/services/employees.ts` | Added for parity |
| `/attendance` | `src/services/attendance.ts` | Added for parity |
| `/payrolls` | — | Intentionally unused |
| `/collections` | — | Web shell intentionally unused; Flutter ships collections workbench and customer collections flows |
| `/expenses` | — | Intentionally unused |
| `/vouchers` | `src/services/accounting.ts` | |
| `/ledgers` | `src/services/accounting.ts` | |
| `/chart-of-accounts` | — | Flutter-only accounting admin surface; web shell intentionally unused |
| `/accounting-periods` | — | Flutter-only accounting close workflow; web shell intentionally unused |
| `/bank-accounts` | — | Flutter-only banking and reconciliation workflow; web shell intentionally unused |
| `/finance-integrity` | — | Flutter accounting diagnostics only; web shell intentionally unused |
| `/cash-registers` | `src/services/accounting.ts` | |
| `/reports` | — | Intentionally unused |
| `/suppliers` | `src/services/suppliers.ts` | |
| `/currencies` | — | Intentionally unused |
| `/taxes` | — | Intentionally unused |
| `/settings` | — | Web shell intentionally unused; Flutter uses inventory settings and other admin settings surfaces |
| `/audit-logs` | — | Intentionally unused |
| `/languages` | — | Intentionally unused |
| `/translations` | — | Intentionally unused |
| `/user-preferences` | — | Intentionally unused |
| `/numbering-sequences` | — | Intentionally unused |
| `/invoice-templates` | — | Intentionally unused |
| `/print` | — | Intentionally unused |
| `/workflow-requests` | — | Web shell intentionally unused; Flutter ships approvals list/detail and approval actions |

This document should be updated whenever new service modules are created or an unused endpoint becomes active.
