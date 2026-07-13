# Production Configuration Plan

## Configuration inventory

| Config ID | System/content owner | Source format | Runtime consumer | Validation | Authoring workflow | Release-scope ID |
|---|---|---|---|---|---|---|
| CFG-001 |  | ScriptableObject / generated table / JSON |  |  |  |  |

## Rules

- Release tuning, content definitions, rewards, progression, spawn tables, and economy values must be data-driven when they are stable content rather than code behavior.
- Every production configuration source has schema/range/reference validation and an actionable failure path.
- Prototype constants must be migrated or explicitly justified before Content Complete.
- Configuration implementation and validation evidence must be listed in `production/scope/release-scope.json` as `type: configuration`.
