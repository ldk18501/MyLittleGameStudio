# Command: build

## Purpose

Prepare or produce a Unity build, especially Android APK or desktop smoke builds.

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
4. Ask before modifying project settings, packages, build settings, or signing configuration.
5. Build if environment and approval allow.
6. Record output path, size, warnings, blockers, and next test action.
7. Record trace.

## Completion

Build succeeds, or blockers and exact fixes are listed.
