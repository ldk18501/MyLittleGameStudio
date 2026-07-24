# Command: test

## Purpose

Run, define, or summarize verification for the current Unity task or project phase.

## Lead

QA Lead

## Supporting Agents

- Gameplay Developer
- Unity Architect
- UI/UX Developer

## Flow

1. Determine target:
   - Unity compile
   - smoke test
   - current task acceptance
   - UI walkthrough
   - balance simulation
   - performance check
   - build preflight
   - art manifest/import/reference validation
   - visual-target linkage and in-game comparison
   - release-scope counts, onboarding/tutorial coverage, and configuration/data-source validation
   - productization quality gate
   - production-code audit
   - localization integrity
   - crash/error smoke
2. Use `mlgs-unity-mechanics` to derive normal, edge, failure, feedback, and performance checks for gameplay systems.
3. For mass objects/DOD/instancing, include scale target, CPU/GPU frame time, GC Alloc, draw calls/batches, culling, collision, and fallback checks.
4. Read the current work package `verificationPolicy`. For ordinary implementation, batch small changes and run the routine compile/acceptance/integration suite once at the task boundary. Run focused checks inside the task only for acceptance-critical or risk-triggered changes. Reuse passing evidence until a relevant input changes; full regression is reserved for declared triggers, build/phase gates, a previous failure, or an explicit owner request.
5. For productization stages, run `tools/test-quality-gate.ps1`; it validates the stage report together with configured art, scope, and code-audit gates. Use the focused art/scope validators while fixing individual failures.
6. For production code, run `tools/test-production-code.ps1` and attach `production/quality/code-audit.json` by Content Complete.
7. At Alpha and later, include a full flow, missing-reference, localization integrity, and crash/error smoke pass. A clean compile alone is insufficient.
8. Run available checks when environment supports them. Repository smoke tests must use an isolated runtime root and must not mutate the live project pointer, trace, or dashboard.
9. If checks cannot run, write a manual verification plan and explain the limit. Manual plans do not satisfy a gate until evidence is recorded.
10. Record result, evidence path, issues found, and next command.
11. Record trace.

## Completion

There is verification evidence or a clear manual test plan.
