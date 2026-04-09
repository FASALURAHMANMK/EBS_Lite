# Codex Execution Protocol

Updated: 2026-04-09 UTC

## 1. Mandatory read order for future runs

1. `AGENTS.md`
2. `.codex/README.md`
3. `.codex/config.toml`
4. `docs/inspection/CURRENT_STATUS_SNAPSHOT.md`
5. `docs/inspection/EXECUTION_LEDGER.md`
6. `docs/inspection/SMB_RELEASE_MILESTONES.md`
7. `docs/inspection/SUBAGENT_USAGE_MATRIX.md`
8. `docs/inspection/REPO_OVERVIEW.md`
9. `docs/inspection/RELEASE_BLOCKERS_AND_RISKS.md`
10. Additional module-specific inspection docs as needed

## 2. Operating rules

- Work from verified repo state only.
- Do not claim a module, milestone, or release gate is complete unless it is verified in code, docs, or executed checks.
- If a referenced file is missing, record it as a gap instead of assuming its content.
- Prefer one current source of truth per topic.
- Archive superseded workflow docs under `docs/archive/` instead of silently deleting them.

## 3. Continuity backbone

Required per substantive run:
- update `docs/inspection/CURRENT_STATUS_SNAPSHOT.md`
- update `docs/inspection/EXECUTION_LEDGER.md`
- update milestone status in `docs/inspection/SMB_RELEASE_MILESTONES.md` if scope changed

## 4. Subagent rules

- Delegate only to agents verified in `.codex/agents/` or the verified local source catalog under `.codex/_subagents_repo/`.
- If a verified agent is not runnable in the current environment, map to the closest verified runnable substitute and document that mapping.
- Keep merge decisions, milestone status, and final documentation synthesis centralized in the parent run.

## 5. Documentation rules

- `docs/inspection/` is the current governance and continuity layer.
- `docs/` root still contains release/ops/support docs and supporting analyses.
- when a legacy prompt set or one-off governance file conflicts with the active workflow, archive it and reference the replacement inspection doc

## 6. Milestone rules

- The current milestone state lives in `docs/inspection/SMB_RELEASE_MILESTONES.md`.
- The next execution step must come from the highest-priority `in_progress` or `pending` milestone that has its prerequisites met.
- Do not restart from discovery unless the user explicitly requests a fresh audit.

## 7. Output rules for future runs

Each future run should:
- state the current milestone it is continuing
- state which verified subagents were used
- update status snapshot and execution ledger
- end with exactly one full `NEXT PROMPT TO RUN` block that continues from the current docs
