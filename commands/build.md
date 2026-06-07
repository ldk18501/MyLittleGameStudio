# Command: build

## Purpose

Prepare or produce a Unity build, especially APK builds for Android.

## Lead

Unity Architect

## Supporting Agents

- QA Lead
- Gameplay Developer

## Procedure

1. Resolve target platform.
2. Inspect Unity version, build settings, scenes, packages, Addressables, and player settings where possible.
3. Run preflight:
   - compile errors
   - required scenes
   - target platform
   - Addressables content
   - development build flag
   - product name/version
4. Ask before changing project settings or package/build configuration.
5. Build when environment and permissions allow.
6. Record build path, size, warnings, and next test action.

## Completion

- Build succeeds, or blockers are listed with precise fixes.

