# Command: release

## Purpose

Prepare and validate the complete game-project release scope: formal content, game-side operations integrations, application icon, localization, crash/error checks, and final builds. External store-console, legal/rating, hosting-deployment, and marketing actions are explicit handoffs rather than silently omitted work.

## Lead

QA Lead

## Supporting Agents

- Technical Artist for application icon variants and import
- UI/UX Developer for localized layout and font coverage
- Unity Architect for logging, exception boundaries, and release build evidence

## Required artifacts

- `production/release/icon-checklist.md`
- `production/localization/localization-report.md`
- `production/qa/crash-check.md`
- `production/release/release-checklist.md`
- `production/release/known-issues.md`
- `production/release/build-report.md`
- `production/scope/release-scope.json`
- `production/release/operations-readiness.md`

## Flow

1. Verify the project is at Beta or later through the unified gate evaluator. Read `targetVersion` from the release-scope manifest; `0.x` remains prototype/pre-release and `1.0.0+` cannot be claimed until the final Release gate passes.
2. Icon:
   - track the icon in `asset-manifest.json` as `kind: app-icon` and `requiredFor: release-candidate`;
   - preserve a master source and generate platform sizes without stretching;
   - verify alpha, safe area, readability, Player Settings assignment, and build output.
3. Localization:
   - verify every release locale has the same keys;
   - detect empty, fallback, debug, and source-language leftovers;
   - verify plural/format placeholders, font glyph coverage, text expansion, truncation, and representative screenshots;
   - record source and locale counts in the localization report.
4. Crash/error check:
   - compile a non-development release candidate;
   - capture Unity Console/build logs and exercise startup, new game, save/load, scene changes, pause/resume, and shutdown;
   - fail on unhandled exceptions, assertion errors, missing references, repeated error logs, or corrupted-save loops;
   - record reproduction and accepted known issues. External crash SaaS integration is out of scope.
5. Validate operations readiness: required game-side monetization, analytics/consent, remote config/LiveOps, backend failure behavior, and save compatibility are verified; external store/legal/deployment handoffs have named owners, inputs, and blocker status.
6. Validate that every release-scope item is `verified`, all planned/implemented/verified counts match, all evidence paths exist, and no placeholders remain.
7. Complete the Release Candidate structured quality report, with evidence for the version contract, full release scope, operations handoff, icon, localization, crash/error checks, build, and known issues.
8. Run `tools/test-quality-gate.ps1 -Stage release-candidate`; it validates the report, art, and release scope together. Fix failures before locking the candidate.
9. After final smoke, complete and validate the `release` quality report. Only then may the build be labeled `1.0.0` or release-ready.
10. Record output path, evidence, risks, and trace.

## Completion

The icon, localization, crash/error checks, and final build evidence pass, or the release remains blocked with exact failures.
