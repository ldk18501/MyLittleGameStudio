# Command: prototype

## Purpose

Validate the core loop or risky interaction before production, without making the prototype a rigid blocker for every project.

## Lead

Gameplay Developer

## Supporting Agents

- Producer
- Game Designer
- Technical Artist
- UI/UX Developer
- QA Lead

## Reads

- project `design/concept-package.md`
- project `design/systems/*.md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- project `.mlgs/state.yaml`

## Writes

- project `prototype/prototype-plan.md`
- project `prototype/html/` or Unity greybox artifacts
- project `prototype/playtest-report.md`
- project `.mlgs/state.yaml`

## Procedure

1. Resolve active project.
2. Read prototype policy from project state.
3. If the user asks to skip, record:
   - `prototype.policy: skipped-with-risk`
   - `prototype.verdict: skipped`
   - skip reason
   - production risk
4. If building:
   - define the minimum playable scope
   - prefer readable visual placeholders over text-only objects
   - build HTML prototype or Unity greybox depending on risk
   - run locally when practical
   - create playtest report
5. Record verdict:
   - pass
   - revise
   - return-to-design
   - skipped
6. If pass or skipped-with-risk and design-plan is approved, set production unblocked.

## Completion

- Prototype exists and is evaluated, or skip risk is explicitly recorded.
