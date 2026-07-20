# Command: start

## Purpose

Start MLGS through a low-friction Codex flow: new game, existing Unity project, continue current project, or pointer repair. Also sets owner participation.

## Lead

Producer

## Supporting Agents

- Creative Director for new game ideas
- Unity Architect for existing Unity projects
- Game Designer for clear gameplay concepts

## Read

- `studio/config.md`
- `rules/state.md`
- `workflow/onboarding.yaml`
- `workflow/catalog.json`
- `studio/state.json` as template only
- optional user runtime pointer or legacy checkout pointer
- user-provided project path, if any

## Write

- project `.mlgs/state.json` only after the owner chooses or confirms a project
- user runtime `current-project.json` only when the owner explicitly chooses to set the navigation default
- project `.mlgs/project.md`

## Flow

1. Run or equivalently execute `tools/resolve-state.ps1 -AllowTemplate`. Prefer an explicit/nearest project over any user pointer; use `-AllowLegacyPointer` only for deliberate recovery.
2. If pointer is stale, report broken `state_path` and `project_root`, then ask one question: repair to what path, or clear pointer?
3. If a valid active project exists and the user did not request a new project, show project/phase/next action and recommend `/mlgs 看看当前状态`.
4. If no active project exists, ask:
   - A) New game
   - B) Existing Unity project
   - C) Continue current project
   - D) Repair or switch
5. Ask participation level if unset or if starting/adopting:
   - A) Low
   - B) Medium
   - C) High
6. Route:
   - New game -> create internal workspace when needed, then internal `brainstorm`
   - Existing Unity project -> run `tools/adopt-project.ps1 -ProjectRoot <path>` for report, then internal `adopt`
   - Continue current -> run `tools/get-project-status.ps1 -AllowTemplate`, then internal `status`
   - Repair/switch -> `tools/repair-pointer.ps1` or clear pointer
7. When initializing state, prefer `tools/init-project-state.ps1`. It does not change the navigation pointer unless `-SetCurrent` is explicit.
8. Record trace.

## Defaults

- Engine: Unity
- Language: C#
- Owner participation: medium
- Planning automation: high
- Production automation: medium
- Existing Unity project mode: external-adopted
- External project approved write path suggestion: `Assets/`

## Completion

The owner has one next phrase/question, or an active project has been configured with participation level and next action.

