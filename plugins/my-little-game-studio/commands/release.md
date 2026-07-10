# Command: release

## Purpose

Prepare and validate the game-facing release subset owned by MLGS: application icon, localization, and crash/error checks. Store operations, legal, monetization, analytics, deployment, and marketing remain outside this route.

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

## Flow

1. Verify the project is at Beta or later through the unified gate evaluator.
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
5. Complete the Release Candidate structured quality report, with evidence for icon, localization, crash/error checks, build, and known issues.
6. Run `tools/test-quality-gate.ps1 -Stage release-candidate`; fix failures before locking the candidate.
7. After final smoke, complete and validate the `release` quality report.
8. Record output path, evidence, risks, and trace.

## Completion

The icon, localization, crash/error checks, and final build evidence pass, or the release remains blocked with exact failures.
