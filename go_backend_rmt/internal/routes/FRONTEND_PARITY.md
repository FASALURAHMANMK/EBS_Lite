# Frontend Coverage of Backend Routes

The table below tracks whether each backend route group in `routes.go` has a corresponding frontend service module.

| Route Group | Frontend Module | Notes |
|-------------|----------------|-------|
| `/auth` | `src/services/auth.ts` | |
| `/device-sessions` | — | Not used in frontend yet |
| `/dashboard` | `src/services/dashboard.ts` | |
| `/users` | `src/services/users.ts` | Added for parity |
| `/companies` | `src/services/companies.ts` | |
| `/locations` | `src/services/locations.ts` | Added for parity |
| `/roles` | `src/services/roles.ts` | Added for parity |
| `/permissions` | `src/services/roles.ts` | Exposed via getPermissions |
| `/products` | `src/services/products.ts` | |
| `/categories` | `src/services/categories.ts` | |
| `/brands` | — | Not currently used |
| `/units` | — | Not currently used |
| `/product-attribute-definitions` | — | Not currently used |
| `/inventory` | `src/services/inventory.ts` | |
| `/sales` | `src/services/sales.ts` | Quote helpers pending |
| `/pos` | — | POS UI not implemented |
| `/loyalty-programs` | — | Reserved for future feature |
| `/loyalty-redemptions` | — | Reserved for future feature |
| `/loyalty` | — | Reserved for future feature |
| `/promotions` | — | Reserved for future feature |
| `/sale-returns` | — | Reserved for future feature |
| `/purchases` | `src/services/purchases.ts` | Listing endpoints not used |
| `/purchase-orders` | `src/services/purchases.ts` | |
| `/goods-receipts` | `src/services/purchases.ts` | |
| `/purchase-returns` | `src/services/purchases.ts` | |
| `/customers` | `src/services/customers.ts` | |
| `/employees` | `src/services/employees.ts` | Added for parity |
| `/attendance` | `src/services/attendance.ts` | Added for parity |
| `/payrolls` | — | Not currently used |
| `/collections` | — | Not currently used |
| `/expenses` | — | Not currently used |
| `/vouchers` | `src/services/accounting.ts` | |
| `/ledgers` | `src/services/accounting.ts` | |
| `/cash-registers` | `src/services/accounting.ts` | |
| `/reports` | — | Not currently used |
| `/suppliers` | `src/services/suppliers.ts` | |
| `/currencies` | — | Not currently used |
| `/taxes` | — | Not currently used |
| `/settings` | — | Not currently used |
| `/audit-logs` | — | Not currently used |
| `/languages` | — | Not currently used |
| `/translations` | — | Not currently used |
| `/user-preferences` | — | Not currently used |
| `/numbering-sequences` | — | Not currently used |
| `/invoice-templates` | — | Not currently used |
| `/print` | — | Not currently used |
| `/workflow-requests` | — | Not currently used |

This document should be updated whenever new service modules are created or an unused endpoint becomes active.
