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

- Root state template: `studio/state.yaml`.
- Local current project pointer: `studio/current-project.local.yaml`.
- Canonical project state: `.mlgs/state.yaml` inside the active game project.
- Do not duplicate active project, phase, or participation in other root files.
- Project notes can live under the active project, but must not conflict with `.mlgs/state.yaml`.

## Safety Strategy

- Routine planning, documents, focused code edits, trace writes, dashboard refreshes, and local checks can proceed under the selected participation level.
- Destructive operations, dependencies, packages, Unity project settings, scenes/prefabs with broad impact, build settings, and core architecture changes require explicit approval.
- External Unity projects require `approved_write_paths` before production edits.

## Prototype Strategy

- Use lightweight HTML prototypes for uncertain loops when Unity-specific behavior is not the risk.
- Use Unity greybox prototypes when risk comes from physics, input, camera, UI, rendering, or engine integration.
- If the owner wants to skip, record `prototype.policy: skipped-with-risk` and the reason.

## Production Gate

Production can start when either:

1. concept and plan are approved, and prototype passed; or
2. concept and plan are approved, and prototype was explicitly skipped with recorded risk.

