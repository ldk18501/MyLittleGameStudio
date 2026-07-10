# State Rules

## Canonical State

`studio/state.json` is a validated template. Live project state belongs at `<ProjectRoot>/.mlgs/state.json` and follows `studio/state.schema.json`.

Legacy `<ProjectRoot>/.mlgs/state.yaml` remains readable. Prefer JSON when both exist. Migrate only through `tools/migrate-state.ps1` and only when the owner authorized changing that project.

## Runtime Data

Installed plugins are immutable. User-specific data defaults to:

```text
$CODEX_HOME/mlgs/
  current-project.json
  runtime.json
  logs/activity.jsonl
  dashboard/
```

When `CODEX_HOME` is unset, use `~/.codex/mlgs/`. In the MLGS source checkout, tools may continue using ignored `studio/` and `dashboard/` runtime files for local development. `studio/current-project.local.yaml` is a read-only legacy fallback.

## Resolution Order

1. Explicit state or project path.
2. User runtime `current-project.json`.
3. Legacy checkout pointer.
4. Nearest parent project state from the current directory.
5. `studio/state.json` template when `-AllowTemplate` is present.

If a pointer is stale, report it as repairable and use `tools/repair-pointer.ps1`. Do not silently clear or overwrite a real pointer during tests.

## Validation

- Parse new state with `ConvertFrom-Json` and validate with `Test-MLGSState`.
- Treat invalid enums, missing required objects, or wrong schema versions as blockers.
- Derive phase readiness and next action through `Get-MLGSGateEvaluation`; do not maintain a second hard-coded recommendation tree.
- A plan gate requires systems documents, `docs/tech-plan.md`, and `production/task-plan.md` together.
- A prototype gate requires both plan and playtest report, or an approved `skipped-with-risk` state with a reason.
- Vertical Slice and later gates require a structured `production/quality/<stage>.json` report with `verdict: pass`, owner approval, no blockers, passing required checks, and evidence for every check.
- Art-related gates also validate `production/assets/asset-manifest.json`; required assets must reach the configured lifecycle status, exist on disk, have import recipes and Unity references, and have in-game evidence.
- Gate evaluation is evidence-driven. Never advance a phase merely because a report file exists or because implementation subjectively looks complete.

## Write Safety

Before `implement` or `fix`, run `tools/preflight-task.ps1`. After edits, run `tools/validate-changes.ps1`. Project planning/QA paths are always allowed; Unity production edits must also fall under `activeProject.approvedWritePaths`.
