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
- `.mlgs/state.json` or legacy `.mlgs/state.yaml`
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

- `<ProjectRoot>/.mlgs/state.json`
- `<ProjectRoot>/.mlgs/project.md`
- user runtime `current-project.json` only when the owner explicitly requests `-SetCurrent`

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
   - recommended project kind and intensity: new/lightweight, small-existing/standard, or large-framework/deep
   - confidence and the signals used; low-confidence classifications must be confirmed or overridden during planning
4. Recommend one action:
   - existing state -> bind that project directly and run `/mlgs 看看当前状态`; offer optional `-SetCurrent` navigation and explicit migration for legacy YAML
   - Unity project without MLGS state -> initialize as `external-adopted`
   - docs/code without Unity project -> initialize internal workspace or ask for Unity path
   - empty/unrelated folder -> internal `start`
5. Ask one A/B/C question:
   - A) Adopt now
   - B) Inspect more before adopting
   - C) Cancel
6. If adopting, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot <path> -Apply
   ```
   Include `-OwnerParticipation low|medium|high` and `-ApprovedWritePaths` when known. Add `-SetCurrent` only when the owner explicitly wants to change the navigation pointer; normal adoption remains project-local.
7. Do not force the adopted project into its current architecture. The report is evidence for planning; it may lead to extending, lightly adapting, replacing a harmful legacy area, or creating an isolated new module.
7. Ask or recommend next work:
   - missing concept -> `/mlgs 帮我头脑风暴这个游戏概念`
   - missing plan -> `/mlgs 把当前概念拆成开发计划`
   - missing prototype or risk unresolved -> `/mlgs 做一个最小原型验证核心风险`
   - production ready -> `/mlgs 看看当前状态并推荐下一个任务`
8. Record trace.

## Completion

The project is attached, or the owner sees a clear adoption report and one next question.

