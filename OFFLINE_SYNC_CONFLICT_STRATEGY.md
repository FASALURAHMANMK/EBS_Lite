# Offline sync conflict strategy (baseline)

This repo uses an offline outbox (queue + replay). To keep stock/cash correct:

- **Server-authoritative totals:** inventory quantities, invoice totals, and cash totals are computed and persisted by the backend. After a successful sync, the client should refresh dashboards/lists from the server.
- **Idempotent writes:** critical write endpoints accept `Idempotency-Key` (or `X-Idempotency-Key`). Retries must reuse the same key so the server can return the original record instead of creating a duplicate.
- **Stable identifiers:** create/write endpoints must return a stable identifier (`sale_id`, `purchase_id`, `collection_id`, etc.) so the client can reconcile local queued work with the server record.
- **Operator recovery:** failed/queued items are visible in **Settings → Sync health** with actions to retry, discard, or export a debug bundle for support.

