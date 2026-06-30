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
2. Use `mlgs-unity-mechanics` to derive normal, edge, failure, feedback, and performance checks for gameplay systems.
3. For mass objects/DOD/instancing, include scale target, CPU/GPU frame time, GC Alloc, draw calls/batches, culling, collision, and fallback checks.
4. Run available checks when environment supports them.
5. If checks cannot run, write a manual verification plan and explain the limit.
6. Record result, evidence path, issues found, and next command.
7. Record trace.

## Completion

There is verification evidence or a clear manual test plan.
