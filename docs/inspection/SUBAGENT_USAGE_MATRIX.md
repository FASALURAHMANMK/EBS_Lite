# Subagent Usage Matrix

Updated: 2026-04-09 UTC

## 1. Verified local agent files

Verified under `.codex/agents/`:
- `api-designer`
- `architect-reviewer`
- `backend-developer`
- `code-mapper`
- `code-reviewer`
- `competitive-analyst`
- `database-administrator`
- `database-optimizer`
- `deployment-engineer`
- `devops-engineer`
- `docs-researcher`
- `documentation-engineer`
- `flutter-expert`
- `golang-pro`
- `knowledge-synthesizer`
- `mobile-developer`
- `performance-engineer`
- `postgres-pro`
- `product-manager`
- `qa-expert`
- `reviewer`
- `search-specialist`
- `security-auditor`
- `sql-pro`
- `ui-designer`
- `ui-fixer`
- `workflow-orchestrator`

## 2. Runtime status in this Codex environment

Verified runnable in this run:
- `flutter-expert`
- `golang-pro`
- `architect-reviewer`
- `sql-pro`

Verified local but not runnable in this ChatGPT-backed Codex account because the local definitions point at `gpt-5.3-codex-spark`:
- `code-mapper`
- `competitive-analyst`

Verified local but incomplete placeholder files in this repo:
- `database-optimizer`
- `workflow-orchestrator`

Verified local but not exercised in this run:
- all other agents listed above

## 3. Responsibility mapping

| Responsibility | Preferred verified local agent | Runtime mapping used in this run | Notes |
|---|---|---|---|
| Repo structure and ownership mapping | `code-mapper` | `architect-reviewer` | fallback used because `code-mapper` was not runnable here |
| Flutter responsive/UI audit | `flutter-expert` | `flutter-expert` | used successfully |
| Go backend/API review | `golang-pro` | `golang-pro` | used successfully |
| PostgreSQL/schema/query review | `postgres-pro` or `sql-pro` | `sql-pro` | `sql-pro` used as the closest verified runnable agent |
| Competitive ERP baseline | `competitive-analyst` | parent agent local research | no clean verified runnable substitute was available in this environment |
| Quality/release risk review | `reviewer` or `architect-reviewer` | `architect-reviewer` | used successfully for repo architecture/governance findings |

## 4. Delegation used in this run

Successful delegated audits:
- `flutter-expert`: responsive/UI and document workflow audit
- `golang-pro`: backend/API/runtime review
- `architect-reviewer`: architecture/governance audit
- `sql-pro`: PostgreSQL/query/index/release-safety audit

Attempted but not runnable:
- `code-mapper`
- `competitive-analyst`

## 5. Rule for future runs

- Use only verified local agents.
- If the preferred agent is not runnable, map to the closest verified runnable agent and record the mapping in the execution ledger.
