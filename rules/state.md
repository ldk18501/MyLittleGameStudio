# State Rules

- `studio/state.yaml` is the only root-level source of truth for active project, phase, approvals, prototype policy, risks, and next action.
- Do not create separate active-project, stage, or session state files at the studio root.
- Project-local logs are allowed, but they must not contradict `studio/state.yaml`.
- If filesystem state conflicts with `studio/state.yaml`, report the conflict before running a project-level command.

