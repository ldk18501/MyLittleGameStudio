# Command: adopt

## Purpose

Inspect and attach an existing Unity project, docs folder, prototype, or codebase. `adopt` analyzes state and asks what to do next; it does not modify production files.

## Lead

Producer

## Supporting Agents

- Unity Architect: Unity structure, version, packages, write boundaries
- Creative Director: concept, references, visual direction
- Game Designer: systems, tasks, scope
- QA Lead: tests, evidence, readiness risks

## Read

- user-provided project path or state path
- `.mlgs/state.yaml`
- `ProjectSettings/ProjectVersion.txt`
- `Packages/manifest.json`
- `Assets/`
- `design/`
- `docs/`
- `prototype/`
- `production/`
- `tests/`
- C# source files

## Write

Only after owner confirmation:

- `<ProjectRoot>/.mlgs/state.yaml`
- `<ProjectRoot>/.mlgs/project.md`
- `studio/current-project.local.yaml`

Do not copy the Unity project into MLGS. Do not rewrite existing design docs during adoption.

## Flow

1. If no path was provided, ask one question: "What is the Unity project directory?"
2. Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot <path>
   ```
   This is report-only by default.
3. Report findings from the structured adoption report:
   - Unity project: yes/no
   - Unity version
   - existing MLGS state
   - design/reference/concept/system docs
   - prototype artifacts
   - production plan/tasks
   - source and asset scale
   - tests or QA evidence
   - detected phase
   - major gaps
4. Recommend one action:
   - existing `.mlgs/state.yaml` -> repair pointer and run `/mlgs-status`
   - Unity project without MLGS state -> initialize as `external-adopted`
   - docs/code without Unity project -> initialize internal workspace or ask for Unity path
   - empty/unrelated folder -> `/mlgs-start`
5. Ask one A/B/C question:
   - A) Adopt now
   - B) Inspect more before adopting
   - C) Cancel
6. If adopting, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot <path> -Apply
   ```
   Include `-OwnerParticipation low|medium|high` and `-ApprovedWritePaths` when known.
7. Ask or recommend next work:
   - missing concept -> `/mlgs-brainstorm`
   - missing plan -> `/mlgs-plan`
   - missing prototype or risk unresolved -> `/mlgs-prototype`
   - production ready -> `/mlgs-status` with task options
8. Record trace.

## Completion

The project is attached, or the owner sees a clear adoption report and one next question.

