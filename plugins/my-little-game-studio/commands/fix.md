# Command: fix

## Purpose

Diagnose and fix a Unity/C# bug, compile error, playtest issue, build problem, UI issue, or QA failure.

## Lead

Gameplay Developer or UI/UX Developer based on issue type.

## Supporting Agents

- Unity Architect for architecture, package, build, or project setting issues
- QA Lead for reproduction and verification
- Technical Artist for visual/VFX issues
- Producer for scope and trace

## Flow

1. Capture symptom, expected behavior, and available evidence.
2. Reproduce or inspect the narrowest relevant evidence.
3. Identify the smallest responsible area.
4. Use `mlgs-unity-mechanics` for gameplay feel, timing, feedback, pooling, or performance bugs.
5. Run `tools/preflight-task.ps1 -Command fix`; only use `-AcceptRisk` after explicit owner acceptance.
6. Make a focused fix inside approved paths.
7. Run the most relevant verification, then `tools/validate-changes.ps1`.
8. Record fix, evidence, remaining risk, and next action.
9. Record trace.

## Ask Before

- changing intended design behavior
- touching packages, project settings, broad scene/prefab structure, or architecture
- choosing among fixes with noticeably different product feel
- editing outside approved paths

## Completion

The issue is fixed and verified, or blocked with a precise reason.
