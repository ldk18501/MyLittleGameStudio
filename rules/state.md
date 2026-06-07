# State Rules

## State Files

`studio/state.yaml` is a template for new projects. It is not live project state.

Live state belongs to the active game project:

- external or embedded Unity project: `<UnityProject>/.mlgs/state.yaml`
- internal MLGS project: `projects/<slug>/.mlgs/state.yaml`

`studio/current-project.local.yaml` is an optional local pointer to the active project's state:

```yaml
version: 0.1
updated: "2026-06-07T00:00:00+08:00"
state_path: "E:/path/to/YourUnityGame/.mlgs/state.yaml"
project_root: "E:/path/to/YourUnityGame"
```

The local pointer must be ignored by git.

## Resolution Order

Resolve project state in this order:

1. Explicit state path or project path from the user.
2. `studio/current-project.local.yaml`.
3. `.mlgs/state.yaml` in the current working directory or nearest parent when working inside a game project.
4. `studio/state.yaml` as a template only.

If only the template is available, route to `commands/start.md` before project-specific production work.

## Single State Rule

For any one game project, `.mlgs/state.yaml` is the only source of truth for:

- active project identity
- phase
- approvals
- prototype policy
- risks
- next action
- approved Unity write paths

Do not create separate active-project, stage, or session state files at the MLGS root.

Project-local logs are allowed, but they must not contradict the resolved `.mlgs/state.yaml`.

If filesystem state conflicts with the resolved project state, report the conflict before running a project-level command.
