# Command: build

## Purpose

Run a non-packaging build preflight or, only when authorized, produce a Unity package build. Build success is evidence for a quality gate, not proof that the game is finished.

## Lead

Unity Architect

## Supporting Agents

- QA Lead
- Gameplay Developer
- Technical Artist when assets/rendering affect build readiness

## Flow

1. Classify the current request before doing any expensive work:
   - `preflight-only`: settings, scenes, packages, Addressables, SDK and signing readiness checks; never produces APK/IPA/EXE/WebGL output.
   - `initial-platform-validation`: one-time validation inside the active new-project `start` flow.
   - `owner-request`: the owner's current message explicitly asks to package, build, install, or test on a device.
   - `release-candidate` or `release`: the formal release flow requires a locked candidate/final build.
   - `routine-development`: any ordinary implementation, fix, art/content/UI change, regression, Vertical Slice, Content Complete, Alpha, or Beta work.
2. Read `.mlgs/build-policy.json`. If an older project has no policy, run `tools/init-build-policy.ps1 -InitialStatus unknown`; do not infer that it needs a new automatic validation. `routine-development` is never authorized to package. A large change, a full regression trigger, a phase gate, changed scene/prefab wiring, or available idle time does not change this.
3. Resolve target platform.
4. Check Unity version, scenes, packages, build settings, Addressables, player settings, and known issues when possible.
5. Run non-packaging preflight:
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
6. Check the current productization gate. Report missing content/art/quality evidence separately from technical build blockers.
7. If only preflight was requested or the reason is `routine-development`, stop after the checks and recommend compile/editor/play-mode verification. Do not invoke Unity batch build, Gradle, Xcode, platform packagers, signing, installation, or device deployment.
8. Before any actual package build, run `tools/preflight-task.ps1 -Command build -View model` with exactly one authorized reason:
   - initial validation: `-BuildReason initial-platform-validation -StartFlowBuild`
   - current owner request: `-BuildReason owner-request -OwnerRequestedBuild`
   - formal flow: `-BuildReason release-candidate` or `-BuildReason release`
9. Ask before modifying project settings, packages, build settings, or signing configuration.
10. Build only when authorization and environment checks pass.
11. Record every attempted package build with `tools/record-build-event.ps1`, including trigger, requester, target, result, and evidence. A successful initial validation changes its policy status to `passed`.
12. Record output path, size, warnings, blockers, development/release flags, and next test action in `production/release/build-report.md` only for actual package builds.
13. Record trace.

## Completion

Preflight completes without packaging, an authorized build succeeds, or blockers and exact fixes are listed. Routine development never ends by silently producing a package.
