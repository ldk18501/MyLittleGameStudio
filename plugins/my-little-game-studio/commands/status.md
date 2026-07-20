# Command: status

## Purpose

Show current project state, owner participation, staff activity, gaps, risks, and A/B/C/D next options. `status` is a producer briefing, not a raw dump.

## Lead

Producer

## Read

- `workflow/onboarding.yaml`
- resolved project `.mlgs/state.json` or legacy `.mlgs/state.yaml`, or template only if no project exists
- `workflow/catalog.json`
- optional user runtime pointer, runtime, and latest activity
- active project artifacts

## Write

- project `.mlgs/state.json` only when correcting state or recording observed risk
- user runtime `current-project.json` only when repairing pointer
- trace/dashboard files

## Flow

1. When a path or nearest project exists, bind it with `tools/new-project-context.ps1`, then run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -ContextPath <context-path> -AllowTemplate
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
   - observed productization stage and the earliest incomplete quality gate
   - art manifest totals, placeholders, and assets below the required lifecycle status when available
   - target product version and release-scope totals by type/status, including planned-vs-implemented-vs-verified count gaps
   - visual-target approval/linkage gaps, onboarding gaps, and configuration/data-source gaps
   - quality report blockers and evidence gaps
   - latest staff activity
   - completed artifacts
   - missing artifacts
   - risks
   - recommended command
5. Offer the status object's A/B/C/D next options.
   Prefer natural-language phrases such as `/mlgs 把当前概念拆成开发计划`; keep old direct aliases only as compatibility.
6. Record trace in the bound project's runtime. Pointer-only status remains read-only and must not authorize later writes.

## Completion

The owner knows the true state and has actionable next options.

