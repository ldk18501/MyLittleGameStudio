# Command: status

## Purpose

Show current project state, missing artifacts, risks, and the next best action.

## Lead

Producer

## Reads

- resolved project `.mlgs/state.yaml`, or `studio/state.yaml` template if no project is configured
- `workflow/phases.yaml`
- `studio/runtime.json` if present
- latest entries from `studio/logs/activity.jsonl` if present
- active project artifacts when present

## Writes

- resolved project `.mlgs/state.yaml` only if correcting stale next action or recording observed risk.

## Procedure

1. Resolve and read project state.
2. Verify the active project path exists if configured.
3. Check the required artifacts for the current phase.
4. Report:
   - active project
   - current phase
   - approvals
   - prototype policy and verdict
   - latest studio activity and agents used
   - completed/missing artifacts
   - risks
   - recommended next command
5. If state conflicts with the filesystem, state the conflict and recommend `start` or a state repair.
6. Record a `status` trace event.

## Completion

- The user knows what is true now and what to do next.
