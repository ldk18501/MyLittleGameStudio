# Command: design-plan

## Purpose

Turn the concept into system designs, Unity technical plan, task plan, asset requirements, and test strategy.

## Lead

Game Designer

## Supporting Agents

- Producer
- Unity Architect
- Gameplay Developer
- UI/UX Developer
- Technical Artist
- QA Lead

## Reads

- project `design/concept-package.md`
- project `design/reference-analysis.md`
- existing Unity project structure when available

## Writes

- project `design/systems/[system].md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- optional project `design/assets/asset-requirements.md`
- optional project `design/ux/[screen].md`
- project `.mlgs/state.yaml`

## Procedure

1. Resolve active project.
2. Confirm concept package exists or draft missing concept assumptions.
3. Decompose MVP systems.
4. For each MVP system, create a compact system design:
   - purpose
   - player experience
   - rules
   - edge cases
   - tuning ranges
   - dependencies
   - acceptance criteria
5. Unity Architect drafts the technical plan:
   - Unity version and platform
   - architecture
   - data/content strategy
   - package risks
   - scene/prefab strategy
   - testing strategy
6. Producer creates `production/task-plan.md`.
7. QA Lead checks acceptance criteria.
8. Decide prototype policy:
   - recommended for uncertain core loop
   - Unity greybox if engine interaction is the risk
   - skipped-with-risk if the user wants direct production
9. Record approval and next action in project state.

## Completion

- MVP systems are documented.
- Technical plan exists.
- Task plan exists.
- Prototype policy is recorded.
