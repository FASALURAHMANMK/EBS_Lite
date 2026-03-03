## Reports + Import/Export cross-check (2026-03-03)

Sources:
- `flutter_app/ERP System Requirements Document.txt` (Reports module + “All reports can be exported to excel & pdf” + Excel import/export notes)
- `go_backend_rmt/Docs & Schema/ERP System Requirements Document.txt` (same)
- `ebs_lite_win/Requirements.txt` (reports “starter pack”, bulk onboarding expectations)

### Implemented report categories (Flutter UI)
Flutter has these report categories and endpoints:
- Sales: `/reports/sales-summary`, `/reports/top-products`, `/reports/customer-balances`, `/reports/tax`
- Purchase: `/reports/expenses-summary`, `/reports/purchase-vs-returns`, `/reports/supplier`
- Accounts: `/reports/daily-cash`, `/reports/income-expense`, `/reports/general-ledger`, `/reports/trial-balance`, `/reports/profit-loss`, `/reports/balance-sheet`, `/reports/outstanding`, `/reports/top-performers`
- Inventory: `/reports/stock-summary`, `/reports/item-movement`, `/reports/valuation`

Exports:
- Backend supports `?format=pdf|excel` for **all** report endpoints above and returns a file download (or JSON error if not implemented/invalid).
- Flutter exports use byte downloads and now surface backend JSON errors clearly.

Known gaps vs `ebs_lite_win/Requirements.txt` “starter pack” (not yet implemented as dedicated endpoints):
- Sales: cashier-wise, item-wise, category-wise, customer-wise
- Stock: stock ledger, low stock report (beyond current summaries)
- Purchases: purchase register by period/supplier
- Customers: statement, loyalty ledger

### Bulk onboarding (Import/Export)
Backend endpoints exist for Excel onboarding:
- Customers: `POST /customers/import` (multipart “file”), `GET /customers/export` (xlsx)
- Suppliers: `POST /suppliers/import` (multipart “file”), `GET /suppliers/export` (xlsx)
- Inventory: `POST /inventory/import` (multipart “file”), `GET /inventory/export` (xlsx)

Flutter provides a Settings-accessible UI that can:
- pick an `.xlsx` file and upload it to the matching import endpoint
- download export files and share/save them via the OS share sheet (Android/Windows supported by `share_plus`)

