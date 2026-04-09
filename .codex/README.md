# Codex Continuity Guide

This directory is the repo-local continuity layer for future Codex runs.

## Mandatory read order

1. `AGENTS.md`
2. `.codex/README.md`
3. `.codex/config.toml`
4. `docs/inspection/CODEX_EXECUTION_PROTOCOL.md`
5. `docs/inspection/CURRENT_STATUS_SNAPSHOT.md`
6. `docs/inspection/EXECUTION_LEDGER.md`
7. `docs/inspection/SMB_RELEASE_MILESTONES.md`
8. `docs/inspection/SUBAGENT_USAGE_MATRIX.md`
9. `docs/inspection/REPO_OVERVIEW.md`
10. Additional inspection docs needed for the active workstream

## Subagent rules

- Project-specific agents live in `.codex/agents/`.
- `.codex/_subagents_repo/` is a verified local source catalog only; it is not the active install set by itself.
- Subagents must be explicitly delegated in the prompt or by the parent agent.
- If a verified local agent is not runnable in the current Codex account environment, map to the closest verified runnable agent and record the mapping in:
  - `docs/inspection/SUBAGENT_USAGE_MATRIX.md`
  - `docs/inspection/EXECUTION_LEDGER.md`

## Continuity rules

- `docs/inspection/CURRENT_STATUS_SNAPSHOT.md` is the current-state summary.
- `docs/inspection/EXECUTION_LEDGER.md` is the activity log and next-step tracker.
- `docs/inspection/SMB_RELEASE_MILESTONES.md` is the milestone source of truth.
- Archive stale one-off prompts and superseded governance docs under `docs/archive/`.
- Every future prompt should end with one full `NEXT PROMPT TO RUN` block.
