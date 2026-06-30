# Command: plan

## Purpose

Turn the concept into Unity systems, technical plan, task plan, asset needs, and prototype policy.

This is the simplified Codex-only replacement for `design-plan`.

## Lead

Game Designer

## Supporting Agents

- Producer
- Unity Architect
- Gameplay Developer
- UI/UX Developer
- Technical Artist
- QA Lead

## Read

- resolved project `.mlgs/state.yaml`
- project `design/concept-package.md`
- project `design/reference-analysis.md`
- existing Unity project structure when available
- existing `production/task-plan.md`

## Write

- project `design/systems/[system].md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- optional project `design/assets/asset-requirements.md`
- optional project `design/ux/[screen].md`
- project `.mlgs/state.yaml`

## Flow

1. Resolve active project. If no concept exists, draft minimal assumptions or route to `/mlgs brainstorm`.
2. Use `mlgs-unity-mechanics` for gameplay systems, input feel, tuning, feedback, or performance-sensitive runtime behavior.
3. Identify MVP systems and skip non-MVP systems.
4. For each MVP system, write:
   - purpose
   - player experience
   - rules
   - tuning ranges
   - edge cases
   - dependencies
   - UI/VFX/audio hooks
   - acceptance criteria
5. Unity Architect writes:
   - Unity version/platform assumptions
   - architecture boundaries
   - ScriptableObject/config strategy
   - scene/prefab strategy
   - package risks
   - testing strategy
   - performance guardrails
6. Producer writes `production/task-plan.md` with 1-3 day tasks.
7. QA Lead checks that acceptance criteria cover normal, edge, failure, feedback, and performance paths.
8. Decide prototype policy.
9. Under low participation, write the plan and ask only for phase approval.
10. Under medium/high participation, show concise options when architecture or scope choices matter.
11. Update state and next action.
12. Record trace.

## Completion

Systems, tech plan, task plan, and prototype policy exist or blockers are explicit.
