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

- resolved project `.mlgs/state.yaml`
- project `production/task-plan.md`
- project `production/tasks/[task].md` when present
- relevant design/system docs
- relevant Unity files inside approved write paths

## Write

- Unity project files inside approved write paths
- project `production/tasks/[task].md`
- tests or QA evidence
- project `.mlgs/state.yaml` when next action changes

## Flow

1. Resolve active project and owner participation.
2. Parse the task from the user request, task plan, or status next options.
3. Confirm production is unblocked. If not, continue only if the owner explicitly accepts risk.
4. Read the smallest relevant design, tech, and code context.
5. Use `mlgs-unity-mechanics` when the task involves gameplay mechanisms, input feel, feedback, object count, pooling, timing, or performance-sensitive runtime logic.
6. For DOD/instancing/bullets/mass objects, read `dod-performance.md` and record the chosen L1-L5 tier.
7. Under high participation, present a concise implementation plan before meaningful edits.
8. Under low/medium participation, implement directly unless the edit is high-risk.
9. Run the most relevant compile, smoke, or test check available.
10. Record:
    - files changed
    - acceptance criteria covered
    - verification result
    - deviations and risks
    - next recommended command
11. Record trace.

## Ask Before

- changing packages, project settings, scenes/prefabs with broad impact, or core architecture
- editing outside approved paths
- changing gameplay rules beyond the task
- making a major product feel choice under medium/high participation

## Completion

The task is implemented and verified, or blocked with a specific reason.
