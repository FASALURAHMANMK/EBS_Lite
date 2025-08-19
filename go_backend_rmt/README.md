# go_erp_backend

ERP BACKEND

## API

### GET /api/v1/customers

Optional query parameters:

- `search` – filter by name, phone, or email
- `phone` – filter by phone number
- `credit_min` / `credit_max` – credit limit range
- `balance_min` / `balance_max` – outstanding balance range

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
