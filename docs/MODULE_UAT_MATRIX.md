# EBS Lite Module UAT Matrix

Date: 2026-03-30
Dataset prerequisite: use the governed demo dataset defined in `RELEASE_READINESS_PLAN.md`

## UAT rules

- All scenarios below apply to the Flutter launch surface unless stated otherwise.
- A failed scenario in a core financial or stock flow is a release blocker.
- Evidence should be stored as screenshots, exported reports, or signed operator notes in the release workspace used by the team.

| Module | Scenario ID | UAT scenario | Expected result | Severity if failed |
|---|---|---|---|---|
| Auth and bootstrap | AUTH-01 | Login with valid credentials and verify `/me`-backed profile loads | User reaches dashboard, company and location context load correctly | Blocker |
| Auth and bootstrap | AUTH-02 | Request password reset using deployed frontend URL configuration | Reset request succeeds and generated link targets real frontend host | Blocker |
| Auth and bootstrap | AUTH-03 | Revoke an active device session and confirm access is cut off | Session disappears from list and revoked device cannot continue using protected routes | High |
| Dashboard and location shell | DASH-01 | Switch locations from dashboard shell | KPIs and module data refresh to the selected location | Blocker |
| Dashboard and location shell | DASH-02 | Open each quick action from dashboard | Every quick action opens a live workflow, not a placeholder | Blocker |
| Dashboard and location shell | DASH-03 | Validate notification badge and sync state after a queued transaction sync | Badge/count and sync indicators refresh without app restart | High |
| POS and sales | POS-01 | Complete an online cash sale from product scan to receipt | Sale posts, stock decrements, receipt data is available, ledger impact reconciles | Blocker |
| POS and sales | POS-02 | Complete a split-payment sale with attached customer | Allocation is stored correctly and invoice detail matches tender split | Blocker |
| POS and sales | POS-03 | Hold and resume a sale, then finalize it | Held sale is recoverable and final sale uses the correct totals and numbering | High |
| POS and sales | POS-04 | Create a quote and convert it to a sale | Quote converts cleanly and resulting sale appears in history and detail pages | High |
| POS and sales | POS-05 | Create a sale return from an existing invoice | Return updates stock, sale history, and accounting behavior per the accounting manual | Blocker |
| POS and sales | POS-06 | Perform an offline checkout using reserved numbering, then sync | Offline sale queues locally and syncs once online without duplicate posting | Blocker |
| Purchases and suppliers | PUR-01 | Create a purchase order and approve it | PO is saved, visible in list/detail, and approval state updates correctly | High |
| Purchases and suppliers | PUR-02 | Receive goods against a purchase order | GRN increases stock and purchase detail reflects received quantities | Blocker |
| Purchases and suppliers | PUR-03 | Run quick purchase plus GRN while offline if supported, then sync | Queued purchase syncs back once online and stock/cost outcomes remain correct | Blocker |
| Purchases and suppliers | PUR-04 | Create a purchase return | Stock and supplier-facing documents reflect the return correctly | Blocker |
| Purchases and suppliers | PUR-05 | Record a supplier payment | Payment is saved and visible in supplier/payment history and accounting impact is traceable | High |
| Inventory control | INV-01 | Create a new product with barcode, tax, and price details | Product becomes searchable and usable in downstream sale/purchase flows | Blocker |
| Inventory control | INV-02 | Post a positive and negative stock adjustment | Stock quantities and movement history update correctly with reasons and auditability | Blocker |
| Inventory control | INV-03 | Create, approve, and complete a stock transfer | Source and destination quantities update correctly and transfer status progresses properly | Blocker |
| Inventory control | INV-04 | Validate serialized or batch-tracked sale and return | Item tracking remains consistent across issue and receive movements | Blocker |
| Inventory control | INV-05 | Import inventory from template and export current inventory | Valid import succeeds, invalid data is rejected clearly, export matches visible data | High |
| Customers, collections, loyalty, warranty | CUS-01 | Create/edit a customer with credit controls | Customer appears in search/detail and settings persist | High |
| Customers, collections, loyalty, warranty | CUS-02 | Record a collection against outstanding invoices | Outstanding balance reduces correctly and collection remains traceable | Blocker |
| Customers, collections, loyalty, warranty | CUS-03 | Queue a collection offline and sync later | Outbox item syncs once connectivity returns without duplicate settlement | Blocker |
| Customers, collections, loyalty, warranty | CUS-04 | Earn and redeem loyalty points in documented UI flows | Points accrue and redeem according to configured rules and reserves | High |
| Customers, collections, loyalty, warranty | CUS-05 | View warranty-linked sale/customer records | Warranty details are retrievable and printable/shareable where documented | Medium |
| Accounting essentials | ACC-01 | Open a cash register with opening balance | Register opens successfully and expected balance is visible | Blocker |
| Accounting essentials | ACC-02 | Record cash in/out and tally during the day | Events are stored and reflected in expected balance calculations | High |
| Accounting essentials | ACC-03 | Close the day using denomination entry and variance review | Day-end close completes and daily cash report reflects the session | Blocker |
| Accounting essentials | ACC-04 | Create receipt and payment vouchers | Voucher list and ledger drill-down show the new entries correctly | High |
| Accounting essentials | ACC-05 | Review ledgers, trial balance, P&L, and balance sheet after seeded transactions | Reports reconcile to the underlying seeded sales, purchases, collections, and expenses | Blocker |
| Reports | REP-01 | Open each report category and run at least one report with filters | Reports render successfully and filter results are coherent | High |
| Reports | REP-02 | Export or share PDF/Excel outputs from representative reports | Export/share action completes without dead-end navigation | High |
| Reports | REP-03 | Reconcile sales, stock, and tax reports against source transactions | Report totals match source documents in seeded data | Blocker |
| HR core | HR-01 | Create or edit employee and department/designation records | Employee and org setup data saves correctly and remains visible | Medium |
| HR core | HR-02 | Check in/check out and submit/approve leave | Attendance and leave records update correctly with permissions enforced | Medium |
| HR core | HR-03 | Create payroll, mark paid, and open a payslip | Payroll cycle completes and payslip is accessible to authorized users | High |
| Workflow and notifications | WF-01 | Open workflow request list and approve one pending request | Status updates correctly and only authorized users can approve | High |
| Workflow and notifications | WF-02 | Reject a workflow request and confirm notification visibility | Rejection is persisted and related notification behavior is consistent | Medium |
| Workflow and notifications | WF-03 | Mark notifications read individually and in bulk | Unread count updates accurately | Medium |
| Admin and settings | ADM-01 | Create a user, assign a role, and verify restricted UI behavior | Permissions enforce correct visibility/action blocking | Blocker |
| Admin and settings | ADM-02 | Update company, tax, payment method, printer, and numbering settings | Settings save correctly and remain effective in downstream flows | High |
| Admin and settings | ADM-03 | Generate a support bundle and review sync-health page | Bundle/share flow works and outbox data is visible to support users | Medium |
| Bulk I/O | BIO-01 | Import customers using template and confirm validation behavior | Valid rows import, invalid rows fail clearly, resulting records are searchable | Medium |
| Bulk I/O | BIO-02 | Import suppliers and export suppliers/customers | Exports match visible data and permission checks are enforced | Medium |
| Limited web office shell | WEB-01 | Login and open dashboard, inventory, sales, purchases, and accounting pages intended for demo | Pages render and route without broken navigation, with scope clearly presented as limited | Medium |
| Limited web office shell | WEB-02 | Verify no demo or sales script claims web parity with Flutter | Demo material and operator notes describe web as secondary office shell only | High |
