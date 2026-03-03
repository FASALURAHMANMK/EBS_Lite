# go_erp_backend

ERP BACKEND

## Configuration (required)

1) Copy `go_backend_rmt/.env.example` to `go_backend_rmt/.env`
2) Update values for your environment (at minimum `DATABASE_URL` and `JWT_SECRET`)
3) Run checks:
   - `go test ./...`
   - `go vet ./...`

To start the server locally, run `go run ./cmd/server` from `go_backend_rmt/` (ensure Postgres is running and `DATABASE_URL` is reachable).

## Migrations

The backend applies SQL migrations automatically on startup (using `pressly/goose`) when `RUN_MIGRATIONS=true`.

- Migrations directory: `go_backend_rmt/migrations`
- Legacy/notes scripts: `go_backend_rmt/Docs & Schema/migrations` (not executed directly)

To disable automatic migrations (not recommended for dev):
- set `RUN_MIGRATIONS=false`

Docker: `go_backend_rmt/docker-compose.yml` runs `postgres` + `erp-api`; on a clean DB the API applies Goose migrations (including the base schema migration) on startup.

## Backup / Restore (operator-friendly)

Minimal recommended backup (run daily, keep at least 7 days):

```bash
pg_dump --format=custom --no-owner --file ebs_lite_$(date +%F).dump "$DATABASE_URL"
```

PowerShell equivalent:

```powershell
$d = Get-Date -Format yyyy-MM-dd
pg_dump --format=custom --no-owner --file "ebs_lite_$d.dump" "$env:DATABASE_URL"
```

Restore to a new empty database:

```bash
createdb ebs_lite_restored
pg_restore --no-owner --clean --if-exists --dbname "$DATABASE_URL" ebs_lite_YYYY-MM-DD.dump
```

Notes:
- Test restore at least once before going live.
- Store backups off the POS device (NAS/cloud/USB rotation).

## Readiness + Support bundle

- Liveness: `GET /health` (always returns 200 when the server is running)
- Readiness: `GET /ready` (returns 200 only when DB + Redis checks pass)
- Support bundle (non-production by default): `GET /api/v1/support/bundle` (requires auth + `VIEW_SETTINGS`)
  - Enable in production only if required: set `SUPPORT_BUNDLE_ENABLED=true`

## API

### GET /api/v1/customers

Optional query parameters:

- `search` – filter by name, phone, or email
- `phone` – filter by phone number
- `credit_min` / `credit_max` – credit limit range
- `balance_min` / `balance_max` – outstanding balance range

### GET /api/v1/ledgers/:account_id/entries

Optional query parameters:

- `date_from` – filter entries on or after this date (YYYY-MM-DD)
- `date_to` – filter entries on or before this date (YYYY-MM-DD)

## Product Attributes

The API supports dynamic product attributes. First create attribute definitions:

```json
POST /api/v1/product-attribute-definitions
{
  "name": "Color",
  "type": "SELECT",
  "is_required": true,
  "options": "[\"Red\",\"Blue\"]"
}
```

Assign values when creating or updating products by providing an `attributes` map where keys are definition IDs:

```json
POST /api/v1/products
{
  "name": "Sample",
  "barcodes": [{"barcode": "123", "pack_size":1, "cost_price":10, "selling_price":12, "is_primary":true}],
  "is_serialized": false,
  "attributes": { "1": "Red" }
}
```

Product responses include attribute values with embedded definitions.
