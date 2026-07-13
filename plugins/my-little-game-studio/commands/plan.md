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
- project `design/player-journey.md`
- project `design/onboarding.md`
- project `production/data/configuration-plan.md`
- project `production/release/operations-readiness.md`
- project `production/scope/release-scope.json`
- project `design/art/style-bible.md`
- project `production/assets/asset-manifest.json`
- optional project `design/assets/asset-requirements.md`
- optional project `design/ux/[screen].md`
- project `.mlgs/state.json`

## Flow

1. Resolve active project. If no concept exists, draft minimal assumptions from the request or route to internal `brainstorm`.
2. Use `mlgs-unity-mechanics` for gameplay systems, input feel, tuning, feedback, or performance-sensitive runtime behavior.
3. Run `tools/init-production-pipeline.ps1`. Identify the explicit `1.0.0` release scope before identifying the smaller prototype/Vertical Slice subset. Do not silently turn unimplemented release content into backlog.
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
6. Game Designer and Producer enumerate `production/scope/release-scope.json`: every release feature, content group with planned quantity, tutorial beat, UI screen, configuration/data source, audio set, art set, localization target, operations-readiness decision, and build. Every item links to a source design file and a target milestone.
7. UI/UX Developer writes the end-to-end player journey and onboarding/tutorial flow. The Vertical Slice must include a real first-session path; Content Complete must include all teach/practice/verify/recovery beats.
8. Unity Architect writes `production/data/configuration-plan.md` for tuning, progression, economy, rewards, spawn/content tables, validation, runtime consumers, and failure behavior. Prototype constants receive migration tasks.
9. Producer and Unity Architect write `production/release/operations-readiness.md`: product model, game-side monetization/analytics/consent/remote-config or LiveOps requirements, service failure behavior, and named external owners for store/legal/deployment handoffs. “Not applicable” must be an explicit verified decision.
10. Technical Artist derives the style bible and every art manifest entry from approved visual-target IDs. The manifest must cover every art scope item, not only assets already generated.
11. Producer writes `production/task-plan.md` with bounded tasks and explicit Vertical Slice, Content Complete, Alpha, Beta, and Release Candidate milestones. Every release-scope item has task coverage; production tasks must not be described as prototype shortcuts.
12. QA Lead checks that acceptance criteria cover normal, edge, failure, feedback, performance, integration, content quantity, first-session comprehension, configuration validation, operations readiness, and visual-target comparison.
13. Decide prototype policy.
14. Under low participation, write the plan and ask only for phase approval.
15. Under medium/high participation, show concise options when architecture or scope choices matter.
16. Update state and next action.
17. Record trace.

## Completion

Systems, production architecture, milestone task plan, art pipeline, and prototype policy exist or blockers are explicit.

## Executable planning contract

Every production task is also a machine-readable work package. Use one verifiable objective per package, link release-scope IDs, record non-goals and dependencies, choose the smallest execution strategy that fits the risk, and cap rework at one to five attempts. Every success criterion needs project-relative evidence plus at least one objective check.
## Production contracts

1. Select the closest Unity profile with `tools/select-game-profile.ps1`; any deviation is an explicit `projectOverrides` entry, not silent omission.
2. Expand every `releaseScopeRequirement` into release-scope items with matching `profileRequirementIds` and sufficient `plannedCount`.
3. Enumerate every profile-required UI screen in `design/ui/screen-inventory.json`, including states, controls, visual targets, implementation path, formal asset IDs, audio IDs, and evidence.
4. Run `tools/validate-game-profile-coverage.ps1`.
5. Freeze the approved plan with `tools/freeze-design-baseline.ps1`. Production cannot start from a draft or stale baseline.
## Capability and orchestration plan

Refresh `production/capabilities/capability-manifest.json` while planning the asset list. Missing image, Sprite, mesh, animation, audio, video, Unity import/validation, or visual-comparison providers become explicit dependencies and budget risks. For non-direct tasks, create `production/execution/<work-package-id>.json` with `tools/new-execution-strategy.ps1`; cap parallel logical groups and synthesis rounds.
