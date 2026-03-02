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

Docker: `go_backend_rmt/docker-compose.yml` runs `postgres` + `erp-api`; on a clean DB the base schema is initialized from `Docs & Schema/PostgrSQL.sql` and then the API applies migrations on startup.

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
