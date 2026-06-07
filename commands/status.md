# Command: status

## Purpose

Show current project state, missing artifacts, risks, and the next best action.

## Lead

Producer

## Reads

- `studio/state.yaml`
- `workflow/phases.yaml`
- active project artifacts when present

## Writes

- `studio/state.yaml` only if correcting stale next action or recording observed risk.

## Procedure

1. Read `studio/state.yaml`.
2. Verify the active project path exists if configured.
3. Check the required artifacts for the current phase.
4. Report:
   - active project
   - current phase
   - approvals
   - prototype policy and verdict
   - completed/missing artifacts
   - risks
   - recommended next command
5. If state conflicts with the filesystem, state the conflict and recommend `start` or a state repair.

## Completion

- The user knows what is true now and what to do next.

