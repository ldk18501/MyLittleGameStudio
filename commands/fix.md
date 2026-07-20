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

1. Bind the requested or nearest project with `tools/new-project-context.ps1`, then capture symptom, expected behavior, and available evidence.
2. Reproduce or inspect the narrowest relevant evidence.
3. Identify the smallest responsible area.
4. For production code, create or refresh the task context and change plan. A focused fix may stay lightweight, but an existing-project fix must still identify the owning module, failure path, affected callers, and the style exemplars required by its selected intensity.
4. Use `mlgs-unity-mechanics` for gameplay feel, timing, feedback, pooling, or performance bugs.
5. Acquire a lease for the approved fix paths and run `tools/preflight-task.ps1 -Command fix -TaskId <id> -ContextPath <context-path>`; only use `-AcceptRisk` after explicit owner acceptance. Risk acceptance never waives missing code context.
6. Make a focused fix inside approved paths.
7. Run code conformance against the actual changed paths, including post-impact review for deep projects, then run the most relevant verification and `tools/validate-changes.ps1 -ContextPath <context-path>` while the same lease is active.
8. Record fix, evidence, remaining risk, and next action.
9. Record trace with the bound context and invocation ID, then release the lease.

## Ask Before

- changing intended design behavior
- touching packages, project settings, broad scene/prefab structure, or architecture
- choosing among fixes with noticeably different product feel
- editing outside approved paths

## Completion

The issue is fixed and verified, or blocked with a precise reason.
