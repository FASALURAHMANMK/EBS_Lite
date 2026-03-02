# Backend ↔ OpenAPI route drift check

Goal: detect “docs drift” between implemented Gin routes and `go_backend_rmt/openapi.yaml`.

## Run (one command)

From repo root:

```powershell
python tools/openapi_route_drift_check.py --out tools/backend_openapi_drift_report.md
```

This will:
- run `go run ./cmd/route_dump --in internal/routes/routes.go` from `go_backend_rmt/` (no DB required)
- compare the result to `go_backend_rmt/openapi.yaml`, respecting:
  - global `servers: - url: /api/v1`
  - per-path `servers` overrides (e.g. `/health` served at `/`)

## Run (two-step)

If you want to inspect the route dump:

```powershell
cd go_backend_rmt
go run ./cmd/route_dump --in internal/routes/routes.go --out ..\\tools\\implemented_routes.txt
cd ..
python tools/openapi_route_drift_check.py --routes tools/implemented_routes.txt --out tools/backend_openapi_drift_report.md
```

## Expected output

`tools/backend_openapi_drift_report.md` contains:
- Implemented routes missing from OpenAPI
- OpenAPI routes missing from implementation
