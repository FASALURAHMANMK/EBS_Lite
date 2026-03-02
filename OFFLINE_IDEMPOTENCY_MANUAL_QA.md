# Offline outbox idempotency — manual QA

Goal: prove queued writes can be retried without creating duplicates.

## Pre-req

- Backend running and reachable.
- Flutter app logged in with a selected location.
- Open **Settings → Sync health** to observe the outbox queue.

## POS checkout (sale)

1. Turn network **OFF** (airplane mode or disable Wi‑Fi).
2. Create a POS checkout (add 1 item, complete payment).
3. Confirm the app indicates it was queued for sync.
4. In **Settings → Sync health**, confirm a `pos_checkout` item exists (status `queued`/`failed`).
5. Turn network **ON**.
6. While the outbox is syncing, briefly toggle network OFF/ON once to force a retry.
7. Verify:
   - Only **one** sale exists in Sales history for that checkout.
   - The outbox item disappears after a successful sync.

## Purchases quick create

1. Turn network **OFF**.
2. Create a “quick purchase” with 1 item.
3. Confirm it queues for sync.
4. Turn network **ON** and again toggle OFF/ON once during syncing to force a retry.
5. Verify:
   - Only **one** purchase exists for that attempt (no duplicates).
   - Outbox item is removed after success.

## Collections create

1. Turn network **OFF**.
2. Record a collection payment for an existing customer.
3. Confirm it queues for sync.
4. Turn network **ON** and toggle OFF/ON once during syncing to force a retry.
5. Verify:
   - Only **one** collection exists for that attempt (no duplicates).
   - Outbox item is removed after success.

## Backend verification (optional)

- Inspect backend logs for lines containing `idempotency_key=` and confirm each key maps to a single `sale_id` / `purchase_id` / `collection_id`.

