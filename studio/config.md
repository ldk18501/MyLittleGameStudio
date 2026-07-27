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
- User runtime pointer: `$CODEX_HOME/mlgs/current-project.json` or `~/.codex/mlgs/current-project.json`; it is navigation convenience, not write authority.
- Per-project runtime: `$CODEX_HOME/mlgs/projects/<project-id>/` with bound contexts, leases, trace, runtime, and dashboard data.
- Canonical project state: `.mlgs/state.json` inside the active game project.
- Legacy `.mlgs/state.yaml` remains readable and can be explicitly migrated.
- Do not duplicate active project, phase, or participation in other root files.
- Bind every routed task to one immutable project context. Different projects may run in parallel; same-project writes require non-overlapping leases.
- Project notes can live under the active project, but must not conflict with `.mlgs/state.json`.

## Safety Strategy

- Routine planning, documents, focused code edits, trace writes, dashboard refreshes, and local checks can proceed under the selected participation level.
- Destructive operations, dependencies, packages, Unity project settings, scenes/prefabs with broad impact, build settings, and core architecture changes require explicit approval.
- External Unity projects require `activeProject.approvedWritePaths` before production edits; preflight and post-change validation enforce it.

## Prototype Strategy

- Use lightweight HTML prototypes for uncertain loops when Unity-specific behavior is not the risk.
- Use Unity greybox prototypes when risk comes from physics, input, camera, UI, rendering, or engine integration.
- If the owner wants to skip, record `prototype.policy: skipped-with-risk` and the reason.
- A prototype is a deliberately small risk test. Passing it never redefines the release product as the prototype plus polish.

## Content Design Strategy

- Owner participation controls how often MLGS asks, not how small the game is. Sparse input under `low` participation grants MLGS authority to research, diverge, synthesize, quantify, and draft a fuller product.
- Classify intended depth as `hyper-casual`, `light`, `standard`, or `deep`. Reference-led, explicitly non-light, and 10+ hour promises default to at least `standard`; 30+ hour promises default to `deep` unless the owner narrows them.
- For `standard`/`deep`, reference-led, or sparse low-participation concepts, perform current web research across direct, adjacent, and contrast references. Record source URLs, observations, inferences, adaptations, and rejected patterns. Never fabricate research or copy protected expression.
- Before planning, compare at least three structurally different product shapes. Select a coherent combination of loop horizons, interacting systems, content families, progression arcs, variation/repetition controls, and endgame.
- `design/content-architecture.json` is the machine-audited product-depth contract. Its content budget must support the promised minimum playtime, and its systems/content families must map to release scope.
- Production is blocked when the formal result is only a visually improved prototype, when content is repeated without meaningful variation, or when system count exists without interaction.

## Adaptive Code Strategy

- Classify Unity code work as `new-project/lightweight`, `small-existing/standard`, or `large-framework/deep`; allow an owner/architect override with a recorded reason.
- New projects may establish the smallest useful foundation without imitating nonexistent legacy patterns.
- Small existing projects learn neighboring modules and at least two representative code examples, but may introduce a better isolated foundation when the tradeoff is explicit.
- Large framework projects require dependency-graph structural evidence through CodeGraph, Roslyn, or a documented manual review; no single provider is mandatory.
- Existing code is evidence, not an absolute rule. `extend`, `adapt`, `replace`, `create-new-foundation`, and `isolated-new-module` are all valid when the selected intensity and approved change plan support them.

## Art Generation Strategy

- An approved visual target carries a structured `styleLock` for palette roles, temperature, saturation, contrast, lighting, materials, texture, shape language, UI treatment, invariants, and forbidden drift.
- Production prompt metadata must include the approved target image as a real reference, copy the style lock exactly, and restate every preserve/avoid rule on each edit.
- `gpt-image-2` canvases obey the current minimum/maximum pixel, 16-pixel edge multiple, edge length, aspect-ratio, and opaque-background constraints. Smaller requested game assets are local post-process sizes.
- Batch only 2–9 low-detail icons, portraits, or thumbnails with the same target into a registered sheet. Split only explicit rectangles with local matte removal, margin/component validation, and per-item reports.
- Every formal asset has a Unity usage JSON in addition to its import recipe, so tint, material, sizing, anchors, sorting, state sprites, and real target components are explicit.
- Approved UI target screens are decomposed before asset generation. `design/ui/screen-inventory.json` records every visible component, its exact source rectangle, state set, reuse key, and generated/reused/procedural/typography decision. Generated components must have matching `screen-derived` manifest entries with component-specific style descriptions, prompt cores, preserve/avoid rules, and text policy.
- 只有 2D 角色采用骨骼分件、Sprite Skin 或含骨骼的混合动画时，才应用 `rules/character-animation-art.md` 和项目内角色动画合同。纯帧动画、静态 Sprite、UI、图标和场景资源继续原流程，不增加骨骼合同负担。
- 骨骼角色在生成前锁定方向专用配方、生产视图、头身比、姿势引导、Rig Master、骨骼、唯一部件所有权、Pivot/Socket、接缝和 Unity 组装。AI 爆炸拆件只能是草稿；正式部件来自作者图层、人工分层或确定性蒙版。
- 骨骼角色 prompt 从内置 `templates/art-recipes/`、项目 `styleLock` 和角色合同合成，复制 `animationContractSnapshot` 并重复所有 preserve/avoid；不再临时自由发挥拆件提示词。

## Verification Cadence

- New work packages default to task-boundary verification: aggregate small edits, run focused inner-loop checks only for acceptance-critical or risk-triggered changes, and run the routine compile/acceptance/integration suite once per attempt.
- Reuse passing evidence until a relevant input changes. Shared contracts, scene/prefab wiring, persistence/configuration, a previous failure, build/phase gates, or an owner request trigger broader regression.
- Broader regression changes test breadth, not packaging authority. Compile, editor tests, PlayMode, data checks, and platform preflight remain the default.

## Package Build Cadence

- A new project may perform one initial target-platform package build after platform confirmation to prove the toolchain. Record it in `.mlgs/build-policy.json`.
- After initial validation passes, routine code/content/UI/art/configuration changes, fixes, regressions, and Vertical Slice through Beta gates never trigger an automatic package build.
- Development package builds require an explicit request in the owner's current message, normally for device-specific testing. Historical preferences and participation level are insufficient.
- Automatic package builds resume only in formal Release Candidate and Release flows. Build preflight is always non-packaging.
- Never treat `build-or-phase-gate`, scene/prefab wiring, a full regression, or an available build environment as package-build authorization.

## Productization Strategy

Product versions do not advance phases. `0.1.x` is a prototype/pre-release label. A game may be called `1.0.0` or later only after the Release gate passes against an explicit `production/scope/release-scope.json`; all required scope items must be verified, all formal art approved against the visual targets, and no release-scope placeholders may remain.

Production can start when either:

1. concept and plan are approved, and prototype passed; or
2. concept and plan are approved, and prototype was explicitly skipped with recorded risk.

After production unlock, projects progress through enforced milestones:

1. Vertical Slice proves a representative final-quality journey, production code structure, art pipeline, and performance target.
2. Content Complete removes placeholders and finishes all release-scope features, content, references, and error paths.
3. Alpha proves full-flow stability, missing-reference cleanup, performance, localization integrity, and crash-free smoke.
4. Beta proves target-platform preflight plus application icon, localization, crash/error, and non-packaging regression checks; a fresh package is deferred to Release Candidate unless the owner explicitly requests one.
5. Release Candidate locks the final game-content evidence and known issues.

Quality gates parse structured JSON evidence and, when applicable, the art asset manifest. File presence alone never passes these milestones.

The release scope is enumerated before production and must cover features, content quantities, onboarding/tutorial beats, UI screens, configuration/data sources, audio, art, localization, operations readiness, and builds. “All content” always means all items in that approved manifest, not all items the implementation happened to create.

The approved visual target is the production reference. HTML prototypes prove interaction hypotheses only; their colors, panels, buttons, and layout are not art direction and must not be carried into Vertical Slice unless the visual target explicitly approves them.

MLGS release scope includes the game-side implementation and evidence needed for monetization, analytics/consent, remote configuration or LiveOps, service failure behavior, application icon, localization, crash/error checks, and final builds when they apply. Store-console accounts, legal/rating submissions, hosting deployment, and marketing execution may use external owners/tools, but the handoff, required game artifacts, and blocker status must be explicit in `production/release/operations-readiness.md`.

