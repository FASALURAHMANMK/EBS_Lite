# Accounting Module User Manual

## Purpose

This document explains how the current accounting module works in `flutter_app/` and `go_backend_rmt/`, what each accounting page does, which ledgers are used, and how operational transactions flow into the books.

The implementation is now aligned to a standard small-business double-entry pattern:

- sales post revenue, tax, receivables/cash, and cost of goods sold
- purchases post inventory, recoverable tax, and payables/cash
- collections clear receivables
- supplier payments clear payables
- expenses reduce cash and hit expense ledgers
- returns reverse both the operational stock movement and the accounting entry

This improves audit readiness, but it is **not a substitute for a local accountant or tax advisor**. Jurisdiction-specific filing layouts, statutory chart-of-accounts mappings, and final tax return sign-off still need a local finance review.

## Accounting Pages

### 1. Accounts Home

File: `flutter_app/lib/features/accounts/presentation/pages/accounting_page.dart`

This is the entry point for the accounting area. It now exposes:

- `Cash Register`
- `Day Open/Close`
- `Expenses`
- `Vouchers`
- `Ledgers`
- `Accounting Reports`
- `Audit Logs`

### 2. Cash Register

File: `flutter_app/lib/features/accounts/presentation/pages/cash_register_page.dart`

Use this page to manage the live drawer/session for a location.

What it does:

- opens a register with an opening balance
- shows the current expected balance
- records manual cash in/cash out events
- records cash tallies during the day
- enables or disables training mode
- closes or force-closes the register

Why it matters:

- creates an auditable day/session cash trail
- supports day-end reconciliation against counted cash
- separates real trading from training/demo activity

### 3. Day End

File: `flutter_app/lib/features/accounts/presentation/pages/day_end_flow_page.dart`

This is the guided day-close flow.

What it does:

- prompts the cashier/accountant to count notes and coins
- compares counted cash to expected cash
- shows variance before closing
- opens the Daily Cash report before final close
- closes the session with denomination detail

Why it matters:

- supports daily cash reconciliation
- highlights shortages/overages for audit follow-up
- provides a clean cashier/day close process

### 4. Expenses

Entry point from Accounts Home: `Expenses`

This page is part of the accounting flow even though it lives in the expenses feature area.

What it does:

- records day-to-day operational expenses
- reduces cash when an expense is paid
- posts the expense into the expense ledger

Typical use cases:

- petty cash spending
- utilities
- office/admin purchases
- transport or maintenance costs

### 5. Vouchers

File: `flutter_app/lib/features/accounts/presentation/pages/vouchers_page.dart`

This page is for manual single-counterpart vouchers.

What it does:

- creates `payment` vouchers
- creates `receipt` vouchers
- lists existing vouchers
- filters by date and type

Important rule:

- `journal` vouchers are intentionally blocked now because the current API only stores one account plus one amount. A true journal requires balanced multi-line debit/credit rows. Allowing a fake one-line journal would be misleading for audit and financial reporting.

Use vouchers for:

- manual cash receipt against an account
- manual cash payment against an account
- controlled one-off adjustments with a cash counterpart

### 6. Ledgers

File: `flutter_app/lib/features/accounts/presentation/pages/ledgers_page.dart`

This page shows the chart-of-accounts balances available to the accounting module.

What it does:

- lists ledger balances by account code/name/type
- lets the user search by code, name, type, or account id
- opens ledger entry drill-down

### 7. Ledger Entries

File: `flutter_app/lib/features/accounts/presentation/pages/ledger_entries_page.dart`

This is the detailed movement screen for one ledger.

What it does:

- shows dated debit/credit rows
- shows running balance
- exposes linked voucher, sale, or purchase references when available
- filters by date range

Use it for:

- tracing one posting back to the source document
- investigating balance movements
- audit support and period-end review

### 8. Audit Logs

File: `flutter_app/lib/features/accounts/presentation/pages/audit_logs_page.dart`

This page shows change/audit records.

What it does:

- lists user actions and record changes
- supports filtering for investigation
- helps explain who changed what and when

Use it for:

- stock adjustment review
- cash movement review
- force-close review
- override and exception follow-up

### 9. Finance Integrity

File: `flutter_app/lib/features/accounts/presentation/pages/finance_integrity_page.dart`

What it does:

- shows guaranteed async finance side effects queued in the backend outbox
- shows failed ledger/cash/loyalty/coupon/raffle side effects with error text
- shows recent documents missing ledger postings
- allows authorized admins to replay failed finance outbox items
- allows authorized admins to enqueue and repair missing ledger postings

Why it matters:

- removes silent accounting drift
- gives supportable diagnostics when async side effects fail
- makes reconciliation issues visible to accounting/admin users without database access

### 10. Accounting Reports

Now reachable from Accounts Home and implemented through the reports module.

Relevant files:

- `flutter_app/lib/features/reports/presentation/report_categories.dart`
- `flutter_app/lib/features/reports/presentation/pages/report_category_page.dart`
- `flutter_app/lib/features/reports/presentation/pages/report_viewer_page.dart`

Reports available:

- Daily Cash
- Expenses Summary
- Income vs Expense
- General Ledger
- Trial Balance
- Profit & Loss
- Balance Sheet
- Outstanding
- Top Performers

These are the period-end review screens for finance users.

## Ledgers Present and Why They Exist

The backend seeds a minimal accounting structure in `go_backend_rmt/internal/services/accounting_defaults.go`.

### Asset Ledgers

- `1000 Cash`  
  Tracks physical cash and cash drawer movement.

- `1010 Bank`  
  Tracks non-cash collections and payments that settle to bank.

- `1100 Accounts Receivable`  
  Tracks customer dues, customer credit created by unpaid sales, and sale-return credit notes.

- `1200 Inventory`  
  Tracks inventory value carried on hand.

- `2200 Tax Receivable`  
  Tracks purchase/input tax that can be claimed or offset.

### Liability Ledgers

- `2000 Accounts Payable`  
  Tracks supplier dues and supplier credits.

- `2100 Tax Payable`  
  Tracks sales/output tax collected and due to the tax authority.

### Income and Expense Ledgers

- `4000 Sales Revenue`  
  Tracks net sales before tax.

- `5000 Cost of Goods Sold`  
  Tracks inventory cost recognized when goods are sold. This is essential for a proper gross profit calculation.

- `6000 Expenses`  
  Tracks operating expenses paid outside inventory purchases.

## Standard Transaction Flow

### A. POS Sale / Invoice

Source flow:

- POS checkout or sale creation

Operational result:

- stock quantity decreases
- cash and/or customer outstanding updates

Ledger result:

- Debit `Cash` for paid portion
- Debit `Accounts Receivable` for unpaid portion
- Credit `Sales Revenue` for net sales
- Credit `Tax Payable` for output tax
- Debit `Cost of Goods Sold`
- Credit `Inventory`

Why this is correct:

- it separates revenue from tax
- it recognizes inventory consumption
- it produces a usable gross profit figure in Profit & Loss

### B. Customer Collection

Source flow:

- collections module

Ledger result:

- Debit `Cash` or `Bank`
- Credit `Accounts Receivable`

Why:

- collection clears an existing customer balance; it is not new revenue

### C. Purchase / GRN

Source flow:

- purchase creation / goods receipt

Ledger result:

- Debit `Inventory`
- Debit `Tax Receivable`
- Credit `Cash` for immediate payment
- Credit `Accounts Payable` for unpaid portion

Why:

- inventory is capitalized
- input tax is separated for reporting/recovery

### D. Supplier Payment

Source flow:

- payment to supplier

Ledger result:

- Debit `Accounts Payable`
- Credit `Cash` or `Bank`

Why:

- payment settles a liability; it is not a new expense when the item was already booked through purchases

### E. Expense

Source flow:

- expense module

Ledger result:

- Debit `Expenses`
- Credit `Cash`

Why:

- direct operating costs should hit the expense ledger immediately when paid

### F. Sale Return

Source flow:

- sales return module

Current accounting treatment:

- treated as a **credit note / customer credit** flow, not an automatic cash refund

Ledger result:

- Debit `Sales Revenue`
- Debit `Tax Payable`
- Credit `Accounts Receivable`
- Debit `Inventory`
- Credit `Cost of Goods Sold`

Why:

- reverses the sale and related tax
- returns stock value to inventory
- reverses the cost recognized on the original sale

Operational note:

- because the current return flow reduces the original sale’s settled amount, the return behaves like customer credit unless a separate cash payout is processed

### G. Purchase Return

Source flow:

- purchase return module

Current accounting treatment:

- treated as a **supplier credit** flow

Ledger result:

- Debit `Accounts Payable`
- Credit `Inventory`
- Credit `Tax Receivable`

Why:

- inventory leaves the business
- recoverable input tax is reversed
- supplier credit/liability position is adjusted

### H. Voucher

Source flow:

- manual payment/receipt voucher

Ledger result:

- `payment`: Debit selected account, Credit `Cash`
- `receipt`: Debit `Cash`, Credit selected account

Why:

- this is a controlled manual correction / settlement tool with a cash counterpart

## Tax and Audit Readiness Notes

### Tax logic now supported better

- output tax is separated from sales revenue
- input tax is separated from inventory purchases
- sale returns reverse output tax
- purchase returns reverse input tax

This structure is much closer to what VAT/GST filing and audit workpapers need.

### Audit logic already supported

- cash register open/close/tally events
- training mode event trail
- force-close trail
- stock adjustment trail
- voucher list and ledger drill-down
- audit log viewer

### Reports finance users should rely on

- `Trial Balance` for period balance review
- `Profit & Loss` for operating result review
- `Balance Sheet` for financial position review
- `General Ledger` for transaction tracing
- `Daily Cash` for cashier reconciliation
- `Outstanding` for customer and supplier settlement follow-up
- `Finance Integrity` for queued side effects and missing-ledger diagnostics

## Operational Guidance for Users

### Daily routine

1. Open cash register with opening balance.
2. Run POS, purchases, collections, and expenses as normal.
3. Record any manual cash movement immediately.
4. Use Day End to count cash and review variance.
5. Review Daily Cash report and close the register.

### Period-end routine

1. Check `Outstanding`.
2. Review `Trial Balance`.
3. Investigate unusual ledger balances.
4. Review `Profit & Loss` and `Balance Sheet`.
5. Export tax and ledger reports for accountant review.

## Current Boundaries / Important Caveats

- Multi-line manual journal vouchers are not implemented yet, so one-line “journal” creation is blocked on purpose.
- Sale returns currently behave as credit notes unless a separate refund/payment process is used.
- The seeded chart of accounts is intentionally minimal; many businesses will still want extra ledgers such as discounts, freight, payroll expense, bank charges, retained earnings, and tax control subaccounts.
- Jurisdiction-specific return boxes, filing labels, and statutory mappings are not hard-coded in this module; they should be validated locally before final filing.

## Summary

The accounting module is now suitable for a practical SME workflow:

- operations and accounting are linked
- inventory costing is recognized in sales
- returns reverse both stock and accounting impact
- tax is separated into payable and receivable buckets
- audit trails exist for cash and control-sensitive actions

For a full production rollout, the next finance-focused enhancement should be:

1. true multi-line journal vouchers
2. richer chart-of-accounts management
3. jurisdiction-specific tax return mapping
4. a dedicated refund/payout workflow for sale returns
