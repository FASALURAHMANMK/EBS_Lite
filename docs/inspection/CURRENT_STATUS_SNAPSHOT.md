# Current Status Snapshot

Timestamp: 2026-04-11 UTC (M4 second slice — outbox idempotency hardening)

## Summary

This run continued the M4 (DB/performance/release safety) phase by hardening the outbox idempotency guarantees. The SQLite outbox table now has a unique index on `idempotency_key`, the `enqueue()` method checks for existing items with the same key before inserting, and a `ConflictAlgorithm.replace` strategy provides defense in depth. The backend already implements server-side idempotency with unique constraints and retry-on-conflict logic for all critical endpoints (collections, sales, purchases, expenses, payments, vouchers, POS checkout, bank statements). The Flutter-side fixes ensure the client doesn't send duplicate requests unnecessarily.

## What changed this run

- Added duplicate detection to `enqueue()` in `outbox_store.dart` — returns existing ID if same idempotency key is already pending/queued
- Added `ConflictAlgorithm.replace` to the insert as defense in depth
- Added unique index `idx_outbox_idempotency_key ON outbox(idempotency_key)` via DB version upgrade (v1 → v2) in `outbox_db.dart`
- Added `onUpgrade` migration handler for existing installations
- Verified backend idempotency implementation across all critical endpoints
- Re-ran the available Flutter, parity, and format checks after implementation and confirmed they all pass.

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress (UI standardization wave substantially complete)
- `M2 Shared UI/layout standardization`: in progress
- `M3 Backend/API hardening`: substantially complete (5 slices)
- `M4 DB, performance, and release safety hardening`: in progress (second slice — outbox idempotency hardened)
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Verification executed in this run

Passed:
- `flutter analyze`
- `flutter test`
- `dart format --set-exit-if-changed .` (on changed files)
- `python3 tools/api_parity_check.py --out tools/api_parity_report.md`

Unverified in this environment:
- `go test ./...`
- `go vet ./...`
- `gofmt -l .`

Reason:
- `go` and `gofmt` were not installed on PATH in this session

## Verified blockers still open

- manual release-candidate UAT sign-off
- missing `ebs_lite_win/Requirements.txt`
- upload authorization — **resolved**
- password reset delivery — **hardened**
- settings permission seeding — **reviewed and hardened**
- outbox idempotency — **hardened in this run** (unique index + duplicate detection + conflict strategy)
- N+1 hotspots — **fixed in previous run** (collection service batch loading)
- dashboard routing still has a fallback `No route configured` branch for other unmapped labels (pre-existing)

## Subagent note

Not used in this run — the outbox idempotency review was a code investigation task. The full outbox implementation was reviewed manually, gaps were identified, and fixes were implemented directly.
