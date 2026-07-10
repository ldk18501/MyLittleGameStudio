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

1. Resolve state and evaluate catalog gates.
2. Select the earliest incomplete stage; do not work from the declared phase alone.
3. Create or refresh its report with:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/new-quality-gate.ps1 -ProjectRoot <UnityProject> -Stage <stage>
   ```

4. Convert every failed or missing check into a bounded task with acceptance criteria and evidence path.
5. For production code, read `rules/production-code.md`; run `tools/test-production-code.ps1` and attach the report at Content Complete or earlier.
6. For art, run the formal `generate-art` route and validate the required manifest scope.
7. Complete the stage definition:
   - Vertical Slice: one representative final-quality player journey, final-look target, production architecture, performance budget, and asset pipeline all proven together.
   - Content Complete: all release-scope features and content exist; placeholders, unfinished flows, temporary code, and missing references are removed.
   - Alpha: full playthrough works; blockers are fixed; performance, localization integrity, missing references, and crash-free smoke are verified.
   - Beta: target-device regression passes; icon, localization, crash/error check, and known-issues review are complete.
8. Put concrete evidence on every required check, keep `blockers` empty, set `ownerApproval: true` only after the owner approves the major gate, then validate:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-quality-gate.ps1 -ProjectRoot <UnityProject> -Stage <stage>
   ```

9. Update state phase from the unified gate evaluator, not from intention.
10. Record trace and the next incomplete check.

## Completion

The current productization gate passes with evidence, or its blockers are converted into actionable tasks.

