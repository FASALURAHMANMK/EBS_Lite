# M6 UAT Test Plan — EBS Lite Release Candidate

Updated: 2026-04-12 UTC
Status: Ready for execution
Milestone: M6 (QA/UAT and operational readiness)
Depends on: M1, M3, M4, M5 (all completed)

---

## 1. Overview

This document defines the structured UAT test plan for the EBS Lite release candidate. It covers all P0/P1 user journeys, defines pass/fail criteria, and maps each scenario to existing automated test coverage gaps.

### UAT Exit Criteria (M6)

ALL of the following must be satisfied for M6 exit:
- Every scenario marked **P0** below passes with no critical failures.
- At least **80% of P1** scenarios pass (documented exceptions acceptable).
- Evidence (screenshots, ledger reports, reconciliation outputs) is attached for every P0 scenario.
- Finance integrity reconciliation (Section 2.1) passes end-to-end with zero unreconciled drift.
- Demo dataset is reset and re-seeded before UAT execution (`./tools/reset_demo_uat.ps1`).

### Test Environment Requirements

- Backend: Go service running with fresh demo dataset
- Flutter: Release build (not debug mode) connected to the test backend
- Network: Online for initial sync; offline testing requires airplane-mode or network block
- Test user: Multiple accounts per role (Admin, Manager, Cashier, Purchaser, Accountant, Inventory, HR, Viewer)

### Demo Dataset Reference

The governed demo dataset provides:
- 1 company (EBS Demo Retail LLC), 3 locations (HQ, Main Store, Secondary Store)
- 8 users across 8 roles (shared password: `DemoPass!234`)
- 60 products, 15 customers, 10 suppliers
- 50 sales documents, 20 purchase/GRN documents
- Financial transactions across all posting types
- Loyalty settings, 3 tiers, 6 employees, 5 workflow requests

---

## 2. P0 Scenarios — Must Pass for Release

### 2.1 Finance Integrity & Reconciliation (GAP-01)

| ID | Scenario | Steps | Expected Result | Evidence Required |
|---|---|---|---|---|
| FIN-01 | POS cash sale → ledger reconciliation | 1. Log in as Cashier at Main Store. 2. Complete a cash sale for 3 products. 3. Navigate to Accounts → General Ledger. 4. Filter to today's date. | GL shows: Debit Cash, Credit Sales Revenue, Credit Tax Payable, Debit COGS, Credit Inventory. Totals match sale receipt. | Screenshot of receipt + GL entries side by side. |
| FIN-02 | Split-payment sale → AR allocation | 1. Log in as Cashier. 2. Attach a credit customer. 3. Complete a sale with split payment (cash + card). 4. Check customer outstanding balance. | Customer AR increased by sale total minus cash tendered. Both payment methods recorded. | Customer detail screen + GL entries. |
| FIN-03 | Collection → AR reduction | 1. Log in as Cashier/Accountant. 2. Record a collection against a customer with outstanding invoices. 3. Check customer outstanding balance. | Outstanding balance reduced by collection amount. GL shows Debit Cash/Bank, Credit AR. | Collection receipt + updated customer balance + GL. |
| FIN-04 | Purchase order → GRN → stock + AP | 1. Log in as Purchaser. 2. Create a PO, approve it. 3. Receive goods (GRN). 4. Check stock-on-hand. 5. Check GL. | Stock increased by received quantities. GL shows Debit Inventory, Debit Tax Receivable, Credit AP. | PO → GRN detail + stock detail + GL entries. |
| FIN-05 | Sale return (credit note) → reversal | 1. Find an existing sale with an invoice. 2. Create a sale return for all items. 3. Check GL and stock. | GL reversal: Debit Sales Revenue + Tax Payable, Credit AR, Debit Inventory, Credit COGS. Stock increased. | Return document + GL + stock movement history. |
| FIN-06 | Purchase return → AP reduction | 1. Create a purchase return against a GRN. 2. Check GL. | GL: Debit AP, Credit Inventory, Credit Tax Receivable. | Return document + GL entries. |
| FIN-07 | Expense recording → ledger impact | 1. Log in as Manager. 2. Record an expense with a reason code. 3. Check GL. | GL shows Debit Expenses, Credit Cash. Expense appears in expense summary report. | Expense record + GL + expense report. |
| FIN-08 | Day-end cash close → variance report | 1. Open a cash register with opening balance. 2. Process at least 2 cash sales. 3. Record a cash tally. 4. Close the day with denomination entry. 5. Review daily cash report. | Report shows expected balance (opening + sales), actual tally, and variance. Session status is "closed". | Register open → sales → tally → close → variance report screenshots. |
| FIN-09 | Accounting reports reconcile to source | 1. Run Trial Balance, P&L, and Balance Sheet. 2. Cross-check totals against individual transaction types (sales, purchases, collections, expenses). | Trial Balance is balanced (debits = credits). P&L net matches revenue minus expenses. Balance Sheet assets = liabilities + equity. | Three report screenshots with reconciliation notes. |
| FIN-10 | Finance Integrity diagnostics page | 1. Navigate to Finance Integrity page. 2. Verify no failed ledger postings or unreconciled items are listed. 3. If any exist, attempt replay/repair. | Page loads cleanly OR any listed items can be replayed successfully with no residual errors. | Screenshot of clean diagnostics page or replay result. |

### 2.2 Auth, Company Bootstrap, & Sessions

| ID | Scenario | Steps | Expected Result | Evidence Required |
|---|---|---|---|---|
| AUTH-01 | Login with company/location context | 1. Log in as Admin. 2. Verify dashboard shows company name and default location. | Dashboard loads with correct company and location. KPIs are visible. | Dashboard screenshot. |
| AUTH-02 | Password reset flow | 1. Log out. 2. Use "Forgot Password" with a registered email. 3. Open the reset link. 4. Set a new password meeting policy. 5. Log in with new password. | Reset email is received with a working link. New password is accepted. Old password is rejected. | Reset email screenshot + successful login screenshot. |
| AUTH-03 | Session management & revocation | 1. Log in from two devices/sessions. 2. From one session, view active sessions. 3. Revoke the other session. 4. Attempt an action from the revoked session. | Revoked session is removed from the list. Revoked session cannot call protected routes (401 or redirect to login). | Session list before/after + revoked session error. |
| AUTH-04 | Role-based UI gating | 1. Log in as Viewer (minimal permissions). 2. Check that Admin, Settings, and role-gated tiles are hidden. 3. Attempt to navigate directly to a restricted route. | Restricted tiles are hidden. Direct navigation is blocked or shows "access denied". | Viewer dashboard + attempted restricted navigation. |

### 2.3 Offline Outbox & Sync

| ID | Scenario | Steps | Expected Result | Evidence Required |
|---|---|---|---|---|
| OFF-01 | Offline POS sale → sync | 1. Log in as Cashier. 2. Go offline (airplane mode). 3. Complete a cash sale. 4. Reconnect. 5. Wait for sync. 6. Verify sale appears in sales history and GL. | Sale queues locally with reserved receipt number. After reconnect, sale syncs without duplicate posting. GL entries appear. | Offline sale receipt + synced sale in history + GL. |
| OFF-02 | Offline collection → sync | 1. Go offline. 2. Record a collection against a customer. 3. Reconnect. 4. Verify collection syncs and AR updates. | Collection queues locally. After sync, customer outstanding balance is reduced correctly. | Offline collection record + updated customer balance after sync. |
| OFF-03 | Offline quick purchase + GRN → sync | 1. Go offline. 2. Create a quick purchase and receive goods (GRN). 3. Reconnect. 4. Verify stock and purchase records. | Purchase and GRN queue locally. After sync, stock is increased and purchase is visible. | Offline purchase/GRN + synced records + stock update. |
| OFF-04 | Sync health monitoring | 1. Create 3+ offline transactions. 2. Reconnect. 3. Navigate to Sync Health page. 4. Verify all items transition from "pending" to "synced". 5. If any failed, attempt retry. | Sync Health page shows correct counts. Failed items can be retried and succeed. | Sync Health page before sync, during sync, and after sync. |

### 2.4 Quick Actions & Dashboard

| ID | Scenario | Steps | Expected Result | Evidence Required |
|---|---|---|---|
| DASH-01 | Quick actions open live workflows | 1. From dashboard, tap each quick action: Sale, Purchase, Collection, Quick Expense. | Each opens a live, functional workflow (not a placeholder or dead-end). | Screenshots of each workflow entry. |
| DASH-02 | Location switching | 1. Switch location from the dashboard shell. 2. Verify KPIs and module data refresh. | Dashboard shows data for the new location. KPIs update. | Dashboard before/after location switch. |
| DASH-03 | No route configured fallback | 1. Navigate to every module from the dashboard drawer/sidebar. | No "No route configured" fallback appears for any active module. | N/A (negative test — log any occurrences). |

---

## 3. P1 Scenarios — Should Pass (80% threshold)

### 3.1 Sales & POS Workflows

| ID | Scenario | Steps | Expected Result |
|---|---|---|---|
| SALE-01 | Quote → sale conversion | 1. Create a quote with items. 2. Print/share the quote. 3. Convert to sale. 4. Verify sale appears in history. | Quote converts cleanly. Sale is visible in history with correct totals. |
| SALE-02 | Hold and resume sale | 1. Start a sale, add items. 2. Hold the sale. 3. Start a new sale. 4. Resume the held sale. 5. Finalize. | Held sale is recoverable with correct items and totals. No data loss. |
| SALE-03 | Sale return with partial quantity | 1. Find a sale with multiple line items. 2. Create a return for only one line item, partial quantity. | Return records correctly. Stock updates for returned items only. AR/credit reflects partial return. |
| POS-01 | Receipt print/preview | 1. Complete a POS sale. 2. Print or preview the receipt. | Receipt shows correct items, totals, tax, company info, and receipt number. |
| POS-02 | Void sale with manager override | 1. Complete a sale. 2. Void the sale as Cashier (requires manager override). 3. Manager approves. | Sale is voided. Stock reverses. GL reverses. Override is logged. |

### 3.2 Purchases & Suppliers

| ID | Scenario | Steps | Expected Result |
|---|---|---|---|
| PUR-01 | PO approval workflow | 1. Create a PO as Purchaser. 2. Submit for approval. 3. Approve as Manager. | PO status transitions from draft → pending → approved. Workflow notification is generated. |
| PUR-02 | Supplier payment recording | 1. Record a payment to a supplier. 2. Check supplier history and GL. | Payment is visible in supplier history. GL shows Debit AP, Credit Cash/Bank. |
| PUR-03 | Supplier detail review | 1. Open a supplier detail page. 2. Verify contact details, financial terms, purchase history, and payment summary. | All data loads correctly. Desktop split-pane shows review panel. Mobile shows stacked view. |
| PUR-04 | Purchase return creation workflow | 1. Find an existing GRN. 2. Create a purchase return against it. 3. Verify stock decreases and supplier-facing documents reflect the return. 4. Verify GL impact (Debit AP, Credit Inventory, Credit Tax Receivable). | Return document saves correctly. Stock decreases for returned items. Supplier history reflects the return. GL entries are correct. |

### 3.3 Inventory Control

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| INV-01 | Product creation with barcode/batch/serial | 1. Create a standard product. 2. Create a serialized product. 3. Create a batch-tracked product. 4. Search for each. | All products are searchable. Serial/batch flags are visible. Products are usable in sales/purchases. |
| INV-02 | Stock adjustment | 1. Post a positive stock adjustment with reason. 2. Post a negative adjustment. 3. Check stock-on-hand and movement history. | Stock quantities update correctly. Movement history shows adjustments with reasons and timestamps. |
| INV-03 | Stock transfer | 1. Create a stock transfer from Main Store to Secondary Store. 2. Approve. 3. Complete. 4. Check quantities at both locations. | Source location stock decreases. Destination increases. Transfer status progresses: draft → approved → completed. |
| INV-04 | Serialized item tracking through sale | 1. Sell a serialized product via POS. 2. Check the sale detail and stock movement history. | Serial number is recorded on the sale line. Stock movement shows issue movement for that serial. |
| INV-05 | Inventory import/export | 1. Download the inventory import template. 2. Populate with valid and invalid product rows. 3. Import. 4. Export current inventory. 5. Compare export to visible data. | Valid rows import; invalid rows fail clearly. Export file opens and matches visible inventory data. |

### 3.4 Customers, Collections, & Loyalty

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| CUS-01 | Customer CRUD with credit limit | 1. Create a customer with credit limit and payment terms. 2. Edit the customer. 3. Check customer detail page. | Customer saves with all fields. Credit limit and terms are visible. Customer appears in search. |
| CUS-02 | Loyalty earn and redeem | 1. Configure loyalty settings. 2. Complete a sale with a loyalty customer. 3. Verify points earned. 4. Redeem points on a subsequent sale. | Points accrue correctly per sale. Redemption reduces the sale total per configured rules. |
| CUS-03 | Customer workbench review | 1. Open Customer Management on desktop. 2. Select a customer from the queue. 3. Verify review pane shows contact details, financial terms, metrics, and credit status. | Desktop split-pane works. Review pane loads without navigation change. Mobile stays stacked. |

### 3.5 Accounting Essentials

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| ACC-01 | Payment voucher creation | 1. Create a payment voucher with balanced debit/credit lines. 2. Save. 3. Check voucher list and ledger. | Voucher appears in list. GL entries match voucher lines. |
| ACC-02 | Chart of Accounts management | 1. Create a new ledger account. 2. Edit its properties. 3. Verify it appears in chart of accounts. | Account saves with correct code, type, and parent. Visible in chart of accounts list. |
| ACC-03 | Accounting period close | 1. Navigate to Accounting Periods. 2. Attempt to close a period with no blockers. 3. Verify closed period blocks new vouchers/postings in its date range. | Period closes successfully. Attempting to post to a closed period is rejected. |
| ACC-04 | Audit log review | 1. Navigate to Audit Logs. 2. Filter by user and date range. 3. Verify entries are present for actions taken during UAT. | Audit log shows entries matching the filtered criteria with timestamps and action details. |
| ACC-05 | Settings management persistence | 1. Update company profile (name, address, tax number). 2. Add/edit a tax profile. 3. Add/edit a payment method. 4. Save numbering sequence. 5. Verify all persist after logout/login. | All settings save correctly and remain effective after re-login. Company info reflects in receipts and reports. |
| ACC-06 | Mid-day cash events during register session | 1. Open a cash register. 2. Record a manual cash-in event with reason. 3. Record a cash-out event. 4. Record a cash tally. 5. Verify expected balance reflects all events. | Expected balance = opening + cash-in - cash-out. Tally shows variance if actual differs. |

### 3.6 Reports

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| REP-01 | Report with filters | 1. Open Sales → Sales Summary report. 2. Apply date range filter. 3. Run the report. | Report renders with results matching the date range. Filters are visible and functional. |
| REP-02 | Report export/share | 1. Run any report. 2. Export as PDF or Excel. 3. Open the exported file. | Export completes without dead-end navigation. File opens with correct content. |
| REP-03 | Inventory valuation report | 1. Run the stock valuation report. 2. Cross-check a sample product's value against its cost price × quantity. | Report values match expected calculations for sampled products. |

### 3.7 HR & Workflow

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| HR-01 | Employee attendance | 1. Check in as an employee. 2. Check out. 3. Verify attendance record. | Attendance record shows correct check-in/check-out times. |
| HR-02 | Leave request workflow | 1. Submit a leave request as employee. 2. Approve as Manager. 3. Verify leave record updates. | Leave request status transitions from pending → approved. Leave balance updates. |
| HR-03 | Payroll cycle | 1. Create a payroll cycle. 2. Mark it as paid. 3. Open a payslip. | Cycle completes. Payslip is accessible to authorized users. |
| WF-01 | Workflow approval/rejection | 1. Open workflow request list. 2. Approve one request, reject another. 3. Verify status updates and notifications. | Approved request shows "approved", rejected shows "rejected". Notifications reflect the actions. |
| WF-02 | Notification read/unread management | 1. Trigger notifications (from workflow actions or system events). 2. Mark one notification as read. 3. Mark all remaining as read in bulk. 4. Verify unread count updates to zero. | Individual and bulk read operations work. Unread count accurately reflects unread notifications. |

### 3.8 Bulk Import/Export

| ID | Scenario | Steps | Expected Result |
|---|---|---|
| BIO-01 | Customer import | 1. Download the import template. 2. Populate with valid and invalid rows. 3. Import. 4. Check results. | Valid rows import successfully. Invalid rows fail with clear error messages. Imported records are searchable. |
| BIO-02 | Supplier export | 1. Export suppliers to Excel. 2. Open the file. 3. Compare with visible supplier list. | Export file opens. Data matches the supplier list. |

---

## 4. P2 Scenarios — Nice to Have (document if skipped)

| ID | Scenario | Notes |
|---|---|---|
| P2-01 | Warranty-linked sale record review | Verify warranty details are retrievable and printable. |
| P2-02 | Support bundle generation | Generate a support bundle and verify it contains outbox health and backend diagnostics. |
| P2-03 | Bank statement line matching | Enter a bank statement line, match it manually, verify reconciliation status. |
| P2-04 | Printer configuration (ESC/POS) | Configure a thermal printer profile and test receipt printing. |
| P2-05 | Multi-location offline master-data sync | Sync offline while switching locations; verify master data updates correctly. |

---

## 5. Test Coverage Mapping

### Existing Flutter test suite vs. UAT scenarios

| UAT Section | Scenarios | Count | Flutter Automated Tests | Go Backend Tests | Gap |
|---|---|---|---|---|---|
| 2.1 Finance Integrity (FIN-01 to FIN-10) | 10 P0 | 10 | 0 | Service tests for ledger posting, voucher creation, idempotency | **Flutter: full manual** |
| 2.2 Auth/Sessions (AUTH-01 to AUTH-04) | 4 P0 | 4 | 2 partial (admin RBAC, drawer routing) | Auth service tests | **Flutter: mostly manual** |
| 2.3 Offline Outbox (OFF-01 to OFF-04) | 4 P0 | 4 | 0 | Idempotency tests for collection, expense, sales, purchase, payment services | **Flutter: full manual** |
| 2.4 Dashboard (DASH-01 to DASH-03) | 3 P0 | 3 | 1 partial (drawer routing) | N/A | **Flutter: mostly manual** |
| 3.1 Sales/POS (SALE-01 to POS-02) | 5 P1 | 5 | 0 | Sales service idempotency and batching tests | **Flutter: full manual** |
| 3.2 Purchases (PUR-01 to PUR-04) | 4 P1 | 4 | 0 | Purchase service idempotency tests | **Flutter: full manual** |
| 3.3 Inventory (INV-01 to INV-05) | 5 P1 | 5 | 0 | N/A (mostly UI) | **Flutter: full manual** |
| 3.4 Customers (CUS-01 to CUS-03) | 3 P1 | 3 | 1 label check (navigation) | Collection service idempotency | **Flutter: mostly manual** |
| 3.5 Accounting (ACC-01 to ACC-06) | 6 P1 | 6 | 0 | Voucher service, ledger service tests | **Flutter: full manual** |
| 3.6 Reports (REP-01 to REP-03) | 3 P1 | 3 | 1 partial (repository URL routing) | Report handler tests | **Flutter: mostly manual** |
| 3.7 HR/Workflow (HR-01 to WF-02) | 5 P1 | 5 | 1 partial (workflow RBAC) | Workflow service tests | **Flutter: mostly manual** |
| 3.8 Bulk Import/Export (BIO-01 to BIO-02) | 2 P1 | 2 | 0 | Upload service tests | **Flutter: full manual** |
| 4. P2 Scenarios (P2-01 to P2-05) | 5 P2 | 5 | 0 | N/A | **Full manual** |

### Summary

- **Total UAT scenarios**: 59 (22 P0, 32 P1, 5 P2)
- **P0 scenarios with any Flutter automated test backing**: 1 of 22 (partial — drawer routing)
- **P1 scenarios with any Flutter automated test backing**: 3 of 32 (partial — navigation label, workflow RBAC, repository routing)
- **Scenarios requiring full manual Flutter execution**: 55 of 59
- **Go backend has meaningful automated tests** for: ledger posting, voucher validation, idempotency (collections, expenses, sales, purchases, payments), auth, uploads, and workflow services. These reduce but do not eliminate the need for Flutter-level UAT.

---

## 6. Execution Protocol

### Pre-execution checklist
- [ ] Run `./tools/reset_demo_uat.ps1` to reset and re-seed the database
- [ ] Verify backend is running and accessible
- [ ] Verify Flutter release build connects to the test backend
- [ ] Confirm all 8 test user accounts are active with correct roles
- [ ] Prepare a test results spreadsheet or document with columns: Scenario ID, Status (Pass/Fail/Blocked), Tester, Date, Evidence Link, Notes

### Execution order (recommended)
1. **Day 1**: AUTH-01 through AUTH-04 (auth baseline), then DASH-01 through DASH-03
2. **Day 2**: FIN-01 through FIN-10 (finance integrity — the critical P0 set)
3. **Day 3**: OFF-01 through OFF-04 (offline outbox — requires network toggling)
4. **Day 4**: SALE-01 through POS-02, PUR-01 through PUR-03
5. **Day 5**: INV-01 through INV-04, CUS-01 through CUS-03
6. **Day 6**: ACC-01 through ACC-04, REP-01 through REP-03
7. **Day 7**: HR-01 through HR-03, WF-01, BIO-01 through BIO-02, P2 scenarios

### Pass/Fail/Blocked definitions
- **Pass**: All expected results are observed; evidence is attached.
- **Fail**: One or more expected results are not met; defect is logged with reproduction steps.
- **Blocked**: Scenario cannot be executed due to environment issues, missing data, or dependency on a failed scenario.

---

## 7. Defect Logging Template

For every failed scenario, log:

```
Defect ID: DEF-<sequential number>
Scenario: <scenario ID, e.g., FIN-03>
Title: <brief description>
Severity: Critical / Major / Minor
Steps to reproduce: <exact steps taken>
Expected: <what should have happened>
Actual: <what actually happened>
Evidence: <screenshot/log excerpt>
Logged by: <tester>
Date: <date>
Status: Open / Investigating / Fixed / Won't Fix
```

---

## 8. M6 Exit Sign-off

Upon completion, this section must be filled:

| Field | Value |
|---|---|
| UAT execution date range | |
| Tester(s) | |
| P0 scenarios: Pass / Fail / Blocked | |
| P1 scenarios: Pass / Fail / Blocked | |
| P2 scenarios: Pass / Fail / Skipped | |
| Total defects logged | |
| Critical defects remaining | |
| Finance integrity reconciliation result | |
| Demo dataset reset confirmed | |
| M6 exit decision | Pass / Fail / Conditional Pass (with conditions listed) |
| Signed by | |
| Date | |
