# Phase 2 Codex Prompt Set

Goal: evolve EBS Lite from strong SMB product to enterprise-release-ready platform and product suite.

Use these prompts in order. Each prompt assumes Phase 1 is complete and stable.

## Global Rules For Every Phase 2 Prompt

Paste this block at the top of every run:

```text
You are working in E:\PROJECTS\EBS_Lite.

Read first:
- AGENTS.md
- RELEASE_READINESS_PLAN.md
- docs/release_market_readiness_report.md
- docs/ACCOUNTING_MODULE_USER_MANUAL.md
- docs/module_wise_feature_list.md
- docs/phase1_smb_release_ready_codex_prompt_set.md
- tools/api_parity_report.md
- go_backend_rmt/openapi.yaml

Mission:
Deliver an enterprise-ready EBS Lite direction without destabilizing the completed SMB release.

Architecture rules:
- Keep Go as the ERP core unless there is repo-proven evidence a change is required.
- Keep Flutter for POS, store, field, device, and offline-first workflows.
- Use next_frontend_web as the preferred path for enterprise back-office, portal, and browser-first experiences unless the repo evidence strongly disproves that path.
- Do not propose full rewrites where staged evolution is viable.

Execution rules:
- Maintain an explicit update plan.
- Create architecture RFCs before invasive cross-cutting changes.
- Implement in vertical slices that can be validated.
- Keep OpenAPI, docs, UI, and tests aligned.
- Document migration strategy, coexistence strategy, and rollback strategy for every major architectural change.
- For every prompt, explicitly cover:
  - business and control logic
  - data model and migration impact
  - API/OpenAPI impact
  - Flutter impact
  - next_frontend_web impact
  - identity/security/governance impact
  - observability and operations impact
  - documentation and rollout impact

Quality gates:
- Preserve all Phase 1 checks.
- Add architecture docs, migration docs, observability docs, and enterprise security docs as part of the deliverable.
- Include a UI ownership plan, migration test plan, and coexistence test matrix for every workflow that spans Flutter and web.
```

## Prompt 1: Enterprise Architecture Decision And Program Baseline

```text
Act as chief architect and enterprise product strategist.

Objective:
Produce the enterprise target-state architecture and execution program for EBS Lite based on the actual repo, not generic assumptions.

Tasks:
1. Inspect Flutter, Go backend, and next_frontend_web.
2. Produce an enterprise architecture RFC that explicitly answers:
   - what stays in Flutter
   - what moves to browser-first web
   - what remains shared in Go/OpenAPI/domain terms
   - how coexistence works during migration
3. Define enterprise edition boundaries versus SMB edition boundaries.
4. Define architectural workstreams, sequencing, risks, and dependencies.
5. Create a migration roadmap for UI ownership by workflow.
6. Define tenant/entity/branch/location concepts clearly for enterprise scale.

Required conclusion:
- recommend the split-front-end strategy unless direct repo evidence proves it is wrong
- explain why a full Flutter replacement or backend rewrite is not the right first move

Output requirements:
- architecture diagram in text form
- phased roadmap
- risk register
- module ownership map
- data and API compatibility principles
```

## Prompt 2: Enterprise Finance, Governance, And Data Model Foundation

```text
Act as principal enterprise ERP architect focused on finance and controls.

Objective:
Design and start implementing the enterprise finance and governance foundation required for serious multi-entity deployments.

Scope:
1. Define and implement the first safe slices for:
   - multi-entity structure
   - legal entities, branches, locations, and shared masters
   - intercompany transaction model
   - consolidation-ready ledger strategy
   - fixed assets and depreciation depth
   - budgeting and planning hooks
   - close controls and close calendars
2. Add governance concepts:
   - separation of duties
   - approval policies
   - privileged action reviewability
   - audit/export controls
3. Update API, services, docs, migrations, and UI contracts accordingly.

Tests required:
- entity scoping
- permission and SoD constraints
- intercompany posting cases
- consolidation or elimination prep logic where implemented
- migration safety

Output must include:
- architecture RFC updates
- migration notes
- admin/user impact notes
- explicit list of what is implemented now vs staged next
```

## Prompt 3: Enterprise Platform Services And Integration Backbone

```text
Act as platform architect and reliability engineer.

Objective:
Build the platform capabilities required for enterprise reliability, integration, auditability, and scale.

Implement and complete:
1. Transactional outbox standardization across critical modules.
2. Background worker or job execution framework for:
   - side effects
   - integrations
   - imports/exports
   - document generation
   - reconciliation jobs
3. Event contracts and retry/error handling rules.
4. Observability foundation:
   - structured logs
   - metrics
   - tracing hooks
   - alerting guidance
5. Enterprise security platform steps:
   - SSO/OIDC/SAML design and initial implementation path
   - SCIM-ready user lifecycle model
   - secrets/config externalization model
6. Data scale posture:
   - archival strategy
   - partitioning strategy
   - reporting isolation strategy

Tests required:
- outbox/job reliability
- retry/idempotency behavior
- worker failure handling
- observability signal coverage for critical paths
- auth and identity integration tests where implemented

Docs required:
- platform runbooks
- event and retry contract docs
- identity integration docs
- scale assumptions and limits
```

## Prompt 4: Browser-First Enterprise Back Office And Portal Evolution

```text
Act as enterprise UX architect and front-end platform lead.

Objective:
Turn next_frontend_web into the strategic enterprise UI shell while preserving Flutter for the workflows it serves better.

Tasks:
1. Audit existing next_frontend_web modules and identify reusable vs replaceable parts.
2. Define the enterprise web information architecture.
3. Implement the first enterprise-priority web slices for:
   - finance operations
   - approvals and audit
   - admin and governance
   - reporting workbenches
   - browser-first procurement/back-office workflows
4. Define portal strategy for customers, suppliers, or partners where justified.
5. Keep shared API contracts consistent with Flutter and Go.

UI expectations:
- dense professional enterprise UX
- no placeholder routes
- role-aware navigation
- scalable table, filter, review, and drill-down patterns
- explicit ownership boundaries between Flutter and web

Tests required:
- route protection
- data loading/error states
- permission-aware UI
- critical workflow regression coverage

Docs required:
- workflow ownership matrix
- enterprise navigation model
- UI migration rules and coexistence notes
```

## Prompt 5: Enterprise Readiness Completion Program

```text
Act as enterprise program lead, QA director, security/compliance lead, and release owner.

Objective:
Consolidate all Phase 2 work into an enterprise-release-ready program outcome.

Tasks:
1. Produce an enterprise readiness checklist covering:
   - product scope
   - architecture
   - security
   - identity
   - finance and controls
   - integrations
   - performance and scale
   - disaster recovery
   - support model
2. Implement the remaining highest-priority blockers that prevent an enterprise release claim.
3. Produce UAT packs for enterprise workflows.
4. Produce architecture and operator docs for:
   - deployment topology
   - HA/DR
   - audit/export handling
   - incident response
   - release governance
5. Verify all code, tests, parity, and enterprise docs are aligned.

Final output required:
- explicit statement whether the product is enterprise-release-ready
- exact blocker list if not fully ready
- exact next-quarter roadmap if some enterprise items remain staged
- evidence trail for the claim
```
