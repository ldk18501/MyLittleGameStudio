# Command: productize

## Purpose

Move a playable prototype toward a finished game through Vertical Slice, Content Complete, Alpha, and Beta gates. This route exists specifically to prevent production from remaining demo-like.

## Lead

Producer

## Supporting Agents

- Game Designer for feature and content completeness
- Unity Architect and Gameplay Developer for production architecture
- UI/UX Developer and Technical Artist for final-look integration
- QA Lead for structured gate evidence

## Stage order

```text
prototype -> vertical-slice -> production -> alpha -> beta -> release-candidate
```

Do not skip a stage by merely creating its files. `tools/test-quality-gate.ps1` must pass the structured report, and art gates must also pass the asset manifest validator.

## Flow

1. Bind the requested or nearest project with `tools/new-project-context.ps1`, then resolve state through that context and evaluate catalog gates.
2. Select the earliest incomplete stage; do not work from the declared phase alone.
3. Create or refresh its report with:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/new-quality-gate.ps1 -ProjectRoot <UnityProject> -Stage <stage>
   ```

4. Convert every failed or missing check into a bounded task with acceptance criteria and evidence path. Acquire non-overlapping leases before executing project writes.
5. Validate the explicit release scope with `tools/validate-release-scope.ps1`; never infer completeness from implemented files alone. Missing planned counts, tutorial beats, UI screens, configuration sources, audio, or art are blockers.
6. For production code, read `rules/production-code.md`; run `tools/test-production-code.ps1` and attach the report at Content Complete or earlier.
7. For art, run the formal `generate-art` route and validate the screen-level visual scene contract before asset approval. Every product gate revalidates the stage-scoped art manifest and approved scene contract, so stale comparison, lifecycle, import, reference, or in-game evidence fails later stages too. A correctly skinned UGUI panel over a background is not final-look evidence when the target requires a layered scene or diegetic display.
8. Validate framework adoption and presentation architecture. A Vertical Slice fails if production gameplay is still a Demo/Test implementation, bypasses the existing framework, or implements 2D core play through UGUI without an approved pure-UI decision.
8. Complete the stage definition:
   - Vertical Slice: one representative final-quality player journey, final-look target, production architecture, performance budget, and asset pipeline all proven together.
   - Content Complete: every enumerated release-scope feature, planned content quantity, tutorial beat, UI screen, production configuration, audio set, and formal art item is integrated; placeholders, unfinished flows, temporary code, and missing references are removed.
   - Alpha: a new player can complete the first-session journey without developer guidance; all release-scope items are verified; blockers are fixed; performance, localization integrity, missing references, and crash-free smoke are verified.
   - Beta: target-device regression passes; icon, localization, crash/error check, and known-issues review are complete.
9. Put existing project-relative evidence files on every required check, keep `blockers` empty, set `ownerApproval: true` only after the owner approves the major gate, then validate:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-quality-gate.ps1 -ProjectRoot <UnityProject> -Stage <stage>
   ```

10. Update state phase from the unified gate evaluator, not from intention or a version string.
11. Record trace with the bound context/invocation, release completed leases, and report the next incomplete check.

## Completion

The current productization gate passes with evidence, or its blockers are converted into actionable tasks.
## Objective gate enforcement

For each failed stage check, create or update a bounded work package. Before a quality report can pass, set its declared verdict, run `tools/run-objective-checks.ps1` over the report, and require both `declaredVerdict: pass` and `objectiveVerdict: pass`. Formal art additionally requires fail-closed Art Director and QA review records.
## Profile, baseline, and UI enforcement

At every product gate, validate profile coverage, the frozen design baseline, and the UI screen contract before evaluating content quantity or polish. Profile minimums cannot be waived by calling a smaller result ?1.0?. A stale baseline invalidates mapped stages; an unlisted, placeholder, target-unlinked, or demo-only UI screen is incomplete.
## Capability readiness gate

Product gates derive required capabilities from the stage-scoped asset manifest. Every required provider must be `ready` with evidence; Unity validation and visual comparison must explicitly support verification. Missing capability readiness is a production blocker, not permission to ship placeholders or waive formal review.
