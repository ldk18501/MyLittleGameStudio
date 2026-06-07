# MyLittleGameStudio Config

## Studio Model

- Studio style: small Unity indie game studio.
- Primary engine: Unity.
- Default automation: high for planning, medium for production code.
- Project owner: user.
- Coordinator role: Producer.

## State Policy

- Canonical state file: `studio/state.yaml`.
- Do not duplicate active project or current phase in separate root files.
- Historical notes may be kept in project-local `production/session-log.md`, but must not override `studio/state.yaml`.

## Safety Policy

- Normal code/document edits may proceed under the selected automation level.
- Destructive operations, dependency changes, package changes, build settings changes, and project-wide rewrites require explicit approval.
- External adopted projects require approved write paths before production edits.

## Prototype Policy

- HTML prototypes are recommended for uncertain core loops.
- Unity greybox prototypes are acceptable when Unity interaction, physics, UI, or rendering is the real risk.
- The prototype gate can be skipped by recording `prototype.policy: skipped-with-risk` in `studio/state.yaml`.

## Production Policy

Production may start when either:

1. concept and design-plan are approved, and prototype has passed; or
2. concept and design-plan are approved, and prototype is explicitly skipped with a recorded reason.

