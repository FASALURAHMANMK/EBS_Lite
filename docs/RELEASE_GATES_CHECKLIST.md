# EBS Lite Release Gates Checklist

Date: 2026-03-30
Applies to: SMB Edition launch candidate

## Blocker gates

### Product and scope

- [ ] `docs/SMB_EDITION_SCOPE.md` is still accurate for the launch candidate.
- [ ] No launch claim contradicts implemented behavior in Flutter or Go.
- [ ] `next_frontend_web/` is not marketed as full parity unless its own readiness gates are added and satisfied.
- [ ] No reachable placeholder, dead route, or fake support action remains in launched Flutter navigation.

### Business logic

- [ ] POS checkout, sales, returns, purchases, collections, expenses, and cash close reconcile in UAT and seeded demo data.
- [ ] Accounting outputs match the currently documented behavior in `docs/ACCOUNTING_MODULE_USER_MANUAL.md`.
- [ ] Sale return and purchase return behavior is explained accurately in operator docs and release claims.

### Data model and migrations

- [ ] No manual schema step is required outside tracked migrations.
- [ ] Demo/seed data required for UAT can be reproduced.
- [ ] Opening balances, taxes, payment methods, numbering, and role seeds are controlled.

### API and OpenAPI

- [ ] `go_backend_rmt/openapi.yaml` reflects all shipped Flutter-called endpoints.
- [ ] `python tools/api_parity_check.py --out tools/api_parity_report.md` reports:
  - no Flutter paths missing from OpenAPI
  - no method mismatches
- [ ] Any unused backend route included in launch docs is explicitly tagged as internal, future, or secondary-surface only.

### Flutter client

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `dart format --set-exit-if-changed .` passes.
- [ ] Packaged build configuration uses an explicit production `API_BASE_URL`.
- [ ] Offline/outbox UX is validated for the flows we claim support.

### Go backend

- [ ] `go test ./...` passes.
- [ ] `go vet ./...` passes.
- [ ] `gofmt -l .` returns no changed files.
- [ ] Production configuration uses non-default secrets and real operational URLs.
- [ ] Upload size/type validation remains enabled in production config.

### Permissions and security

- [ ] Permission-gated actions have positive and negative test coverage.
- [ ] Session revocation, request IDs, and rate limiting remain enabled.
- [ ] Security-sensitive settings changes require elevated verification in the shipped build.
- [ ] Password reset URL is configured to a real deployed frontend.
- [ ] Support bundle exposure is explicitly approved for the deployment environment.

### Documentation and governance

- [ ] `RELEASE_READINESS_PLAN.md` is current.
- [ ] `docs/MODULE_UAT_MATRIX.md` has completed evidence for all in-scope modules.
- [ ] `docs/REPO_GOVERNANCE_ARTIFACTS.md` contains no unresolved must-exist launch blocker.
- [ ] Required operator/admin manuals, SOPs, and onboarding assets exist in repo.

## Non-blocker gates

- [ ] Backend-ready but non-commercialized endpoints are reviewed and classified.
- [ ] P2 architecture debt is logged and does not leak into launch claims.
- [ ] Web shell manual smoke testing is completed if it will be demoed.

## Required commands

From `go_backend_rmt/`:

```powershell
go test ./...
go vet ./...
gofmt -l .
```

From `flutter_app/`:

```powershell
flutter analyze
flutter test
dart format --set-exit-if-changed .
```

From repo root:

```powershell
python tools/api_parity_check.py --out tools/api_parity_report.md
```
