# SMB Release Milestones

Updated: 2026-04-09 UTC
Status model: `completed`, `in_progress`, `pending`, `blocked`

## Milestone table

| ID | Milestone | Status | Depends on | Exit criteria |
|---|---|---|---|---|
| M0 | Repo bootstrap and continuity baseline | completed | none | `docs/inspection/` is populated, stale workflow docs are archived, `.codex` continuity files are current |
| M1 | Responsive and document workflow baseline | in_progress | M0 | verified module audit exists, Sales reference pattern is documented, rollout priority for non-standard modules is agreed |
| M2 | Shared UI/layout standardization | pending | M1 | shared desktop/mobile document shell exists and is applied to priority modules beyond Sales |
| M3 | Backend/API hardening | pending | M0 | runtime schema tolerance removed from request paths, OpenAPI classification is tightened, major auth/settings/runtime drift issues are reduced |
| M4 | DB, performance, and release safety hardening | pending | M3 | top N+1 hotspots, outbox claim races, and DB idempotency gaps have verified mitigation plans or fixes |
| M5 | Validation, permissions, and security posture | pending | M3 | production config gates, uploads, password reset delivery, and permission-sensitive paths are verified and documented |
| M6 | QA/UAT and operational readiness | blocked | M1, M3, M4, M5 | blocker UAT scenarios are executed, evidence is attached, release ops docs match reality |
| M7 | Deployment and final release gate | blocked | M6 | packaged environment verification is complete and a current go/no-go decision is evidence-backed |

## Milestone details

### M0. Repo bootstrap and continuity baseline

Scope:
- inspect repo structure and current docs
- archive stale one-off workflow docs
- create the inspection baseline and continuity protocol
- restore tracked `.codex/config.toml`

Completed in this run:
- `docs/inspection/*` continuity backbone created
- stale prompt/governance artifacts archived under `docs/archive/2026-04-09/`
- `.codex/README.md` refreshed
- `.codex/config.toml` restored

Residual notes:
- `AGENTS.md` still references a missing backlog file, but it now flags that gap explicitly

### M1. Responsive and document workflow baseline

Scope:
- audit desktop/mobile/responsive behavior across major modules
- identify the strongest current document workflow pattern
- define a standard for create/list/detail/edit/approve/print/share/status

Current evidence:
- Sales deeper document pages are the best current reference
- POS is not yet the desktop reference
- Purchases and several back-office modules remain mixed or mobile-first

Exit criteria:
- `docs/inspection/UI_RESPONSIVE_AUDIT.md` and `docs/inspection/DOCUMENT_WORKFLOW_STANDARD.md` stay current
- the next implementation slice is picked from the priority rollout order below

Priority rollout order:
1. Sales gaps: invoice listing, quote list/detail, sale detail desktop pattern
2. Purchases: PO, GRN, purchase returns
3. Accounts and reports dense-workbench pages
4. Customer and supplier document-heavy workbenches

### M2. Shared UI/layout standardization

Scope:
- turn Sales professional document widgets into a reusable pattern
- remove mixed desktop landing/page patterns
- centralize responsive rules instead of ad hoc width checks

Exit criteria:
- shared document components are reused across multiple modules
- module landing pages no longer split between old grid-only and newer list/workbench patterns without justification

### M3. Backend/API hardening

Scope:
- remove runtime schema drift tolerance
- move seed/bootstrap behavior out of startup-side services where possible
- classify unused OpenAPI endpoints
- reduce fragile runtime assumptions in auth, settings, and support flows

Exit criteria:
- no request path depends on schema probing as a fallback behavior
- auth/settings/bootstrap posture is migration-backed and environment-safe
- unused endpoints are classified as internal, future, or uncommercialized

### M4. DB, performance, and release safety hardening

Scope:
- eliminate major N+1 hotspots
- reduce dashboard fan-out cost
- strengthen finance outbox and ledger idempotency guarantees
- improve migration hygiene and schema confidence

Exit criteria:
- top hotspots have code fixes or documented exceptions
- outbox claim/idempotency protections are no longer purely best-effort
- release DB safety is stronger than current startup defaults

### M5. Validation, permissions, and security posture

Scope:
- tighten upload confidentiality
- verify password reset deliverability and production-readiness checks
- review permission-sensitive settings/admin flows
- verify release config guidance against actual code paths

Exit criteria:
- production readiness includes the real password reset dependency chain
- upload handling is compatible with document confidentiality expectations
- permission and security docs match implementation

### M6. QA/UAT and operational readiness

Scope:
- execute blocker UAT scenarios
- reconcile seeded data against reports and accounting outputs
- validate offline/outbox claims in the flows that are publicly claimed

Current blocker:
- manual release-candidate UAT sign-off remains incomplete

### M7. Deployment and final release gate

Scope:
- rerun automated gates
- verify packaged configuration
- update ship/no-go decision

Gate note:
- this milestone stays blocked until M6 evidence is complete
