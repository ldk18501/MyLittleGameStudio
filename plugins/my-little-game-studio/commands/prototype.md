# Command: prototype

## Purpose

Validate the riskiest gameplay loop, interaction, Unity behavior, or performance assumption before production. Skipping is allowed when the owner accepts recorded risk.

## Lead

Gameplay Developer

## Supporting Agents

- Producer
- Game Designer
- Unity Architect
- Technical Artist
- UI/UX Developer
- QA Lead

## Read

- project `.mlgs/state.json` or legacy `.mlgs/state.yaml`
- project `design/concept-package.md`
- project `design/systems/*.md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`

## Write

- project `prototype/prototype-plan.md`
- project `prototype/html/` or Unity greybox artifacts
- project `prototype/playtest-report.md`
- project `.mlgs/state.json`

## Flow

1. Resolve active project and owner participation.
2. Read prototype policy and the main risk.
3. If the owner asks to skip, record:
   - `prototype.policy: skipped-with-risk`
   - `prototype.verdict: skipped`
   - skip reason
   - production risk
4. If building, define the smallest playable scope that can answer the risk.
5. Use `mlgs-unity-mechanics` only for the mechanism patterns needed.
6. Choose HTML when engine behavior is not the risk; choose Unity greybox for physics, input, camera, UI, rendering, Addressables, or performance risk.
7. Build or specify the prototype based on feasibility.
8. Run it locally when possible and create `playtest-report.md`.
9. Set verdict: pass, revise, return-to-plan, or skipped.
10. If pass or skipped-with-risk and plan is approved, set `approvals.productionUnblocked` and ensure the unified gate evaluator passes.
11. Record trace.

## Completion

Prototype evidence exists, or skipped risk is explicit.
