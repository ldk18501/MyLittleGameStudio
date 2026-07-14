# Production Code Rules

These rules apply after prototype approval. The goal is maintainable game code sized to the project, not enterprise ceremony.

## Boundaries

- Before changing production code, complete and pass `design/framework-adoption.json`. Existing projects must adopt or explicitly adapt their composition root, module lifecycle, events, configuration, persistence, UI framework, assemblies, and asset loading instead of creating parallel one-off managers.
- Complete `design/presentation-architecture.json` before implementation. For 2D games, core gameplay defaults to scene objects using `SpriteRenderer`/`TilemapRenderer`, `Animator`, particles, shaders, and world cameras. UGUI/UI Toolkit is limited to HUD, menus, overlays, dialogs, inventories, tooltips, and other presentation surfaces.
- A 2D core gameplay implementation may use UGUI only when the whole game is explicitly classified as `pureUIGame` and owner-approved, or a narrow path is recorded as an owner-approved exception.
- Separate gameplay rules/state from Unity presentation and scene wiring when the rules can be tested without a frame.
- Use explicit module dependency direction. A feature may depend on shared contracts/core; shared code must not depend back on a feature.
- Use asmdefs when they create real runtime/editor/test or feature boundaries. Do not create one assembly per class.
- Keep composition in a clear bootstrap/installer/composition root. Do not use scene searches as hidden dependency injection.
- UI reads view models/state and issues commands/events; it does not own authoritative gameplay rules.
- Keep stable content/config in ScriptableObjects or validated data files; keep mutable runtime/save state separate.

## Lifecycle and errors

- Make subscription cleanup, cancellation, pooled-object reset, and scene unload behavior explicit.
- Do not use `async void` except Unity event entry points with contained exception handling.
- Validate serialized references and configuration early; fail with actionable context instead of a later null reference.
- Do not swallow exceptions or log the same recoverable failure every frame.
- Give save/config data a version and an explicit failure or migration path when persistence exists.

## Prohibited production shortcuts

- No `GameObject.Find`, `FindObjectOfType`, `FindAnyObjectByType`, or `SendMessage` in production paths without an approved, documented exception.
- No `NotImplementedException`, empty handlers, fake success, debug-only unlocks, or placeholder branches in release scope.
- No untracked `TODO`, `FIXME`, `HACK`, `TEMP`, `Demo`, or `Prototype` code surviving the milestone that consumes it.
- No runtime string-path asset lookup as the default integration mechanism. Prefer serialized references, ScriptableObjects, Prefabs, or Addressables where justified.
- No feature completion claim while the real scene, UI, content, save/error path, or asset reference remains unwired.
- No `Demo`, `Prototype`, `Sample`, `Mock`, `Temp`, or test-named scripts under production runtime paths. Test fixtures live in test assemblies/folders; disposable prototype code does not become the feature implementation.
- No authoritative gameplay transitions, combat/reward calculations, spawning, wave/turn resolution, or persistent state inside UGUI views and click handlers. UI emits commands/events and renders state owned by gameplay/application modules.
- No new standalone `Manager`/singleton/service when the adopted framework already owns that responsibility. Extend its module/factory/service boundary or record an approved architecture change.

## Verification

- Give pure rules EditMode tests where practical; give Unity integration and lifecycle behavior PlayMode or smoke evidence.
- Cover normal, edge, failure, feedback, performance, and cleanup paths.
- Run `tools/test-framework-adoption.ps1`, `tools/test-presentation-architecture.ps1`, and `tools/test-production-code.ps1` for milestone reviews. All three fail closed; then perform architecture review on the changed module.
- Record intentional debt with owner, reason, removal milestone, and acceptance impact.
