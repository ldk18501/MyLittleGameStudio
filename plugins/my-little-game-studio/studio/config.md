# MyLittleGameStudio Config

## Studio Model

- Platform: Codex only.
- Engine: Unity only.
- Language: C#.
- Studio style: compact AI indie game studio.
- Owner: user.
- Default coordinator: Producer.
- Default owner participation: `medium`.

## Product Goals

- Start through `/mlgs` followed by natural language; keep `/mlgs start` and older `/mlgs-start` text as compatibility aliases.
- Guide the owner into either a new Unity game or adoption of an existing project.
- Keep one memorable entry point and let the Producer route natural-language requests.
- Let specialist agents handle their domains without making the owner manage internal process.
- Preserve a visible dashboard of staff activity.
- Prefer autonomy by default, with configurable owner participation.

## State Strategy

- Root state template: `studio/state.json`.
- User runtime pointer: `$CODEX_HOME/mlgs/current-project.json` or `~/.codex/mlgs/current-project.json`.
- Canonical project state: `.mlgs/state.json` inside the active game project.
- Legacy `.mlgs/state.yaml` remains readable and can be explicitly migrated.
- Do not duplicate active project, phase, or participation in other root files.
- Project notes can live under the active project, but must not conflict with `.mlgs/state.json`.

## Safety Strategy

- Routine planning, documents, focused code edits, trace writes, dashboard refreshes, and local checks can proceed under the selected participation level.
- Destructive operations, dependencies, packages, Unity project settings, scenes/prefabs with broad impact, build settings, and core architecture changes require explicit approval.
- External Unity projects require `activeProject.approvedWritePaths` before production edits; preflight and post-change validation enforce it.

## Prototype Strategy

- Use lightweight HTML prototypes for uncertain loops when Unity-specific behavior is not the risk.
- Use Unity greybox prototypes when risk comes from physics, input, camera, UI, rendering, or engine integration.
- If the owner wants to skip, record `prototype.policy: skipped-with-risk` and the reason.

## Adaptive Code Strategy

- Classify Unity code work as `new-project/lightweight`, `small-existing/standard`, or `large-framework/deep`; allow an owner/architect override with a recorded reason.
- New projects may establish the smallest useful foundation without imitating nonexistent legacy patterns.
- Small existing projects learn neighboring modules and at least two representative code examples, but may introduce a better isolated foundation when the tradeoff is explicit.
- Large framework projects require dependency-graph structural evidence through CodeGraph, Roslyn, or a documented manual review; no single provider is mandatory.
- Existing code is evidence, not an absolute rule. `extend`, `adapt`, `replace`, `create-new-foundation`, and `isolated-new-module` are all valid when the selected intensity and approved change plan support them.

## Productization Strategy

Product versions do not advance phases. `0.1.x` is a prototype/pre-release label. A game may be called `1.0.0` or later only after the Release gate passes against an explicit `production/scope/release-scope.json`; all required scope items must be verified, all formal art approved against the visual targets, and no release-scope placeholders may remain.

Production can start when either:

1. concept and plan are approved, and prototype passed; or
2. concept and plan are approved, and prototype was explicitly skipped with recorded risk.

After production unlock, projects progress through enforced milestones:

1. Vertical Slice proves a representative final-quality journey, production code structure, art pipeline, and performance target.
2. Content Complete removes placeholders and finishes all release-scope features, content, references, and error paths.
3. Alpha proves full-flow stability, missing-reference cleanup, performance, localization integrity, and crash-free smoke.
4. Beta proves target-device regression plus application icon, localization, and crash/error checks.
5. Release Candidate locks the final game-content evidence and known issues.

Quality gates parse structured JSON evidence and, when applicable, the art asset manifest. File presence alone never passes these milestones.

The release scope is enumerated before production and must cover features, content quantities, onboarding/tutorial beats, UI screens, configuration/data sources, audio, art, localization, operations readiness, and builds. “All content” always means all items in that approved manifest, not all items the implementation happened to create.

The approved visual target is the production reference. HTML prototypes prove interaction hypotheses only; their colors, panels, buttons, and layout are not art direction and must not be carried into Vertical Slice unless the visual target explicitly approves them.

MLGS release scope includes the game-side implementation and evidence needed for monetization, analytics/consent, remote configuration or LiveOps, service failure behavior, application icon, localization, crash/error checks, and final builds when they apply. Store-console accounts, legal/rating submissions, hosting deployment, and marketing execution may use external owners/tools, but the handoff, required game artifacts, and blocker status must be explicit in `production/release/operations-readiness.md`.

