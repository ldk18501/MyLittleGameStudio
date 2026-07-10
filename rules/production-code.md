# Production Code Rules

These rules apply after prototype approval. The goal is maintainable game code sized to the project, not enterprise ceremony.

## Boundaries

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

## Verification

- Give pure rules EditMode tests where practical; give Unity integration and lifecycle behavior PlayMode or smoke evidence.
- Cover normal, edge, failure, feedback, performance, and cleanup paths.
- Run `tools/test-production-code.ps1` for milestone reviews. Treat its output as a focused heuristic audit, then perform architecture review on the changed module.
- Record intentional debt with owner, reason, removal milestone, and acceptance impact.
