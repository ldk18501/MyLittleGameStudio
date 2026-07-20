# State Rules

## Canonical State

`studio/state.json` is a validated template. Live project state belongs at `<ProjectRoot>/.mlgs/state.json` and follows `studio/state.schema.json`.

Legacy `<ProjectRoot>/.mlgs/state.yaml` remains readable. Prefer JSON when both exist. Migrate only through `tools/migrate-state.ps1` and only when the owner authorized changing that project.

## Runtime Data

Installed plugins are immutable. User-specific data defaults to:

```text
$CODEX_HOME/mlgs/
  current-project.json
  projects/<project-id>/
    contexts/<invocation-id>.json
    leases/<invocation-id>.json
    runtime.json
    logs/activity.jsonl
    dashboard/
```

When `CODEX_HOME` is unset, use `~/.codex/mlgs/`. In the MLGS source checkout, tools may continue using ignored `studio/` and `dashboard/` runtime files for local development. `studio/current-project.local.yaml` is a read-only legacy fallback.

## Resolution Order

1. Bound task context created by `tools/new-project-context.ps1`.
2. Explicit state or project path.
3. Nearest parent project state from the current directory.
4. User runtime `current-project.json` as a compatibility fallback for read-only navigation.
5. Legacy checkout pointer only when `-AllowLegacyPointer` is explicit.
6. `studio/state.json` template when `-AllowTemplate` is present.

Project write routes must resolve through items 1-3. A global or legacy pointer cannot authorize `implement`, `fix`, `generate-art`, or `productize`. Resolve once at task start, retain the returned context path, and pass it through preflight, trace, dashboard, and post-change validation; never re-resolve a running task through the global pointer.

If a pointer is stale, report it as repairable and use `tools/repair-pointer.ps1`. Do not silently clear or overwrite a real pointer during tests.

## Validation

- Parse new state with `ConvertFrom-Json` and validate with `Test-MLGSState`.
- Treat invalid enums, missing required objects, or wrong schema versions as blockers.
- Derive phase readiness and next action through `Get-MLGSGateEvaluation`; do not maintain a second hard-coded recommendation tree.
- A plan gate requires systems documents, `docs/tech-plan.md`, and `production/task-plan.md` together.
- A prototype gate requires both plan and playtest report, or an approved `skipped-with-risk` state with a reason.
- Vertical Slice and later gates require a structured `production/quality/<stage>.json` report with `verdict: pass`, owner approval, no blockers, passing required checks, and evidence for every check.
- Art-related gates also validate `production/assets/asset-manifest.json`; required assets must reach the configured lifecycle status, exist on disk, have import recipes and Unity references, and have in-game evidence.
- Plan and productization gates validate `production/scope/release-scope.json`. It is the explicit completeness set for features, content quantities, tutorials, UI screens, configuration, audio, art, localization, operations readiness, and builds.
- Formal art entries must link to approved IDs in `design/art/visual-target.json`; Unity references and in-game evidence must be existing project-relative files.
- Quality-check evidence must be existing project-relative files. Labels such as `manual:passed` or unresolvable prose are not gate evidence.
- Version strings never advance state. `0.x` is prototype/pre-release; `1.0.0+` requires the final Release gate and a fully verified release scope.
- Gate evaluation is evidence-driven. Never advance a phase merely because a report file exists or because implementation subjectively looks complete.

## Write Safety

Before `implement` or `fix`, bind a project context, acquire a path lease, and run `tools/preflight-task.ps1 -ContextPath <context-path>`. After edits, run `tools/validate-changes.ps1 -ContextPath <context-path>` before releasing that lease. Project planning/QA paths are always allowed by project policy, but every actual write must also be covered by the active lease; Unity production edits must additionally fall under `activeProject.approvedWritePaths`.

Different projects use different project runtime roots. Parallel writes inside one project require an active lease from `tools/acquire-project-lease.ps1`; overlapping declared paths fail closed. Release the lease after the terminal trace event. Atomic JSON replacement prevents partial files but does not replace task-level path ownership.
