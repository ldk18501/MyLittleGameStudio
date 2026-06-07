# Command: concept

## Purpose

Create or revise the concept package.

## Lead

Creative Director

## Supporting Agents

- Producer
- Game Designer
- Technical Artist
- UI/UX Developer when interface is central

## Reads

- project `design/references.md`
- project `design/reference-analysis.md`
- existing `design/concept-package.md` if present

## Writes

- project `design/concept-package.md`
- project `.mlgs/state.yaml`

## Procedure

1. Resolve active project.
2. Summarize user intent and reference analysis.
3. Draft:
   - one-sentence pitch
   - core fantasy
   - target player
   - 3-5 gameplay pillars
   - anti-goals
   - core loop
   - visual direction
   - MVP and stretch scope
   - risks and assumptions
4. In high automation, write the recommended package and ask for gate approval.
5. In medium/low automation, show a compact draft before finalizing.
6. If approved, set `approvals.concept_package: true` and next action `design-plan` in project state.

## Completion

- Concept package exists.
- Approval state is recorded.
