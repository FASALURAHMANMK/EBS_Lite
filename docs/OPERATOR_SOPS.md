# EBS Lite Operator SOPs

Date: 2026-03-30  
Applies to: SMB Edition launch operations

## 1. POS cashier SOP

Scope:
- open a register
- complete sales
- handle hold/resume and split payment
- reprint receipts
- void with approved override
- understand offline behavior

Daily flow:
1. Confirm the correct location is selected.
2. Open the cash register with the physical opening balance.
3. Verify printer profile and payment methods before the first sale.
4. Scan or search items, attach a customer when needed, and confirm price/discount authority.
5. Use split payment only after verifying the tender breakdown on screen.
6. Use `Hold` only for interrupted checkout. Resume and complete or void before shift end.
7. Reprint from the documented sale/receipt history flow only.
8. If a void or restricted override is required, use the manager step-up approval flow and record the reason.

Offline behavior:
- POS offline checkout is supported only for the flows already backed by reserved numbering and the SQLite outbox.
- Cashiers must not force-close the app while a sale is still queued.
- At connectivity recovery, confirm the outbox queue clears from `Settings > Sync health`.

Evidence to retain:
- one printed or PDF receipt
- one hold/resume example
- one split-payment example
- one override audit example

## 2. Day open / close SOP

Open:
1. Count opening cash physically.
2. Open the register with the counted amount.
3. Confirm training mode is off unless a supervised demo is running.

During shift:
1. Record all cash in and cash out movements immediately.
2. Use tally for spot checks when variance is suspected.

Close:
1. Run the guided day-end flow.
2. Count denomination totals physically.
3. Compare counted cash to expected cash.
4. Review variance before final close.
5. Export or capture the Daily Cash report for the shift pack.
6. Escalate unexplained variance the same day.

## 3. Purchase receiving and return SOP

Receiving:
1. Confirm supplier, location, and purchase reference before receiving.
2. Match delivered quantity to the purchase order or quick-purchase document.
3. Upload supplier invoice or GRN attachment when available.
4. Review serial, batch, or expiry details before posting.
5. Confirm stock is updated in inventory detail after GRN completion.

Returns:
1. Reference the original purchase where possible.
2. Confirm physical quantity and supplier agreement before posting the return.
3. Upload return support documents if provided.
4. Verify supplier-facing balances and stock reflect the return.

## 4. Inventory control SOP

Stock adjustment:
1. Use positive or negative adjustments only with a recorded reason.
2. For serialized or batch-tracked items, verify the exact units being adjusted.
3. Review adjustment history after save to confirm the movement posted correctly.

Stock transfer:
1. Create the transfer from the correct source location.
2. Confirm destination location and quantities.
3. Use approval and completion actions in sequence; do not bypass incomplete transfers.
4. Validate both source and destination stock after completion.

Product setup:
1. Confirm tax, barcode, and pricing before activating a new product.
2. For serialized, batch, or variant-rich items, test one downstream sale before general release.

## 5. Escalation rule

- Operational errors that block sale, purchase, stock, or close workflows are P1 incidents.
- Capture a support bundle and the affected document numbers before escalation.
- Do not edit database records manually outside approved support and rollback procedures.
