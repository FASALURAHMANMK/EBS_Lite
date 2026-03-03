# POS essentials checklist (audit vs `ebs_lite_win/Requirements.txt`)

Date: 2026-03-03

This checklist focuses on the POS items explicitly called out in `ebs_lite_win/Requirements.txt`:
- split payments
- multi-currency tender/exchange rates
- credit limit checks
- loyalty earn/redeem + receipts
- returns by reference
- reprint/share receipt/invoice

## Implemented

### Split payments (multiple methods)
- Flutter: `flutter_app/lib/features/pos/presentation/pages/payment_page.dart` (multiple payment lines)
- Flutter → API: `flutter_app/lib/features/pos/data/pos_repository.dart` (`payments: [...]` on `/pos/checkout`)
- Backend: `go_backend_rmt/internal/services/pos_service.go` (`recordSalePaymentsTx` / `sale_payments` writes)

### Multi-currency tender + exchange rates (per payment method)
- Flutter: `flutter_app/lib/features/pos/presentation/pages/payment_page.dart` (currency picker per payment line)
- Flutter → API:
  - `flutter_app/lib/features/dashboard/data/payment_methods_repository.dart` (`getMethodCurrencies`)
  - `flutter_app/lib/features/pos/data/pos_repository.dart` (`/currencies`, `/pos/payment-methods`)
- Backend: `go_backend_rmt/internal/services/pos_service.go` (exchange rate resolution when recording payments)

### Returns by reference (invoice-linked)
- Flutter: `flutter_app/lib/features/sales/presentation/pages/sales_returns_page.dart` (link by invoice number)
- Backend:
  - `go_backend_rmt/internal/handlers/returns.go` (`/sale-returns/search/{sale_id}`, `/sale-returns/process/{sale_id}`)
  - `go_backend_rmt/internal/services/returns_service.go` (validates return quantities vs original sale)

### Reprint/share receipt/invoice
- Flutter:
  - `flutter_app/lib/features/pos/presentation/pages/payment_page.dart` (print/share after successful checkout)
  - `flutter_app/lib/features/sales/presentation/pages/sale_detail_page.dart` (print/share from history)
- Backend: `go_backend_rmt/internal/handlers/pos.go` (`/pos/print`, `/pos/receipt/{id}`)

## Implemented (new in this pass)

### Credit limit checks (server-enforced)
- Backend: `go_backend_rmt/internal/services/pos_service.go` (`enforceCustomerCreditLimit` invoked from checkout and held-sale finalization)
- Behavior:
  - If a POS checkout creates new outstanding (`total - paid_amount > 0`), the backend rejects when it exceeds `customers.credit_limit` (considering existing outstanding).

### Role-based discount limits + manager override (server-enforced)
- Backend:
  - Migration: `go_backend_rmt/migrations/202603030000_pos_controls.sql` (role limits + `OVERRIDE_DISCOUNTS`)
  - Enforcement: `go_backend_rmt/internal/services/pos_service.go` (`enforceDiscountLimits`)
  - Manager override token: `go_backend_rmt/internal/utils/override_token.go`, `go_backend_rmt/internal/handlers/auth.go` (`/auth/verify`)
- Flutter:
  - `flutter_app/lib/features/pos/presentation/pages/payment_page.dart` (handles `OVERRIDE_REQUIRED` by prompting manager + reason then retries checkout)

## Partially implemented / follow-ups

### Loyalty earn/redeem + receipts
- Implemented:
  - Redeem: Flutter `payment_page.dart` + backend `pos_service.go` (`RedeemPointsForSale`)
  - Earn: backend `go_backend_rmt/internal/services/sales_service.go` (`AwardPoints` async)
- Follow-up:
  - Ensure printed receipts/invoices display loyalty earned/redeemed amounts consistently (ESC/POS ticket + A4 PDF templates currently do not show points).
