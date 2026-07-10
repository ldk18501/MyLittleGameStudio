# Command: implement

## Purpose

Implement a focused, approved Unity/C# production task.

## Lead

Gameplay Developer

## Supporting Agents

- Unity Architect for architecture-sensitive work
- UI/UX Developer for UI tasks
- Technical Artist for VFX, shaders, generated art integration
- QA Lead for verification
- Producer for scope and trace

## Read

- resolved project `.mlgs/state.json` or legacy `.mlgs/state.yaml`
- project `production/task-plan.md`
- project `production/tasks/[task].md` when present
- relevant design/system docs
- relevant Unity files inside approved write paths
- `rules/production-code.md`

## Write

- Unity project files inside approved write paths
- project `production/tasks/[task].md`
- tests or QA evidence
- project `.mlgs/state.json` when next action changes

## Flow

1. Resolve active project and owner participation.
2. Parse the task from the user request, task plan, or status next options.
3. Run `tools/preflight-task.ps1 -Command implement`. If blocked, continue only after the owner explicitly accepts risk and rerun with `-AcceptRisk`.
4. Read the smallest relevant design, tech, and code context.
5. Determine whether the work is disposable prototype code or production code. After prototype approval, default to production code; a temporary shortcut requires a tracked removal task before Vertical Slice approval.
6. Apply `rules/production-code.md`: preserve module dependency direction, separate rules from Unity presentation, use explicit composition and serialized references, make lifecycle cleanup/cancellation explicit, keep config data-driven, and expose errors with context.
7. Use `mlgs-unity-mechanics` when the task involves gameplay mechanisms, input feel, feedback, object count, pooling, timing, or performance-sensitive runtime logic.
8. For DOD/instancing/bullets/mass objects, read `dod-performance.md` and record the chosen L1-L5 tier.
9. Under high participation, present a concise implementation plan before meaningful edits.
10. Under low/medium participation, implement directly unless the edit is high-risk.
11. Run compile, focused tests, integration smoke, and the task acceptance checks. A feature is not done if only an isolated component works but its actual scene/UI/data flow is unwired.
12. Run `tools/test-production-code.ps1` for production tasks. Resolve errors; convert warnings into fixes or recorded debt with a removal milestone.
13. Run `tools/validate-changes.ps1` and reject edits outside project planning paths or approved Unity write paths.
14. Record:
    - files changed
    - acceptance criteria covered
    - verification result
    - deviations and risks
    - next recommended command
15. Record trace.

## Ask Before

- changing packages, project settings, scenes/prefabs with broad impact, or core architecture
- editing outside approved paths
- changing gameplay rules beyond the task
- making a major product feel choice under medium/high participation

## Completion

The task is integrated, production-structured, and verified against real acceptance criteria, or blocked with a specific reason. “Works in a demo scene” is not completion evidence after the prototype phase.
