# Codex Adapter

MLGS is now Codex-first. Claude Code compatibility is intentionally out of scope.

## Preferred Use

Install the bundled Codex plugin, then use:

```text
/mlgs start
/mlgs brainstorm
/mlgs adopt D:\path\to\UnityProject
/mlgs status
/mlgs plan
/mlgs implement 下一个任务
/mlgs fix 这个问题
/mlgs build APK
```

Natural language remains valid, but `/mlgs ...` is the stable mental model.

## Runtime Behavior

- Read `studio/config.md`, `rules/state.md`, and `workflow/catalog.json`.
- Use `workflow/command-router.md` only as the routing procedure.
- Use `workflow/onboarding.yaml` for start/adopt/status.
- Resolve active project through `rules/state.md`.
- Keep `studio/state.json` as template only; runtime data belongs under `$CODEX_HOME/mlgs/` for installed plugins.
- Record every routed task through `tools/trace.ps1`.
- Refresh the resolved runtime dashboard data.

## Checks

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
powershell -ExecutionPolicy Bypass -File tools/run-smoke-tests.ps1
```
