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

- resolved project `.mlgs/state.json` or legacy `.mlgs/state.yaml`
- project `design/concept-package.md`
- project `design/reference-analysis.md`
- existing Unity project structure when available
- existing `production/task-plan.md`

## Write

- project `design/systems/[system].md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- project `design/art/style-bible.md`
- project `production/assets/asset-manifest.json`
- optional project `design/assets/asset-requirements.md`
- optional project `design/ux/[screen].md`
- project `.mlgs/state.json`

## Flow

1. Resolve active project. If no concept exists, draft minimal assumptions from the request or route to internal `brainstorm`.
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
   - module/assembly boundaries and dependency direction
   - composition root, lifecycle/cancellation, error handling, save boundaries, and localization boundaries
6. Technical Artist initializes the formal art pipeline, writes the style bible, and creates manifest entries for every release-scope asset. Each asset receives a target milestone and import/reference strategy.
7. Producer writes `production/task-plan.md` with bounded tasks and explicit Vertical Slice, Content Complete, Alpha, Beta, and Release Candidate milestones. Production tasks must not be described as prototype shortcuts.
8. QA Lead checks that acceptance criteria cover normal, edge, failure, feedback, performance, integration, and content-completeness paths.
9. Decide prototype policy.
10. Under low participation, write the plan and ask only for phase approval.
11. Under medium/high participation, show concise options when architecture or scope choices matter.
12. Update state and next action.
13. Record trace.

## Completion

Systems, production architecture, milestone task plan, art pipeline, and prototype policy exist or blockers are explicit.

