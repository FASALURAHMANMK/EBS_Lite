# Execution Ledger

Last updated: 2026-04-11 UTC (M4 first slice — N+1 hotspot fixes)

## Completed

- Continued the existing milestone workflow without restarting discovery.
- Read the NEXT_RUN_PROMPT.md and required continuity docs.
- Implemented the M4 first slice — N+1 hotspot fixes:
  - **`GET /collections` N+1**: Replaced per-collection `collection_invoices` query with a single batch `IN (...)` query. For a list of N collections, this reduces N+1 queries to 2 queries total.
  - **`GET /collections/outstanding` N+1**: Replaced per-customer outstanding invoices query with a single batch `IN (...)` query. For a list of N customers with balances, this reduces N+1 queries to 2 queries total.
  - Both fixes use the same pattern: collect IDs during the main query scan, then batch-load all related rows in a second query with an `IN` clause, and map results back using an index map.
  - No API contract changes — the response structure is identical.
  - Re-ran Flutter checks (analyze, test) and API parity — all pass.
  - Attempted Go quality gates — Go toolchain unavailable in this environment.

## In progress

- M4 (DB/performance/release safety) — first slice complete (N+1 hotspots in collection service fixed)

## Blocked

- manual release-candidate UAT evidence
- final release gate
- Go quality gates in this environment (toolchain unavailable)

## Pending

- remaining N+1 patterns (if any discovered through profiling)
- outbox claim/idempotency guarantees (currently application-level only)
- migration hygiene review (base migration contains duplicate DDL blocks)
- dashboard `No route configured` fallback — add missing routes

## Next recommended action

Continue M4:
- outbox claim/idempotency review (currently application-level safeguards only)
- or migration hygiene review

## Last updated scope

M4 first slice — N+1 hotspot fixes:
- batch-loaded `collection_invoices` in `GetCollections()` (was N+1, now 2 queries)
- batch-loaded outstanding invoices in `GetOutstanding()` (was N+1, now 2 queries)
- no API contract changes — response structure identical

## Subagent record

Not used in this run — the N+1 fixes were straightforward pattern replacements identified from the release blockers doc and verified by code inspection.

## Milestone mapping

| Workstream | Milestone |
|---|---|
| continuity and docs baseline | M0 |
| responsive/document audit | M1 |
| shared document standard rollout | M2 |
| backend/API/runtime hardening | M3 (substantially complete) |
| DB/performance/release safety | M4 (in progress — first slice) |
| UAT and release gate | M6, M7 |
