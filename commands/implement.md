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
- project `design/framework-adoption.json`
- project `design/presentation-architecture.json`
- relevant entries in project `design/art/visual-scene-contract.json`
- project `design/code/codebase-profile.json`
- project `design/code/module-map.json`
- project `production/context-packs/[task-id].json`
- project `production/change-plans/[task-id].json`

## Write

- Unity project files inside approved write paths
- project `production/tasks/[task].md`
- tests or QA evidence
- project `.mlgs/state.json` when next action changes

## Flow

1. Resolve the requested or nearest project, then create one bound context with `tools/new-project-context.ps1`. Keep its project root, runtime root, context path, and invocation ID fixed for the task.
2. Parse the task from the user request, task plan, or status next options.
3. Create the work package, then run `tools/new-code-task.ps1 -TaskId <id>`. Fill the context pack and change plan at the intensity selected by the codebase profile.
4. Run `tools/test-code-task.ps1 -TaskId <id>`. For new projects, keep the context light and design the minimum useful foundation. For small projects, read the target module and two sibling/style examples. For deep projects, record callers, callees, base types, subscribers, data owners, and impact evidence.
5. Acquire a write lease for the approved planned paths, then run `tools/preflight-task.ps1 -Command implement -TaskId <id> -ContextPath <context-path>`. `-AcceptRisk` never waives missing or stale code understanding.
6. Read exactly the approved context pack. Do not start from the design document alone and do not expand into unrelated modules.
5. Determine whether the work is disposable prototype code or production code. After prototype approval, default to production code; a temporary shortcut requires a tracked removal task before Vertical Slice approval.
6. Link the task to one or more IDs in `production/scope/release-scope.json`. After the prototype phase, UI/presentation tasks must read the approved visual target and style bible; do not reproduce HTML prototype styling unless explicitly approved there.
8. Apply `rules/production-code.md`: preserve the adopted framework and module dependency direction, separate rules from Unity presentation, use explicit composition and serialized references, make lifecycle cleanup/cancellation explicit, keep config data-driven, and expose errors with context. Runtime production paths may not contain Demo/Test/Prototype implementations.
9. For 2D non-pure-UI games, build core gameplay as scene objects with SpriteRenderer/TilemapRenderer and suitable animation/VFX components. UGUI implements only HUD, menus, overlays and recorded exceptions; UI views never own authoritative gameplay rules.
7. Use `mlgs-unity-mechanics` when the task involves gameplay mechanisms, input feel, feedback, object count, pooling, timing, or performance-sensitive runtime logic.
8. For DOD/instancing/bullets/mass objects, read `dod-performance.md` and record the chosen L1-L5 tier.
9. Under high participation, present a concise implementation plan before meaningful edits.
10. Under low/medium participation, implement directly unless the edit is high-risk.
11. Follow the work package `verificationPolicy`. Default to `task-boundary`: aggregate the small edits inside the approved task, use an inner-loop check only when a change is risky or directly exercises an acceptance criterion, then run compile, task acceptance, and one integration smoke pass at the work-package boundary. Do not rerun a passing suite after every helper, field, or UI callback unless a relevant input changed, a prior check failed, or a declared full-regression trigger applies. A feature is not done if only an isolated component works but its actual scene/UI/data flow is unwired.
14. After edits, mark the task context/plan implemented, record the actual changed paths, run post-impact analysis when required, then run `tools/test-code-conformance.ps1` and `tools/test-production-code.ps1 -TaskId <id> -ChangedPaths <paths>`.
13. Run `tools/validate-changes.ps1 -ContextPath <context-path>` while the same lease is active; reject edits outside its claimed paths, project planning paths, or approved Unity write paths.
14. Record:
    - files changed
    - acceptance criteria covered
    - verification result
    - deviations and risks
    - next recommended command
15. Record trace with the bound context and invocation ID, then release the project lease.

## Ask Before

- changing packages, project settings, scenes/prefabs with broad impact, or core architecture
- editing outside approved paths
- changing gameplay rules beyond the task
- making a major product feel choice under medium/high participation

## Completion

The task is integrated, production-structured, and verified against real acceptance criteria, or blocked with a specific reason. “Works in a demo scene” is not completion evidence after the prototype phase.
## Work package contract

Production implementation starts from `production/work-packages/<id>.json`, created by `tools/new-work-package.ps1`. The package must name its objective, release-scope IDs, non-goals, owner, dependencies, strategy, success criteria, objective checks, and a maximum of five attempts.

After implementation, run `tools/run-objective-checks.ps1`, record the attempt with `tools/complete-work-package-attempt.ps1`, and validate with `tools/test-work-package.ps1`. A declared pass without an objective pass is a failure, not completion.
## Design-change guard

Run `tools/test-design-baseline.ps1` before production edits. If a frozen design source changed, stop the affected work packages and gates, review the generated change-impact report, update scope/assets/tasks, and deliberately re-freeze a new baseline version. UI implementation also has to satisfy its screen contract; a standalone demo panel is not evidence.
## Risk-based orchestration

Use `direct` by default. Choose `pipeline` for dependent handoffs, `fan-out-and-synthesize` for independent specialist passes, `adversarial-review` for high-risk architecture/visual/release decisions, and `loop-until-done` only when objective checks define the stop condition. Non-direct work must have an execution strategy file and still obey the work-package attempt budget.
