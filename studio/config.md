# MyLittleGameStudio Core Config

This file is the small always-read studio kernel. Domain policies live in `rules/studio/` and are loaded only when the selected route needs them.

## Studio

- Platform: Codex only.
- Engine: Unity only.
- Language: C#.
- Owner: user.
- Coordinator: Producer.
- Default owner participation: `medium`.
- Public entry: `/mlgs` followed by natural language.

## State

- Canonical game state: `<ProjectRoot>/.mlgs/state.json`.
- User pointer is read-only navigation fallback, never write authority.
- Bind one immutable project context per routed project task.
- Same-project writes require a path lease; different projects may run independently.
- Project runtime, trace, contexts, leases, and dashboard data live under `$CODEX_HOME/mlgs/projects/<project-id>/`.

## Safety

- Routine planning, focused approved edits, trace writes, and local checks follow owner participation.
- Destructive work, packages/dependencies, broad scene or prefab changes, Unity/build settings, core architecture, monetization direction, and phase gates require explicit approval.
- Project writes must pass preflight and post-change validation with the same context and active lease.

## Route-Specific Policies

Read only the policies needed by the selected route:

- Brainstorm, plan, or product depth -> `rules/studio/content-design.md`
- Implement, fix, or code review -> `rules/studio/adaptive-code.md`
- Generate art, art review, or art gates -> `rules/studio/art-generation.md`
- Test, build, or verification cadence -> `rules/studio/verification-build.md`
- Vertical Slice through Release -> `rules/studio/productization.md`

## Core Invariants

- Prototype evidence never becomes the production visual specification.
- Low owner participation reduces questions, not product scope or quality.
- Existing project architecture is inspected and deliberately adopted or adapted before production code.
- Formal art and product gates remain evidence-driven and fail closed.
- Ordinary development does not create a package build without current explicit owner authorization.
- Every routed task records trace and refreshes its runtime dashboard.
