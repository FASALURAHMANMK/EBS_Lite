# EBS Lite Final Release Prompts

Date: 2026-03-30
Use these only after the Phase 1 engineering prompts are completed and the repo is at the current baseline.

## Prompt 1: Release-Candidate UAT Closure

```text
Act as a release QA lead and ERP operator validator.

Objective:
Close the final manual release blocker by executing and documenting the blocker scenarios in docs/MODULE_UAT_MATRIX.md against the seeded release-candidate dataset.

Mandatory setup:
- Work in E:\PROJECTS\EBS_Lite
- Reset the demo/UAT dataset first with:
  - ./tools/reset_demo_uat.ps1
- Use the generated docs/DEMO_DATASET_REPORT.md as the seeded-baseline attachment.

Tasks:
1. Execute every Blocker-severity scenario in docs/MODULE_UAT_MATRIX.md.
2. Capture evidence for each scenario as screenshots, exported reports, or signed operator notes.
3. Reconcile the seeded sales, returns, purchases, collections, expenses, cash close, and accounting reports against the generated dataset.
4. Update docs/UAT_EVIDENCE_PACK.md with exact evidence collected, exact users used, exact document numbers tested, and pass/fail status per blocker scenario.
5. If any blocker scenario fails, document the exact defect, impacted module, replication steps, and whether it is a code bug, data issue, or operator/training issue.
6. Update docs/GO_NO_GO_SUMMARY.md with the post-UAT decision.

Completion definition:
- Every Blocker scenario in docs/MODULE_UAT_MATRIX.md has evidence and a clear pass/fail result.
- docs/UAT_EVIDENCE_PACK.md and docs/GO_NO_GO_SUMMARY.md are current.
```

## Prompt 2: Packaged Deployment Verification

```text
Act as release manager, deployment engineer, and security verifier.

Objective:
Prove that the packaged release candidate uses production-safe configuration and that the deployed environment matches the repo’s release gates.

Mandatory setup:
- Work in E:\PROJECTS\EBS_Lite
- Use go_backend_rmt/.env.production.template and flutter_app/dart_defines.production.example.json as the baseline.

Tasks:
1. Verify the packaged Flutter build uses an explicit non-local API_BASE_URL and starts successfully.
2. Verify backend production configuration uses:
   - non-default JWT secret
   - real FRONTEND_BASE_URL for password reset
   - exact ALLOWED_ORIGINS
   - upload size/type validation enabled
   - Redis/rate-limit posture aligned with docs/SECURITY_OPERATIONS_GUIDE.md
3. Confirm password reset links point to the deployed frontend host, not localhost.
4. Confirm support-bundle exposure is approved for the deployment environment.
5. Update docs/RELEASE_GATES_CHECKLIST.md with the deployment verification outcome and note any environment-specific exceptions.
6. If verification fails, record the exact config key, current unsafe value, required safe value, and deployment owner action.

Completion definition:
- The packaged app and deployed backend satisfy the production-config gates in docs/RELEASE_GATES_CHECKLIST.md.
```

## Prompt 3: Final Ship Decision

```text
Act as SMB release approver and documentation owner.

Objective:
Produce the final go/no-go decision using the completed UAT evidence, deployment verification, automated quality gates, and parity status.

Tasks:
1. Re-run the mandatory automated gates:
   - From go_backend_rmt: go test ./..., go vet ./..., gofmt -l .
   - From flutter_app: flutter analyze, flutter test, dart format --set-exit-if-changed .
   - From repo root: python tools/api_parity_check.py --out tools/api_parity_report.md
2. Read:
   - RELEASE_READINESS_PLAN.md
   - docs/UAT_EVIDENCE_PACK.md
   - docs/GO_NO_GO_SUMMARY.md
   - docs/RELEASE_GATES_CHECKLIST.md
   - docs/DEMO_DATASET_REPORT.md
3. Update docs/GO_NO_GO_SUMMARY.md to either:
   - GO, with exact evidence references and accepted limitations only
   - NO-GO, with exact residual blockers only
4. Update release notes and operator handoff docs if the decision changes.

Completion definition:
- The repo contains a final, evidence-backed ship decision with no ambiguous blocker wording.
```
