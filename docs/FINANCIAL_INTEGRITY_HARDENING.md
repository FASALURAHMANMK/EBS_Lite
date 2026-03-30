# Financial Integrity Hardening

Date: 2026-03-30

## Purpose

This document records how finance-sensitive operational flows are now classified and monitored for SMB release readiness.

The implementation goal is:

- operational truth is created inside the primary transaction
- required secondary finance side effects are never silently dropped
- any delayed side effect is queued in the backend finance-integrity outbox
- accounting/admin users can detect and replay failures from the Flutter Accounts area

## Side-effect classification

### Must be atomic with the source transaction

- POS checkout and sales document creation
- held sale creation
- void sale document creation
- purchase creation
- goods receipt stock movement
- collection document creation and invoice allocation
- expense document creation
- supplier payment document creation
- sale return stock reversal
- purchase return stock reversal
- numbering allocation for persisted documents
- audit logging for voids and returns

### Guaranteed async through backend transactional outbox

- sale ledger posting
- purchase ledger posting
- collection ledger posting
- expense ledger posting
- supplier payment ledger posting
- sale return ledger posting
- purchase return ledger posting
- sale cash register event posting
- purchase cash register event posting
- collection cash register event posting
- expense cash register event posting
- supplier payment cash register event posting
- loyalty point award on sale
- loyalty points redemption finalization on sale
- coupon redemption finalization on sale
- raffle issuance on sale

### Best-effort but observable

- immediate replay attempt after commit
- operator-triggered replay from the Finance Integrity page

These are best-effort only in timing, not in durability: if the immediate replay fails, the outbox row remains visible and replayable.

## Diagnostics and repair

The Flutter Accounts module now includes a `Finance Integrity` page.

It exposes:

- finance outbox backlog by status and event type
- last error text for failed items
- recent missing ledger postings detected by reconciliation query
- `Replay Outbox` action
- `Repair Missing Ledger` action

Permissions:

- read diagnostics: `VIEW_LEDGER`
- replay or repair: `MANAGE_SETTINGS`

## Reconciliation scope

Current missing-ledger diagnostics cover:

- completed sales
- purchases
- collections
- expenses
- supplier payments
- sale returns
- purchase returns

## Idempotency and retry notes

- existing offline-first flows remain idempotent for POS, purchases, collections, and expenses
- supplier payments now also accept idempotency headers
- ledger postings remain reference-idempotent
- loyalty award, loyalty redemption, coupon redemption, and raffle issuance were hardened to avoid duplicate side effects during replay

## Operator guidance

When diagnostics show failures:

1. Open `Accounts > Finance Integrity`
2. Review failed outbox items and missing-ledger documents
3. Use `Replay Outbox`
4. If a historical document has no ledger rows, use `Repair Missing Ledger`
5. If the same item keeps failing, capture the error text and share it with support
