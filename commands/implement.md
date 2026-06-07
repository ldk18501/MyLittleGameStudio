# Command: implement

## Purpose

Implement an approved Unity production task.

## Lead

Gameplay Developer

## Supporting Agents

- Unity Architect for architecture-sensitive work
- UI/UX Developer for UI tasks
- Technical Artist for visual/VFX/generated-art tasks
- QA Lead for verification

## Reads

- resolved project `.mlgs/state.yaml`
- project `production/task-plan.md`
- project `production/tasks/[task].md` if present
- relevant design/system docs
- relevant Unity files

## Writes

- Unity project files in approved paths
- project `production/tasks/[task].md`
- test or QA evidence

## Procedure

1. Resolve the task from user request or task plan.
2. Confirm production is unblocked. If not, continue only when the user explicitly asks and record risk.
3. Read design, technical plan, and existing code.
4. Make a focused implementation plan.
5. Ask only if the edit affects protected paths, packages, project settings, core architecture, or unclear gameplay behavior.
6. Implement the task.
7. Run available compile, smoke, or test checks.
8. Record:
   - files changed
   - acceptance criteria covered
   - tests/checks run
   - deviations and risks
   - trace event with lead/supporting agents, skills used, files read/written, decisions, and verification

## Completion

- Task is implemented or blocked with a clear reason.
- Verification evidence is recorded.
