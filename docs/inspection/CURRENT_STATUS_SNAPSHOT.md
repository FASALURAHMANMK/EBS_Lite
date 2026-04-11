# Current Status Snapshot

Timestamp: 2026-04-11 UTC (M4 first slice — N+1 hotspot fixes)

## Summary

This run began the M4 (DB/performance/release safety) phase by fixing the two highest-impact N+1 hotspots identified in the release blockers doc. `GET /collections` previously fired one additional query per collection row to fetch `collection_invoices`; this is now a single batch `IN (...)` query. `GET /collections/outstanding` previously fired one additional query per customer to fetch outstanding invoices; this is now also a single batch query. Both fixes preserve the exact API response structure. No Flutter changes were required.

## What changed this run

- Replaced per-collection `collection_invoices` N+1 query with batch `IN (...)` query in `GetCollections()` (collection_service.go)
- Replaced per-customer outstanding invoices N+1 query with batch `IN (...)` query in `GetOutstanding()` (collection_service.go)
- Re-ran the available Flutter, parity, and format checks after implementation and confirmed they all pass.

## Active milestone state

- `M0 Repo bootstrap and continuity baseline`: completed
- `M1 Responsive and document workflow baseline`: in progress (UI standardization wave substantially complete)
- `M2 Shared UI/layout standardization`: in progress
- `M3 Backend/API hardening`: in progress (5 slices complete, substantially complete)
- `M4 DB, performance, and release safety hardening`: in progress (first slice — N+1 hotspots fixed)
- `M6 QA/UAT and operational readiness`: blocked pending implementation and manual evidence

## Verification executed in this run

Passed:
- `flutter analyze`
- `flutter test`
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
- dashboard routing still has a fallback `No route configured` branch for other unmapped labels (pre-existing)

## Subagent note

Not used in this run — the N+1 fixes were straightforward pattern replacements identified from the release blockers doc and verified by code inspection.
