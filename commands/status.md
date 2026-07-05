# Command: status

## Purpose

Show current project state, owner participation, staff activity, gaps, risks, and A/B/C/D next options. `status` is a producer briefing, not a raw dump.

## Lead

Producer

## Read

- `workflow/onboarding.yaml`
- resolved project `.mlgs/state.yaml`, or template only if no project exists
- `workflow/phases.yaml`
- optional `studio/current-project.local.yaml`
- optional `studio/runtime.json`
- optional latest `studio/logs/activity.jsonl`
- active project artifacts

## Write

- project `.mlgs/state.yaml` only when correcting stale next action or recording observed risk
- `studio/current-project.local.yaml` only when repairing pointer
- trace/dashboard files

## Flow

1. Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate
   ```
2. If pointer is stale, report broken paths and ask one recovery question.
3. If only template exists, report no active project and ask:
   - A) New game
   - B) Existing Unity project
   - C) Help/menu
   - D) Clear/repair pointer
   If the user already provided an idea seed or project path, route directly to internal `brainstorm` or `adopt` instead of asking again.
4. If active project exists, report from the structured status object:
   - active project
   - owner participation
   - current phase
   - approvals
   - prototype policy/verdict
   - latest staff activity
   - completed artifacts
   - missing artifacts
   - risks
   - recommended command
5. Offer the status object's A/B/C/D next options.
   Prefer natural-language phrases such as `/mlgs 把当前概念拆成开发计划`; keep old direct aliases only as compatibility.
6. Record trace.

## Completion

The owner knows the true state and has actionable next options.

