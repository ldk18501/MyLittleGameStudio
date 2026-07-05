# State Rules

## Canonical State

`studio/state.yaml` is a template, not live project state.

Live state belongs to the active game project:

- external or embedded Unity project: `<UnityProject>/.mlgs/state.yaml`
- internal MLGS project: `projects/<slug>/.mlgs/state.yaml`

`studio/current-project.local.yaml` is an optional local pointer:

```yaml
version: 0.2
updated: "2026-06-30T00:00:00+08:00"
state_path: "E:/path/to/YourUnityGame/.mlgs/state.yaml"
project_root: "E:/path/to/YourUnityGame"
```

The pointer must be ignored by git.

## Resolution Order

Resolve active state in this order:

1. user-provided state path or project path
2. `studio/current-project.local.yaml`
3. `.mlgs/state.yaml` in the current directory or nearest parent
4. `studio/state.yaml` as template only

If only the template exists, route to `/mlgs-start` before project-level work, unless the current request contains enough idea or path context to create/adopt the project directly.

## Required Project State Fields

Every project `.mlgs/state.yaml` should contain:

- `active_project`
- `owner_participation`
- `phase`
- `approvals`
- `prototype`
- `next_action`
- `assumptions`
- `risks`

For older `version: 0.1` state files, treat missing `owner_participation` as `medium` and old phases as:

- `idea-alignment` -> `intake`
- `concept-package` -> `concept`
- `design-tech-plan` -> `plan`
- `prototype-validation` -> `prototype`
- `polish-ship` -> `release`

## Stale Pointer Recovery

If `studio/current-project.local.yaml` exists but `state_path` or `project_root` does not exist:

1. Do not continue project-level commands.
2. Report the broken paths.
3. Ask one recovery question: provide a new project/state path, or clear the pointer and start again.
4. Use `tools/repair-pointer.ps1` when possible.
5. Trace status as `partial`.

## Adopting Existing Projects

When the user provides an existing Unity project, code folder, prototype, or docs path:

1. Run or equivalently execute `tools/detect-project-stage.ps1`.
2. If `.mlgs/state.yaml` exists, repair the pointer and run `/mlgs-status`.
3. If it is a Unity project without MLGS state, route to `/mlgs-adopt`.
4. If it is not Unity but has docs/prototype/code, route to `/mlgs-adopt` for gap analysis.

## Single Source Of Truth

For a game project, `.mlgs/state.yaml` is the source of truth for:

- project identity
- owner participation
- phase
- approvals
- prototype policy
- risks
- next action
- approved Unity write paths

Do not create extra root-level active-project, stage, or session state files.

