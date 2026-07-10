# Command: build

## Purpose

Prepare or produce a Unity build. Build success is evidence for a quality gate, not proof that the game is finished.

## Lead

Unity Architect

## Supporting Agents

- QA Lead
- Gameplay Developer
- Technical Artist when assets/rendering affect build readiness

## Flow

1. Resolve target platform.
2. Check Unity version, scenes, packages, build settings, Addressables, player settings, and known issues when possible.
3. Run preflight:
   - compile errors
   - required scenes
   - target platform
   - Addressables content
   - product name/version
   - development build flag
   - signing/keystore notes for Android
   - application icon assignment for Beta or later
   - localization tables/font coverage for Beta or later
   - non-development crash/error smoke for Release Candidate
4. Check the current productization gate. Report missing content/art/quality evidence separately from technical build blockers.
5. Ask before modifying project settings, packages, build settings, or signing configuration.
6. Build if environment and approval allow.
7. Record output path, size, warnings, blockers, development/release flags, and next test action in `production/release/build-report.md` when applicable.
8. Record trace.

## Completion

Build succeeds, or blockers and exact fixes are listed.
