# Command: fix

## Purpose

Diagnose and fix a bug, playtest issue, build failure, UI problem, compile error, or QA failure.

## Lead

Gameplay Developer or UI/UX Developer depending on issue.

## Supporting Agents

- Unity Architect for architecture/build/package issues
- QA Lead for repro and verification
- Technical Artist for visual/VFX issues

## Procedure

1. Capture the symptom and expected behavior.
2. Reproduce or inspect the relevant evidence.
3. Identify the smallest responsible area.
4. Fix narrowly.
5. Run the most relevant verification.
6. Record the fix and evidence in the task or QA note.
7. Record a trace event with the symptom, agent handoff, files read/written, decision, and verification result.

## Ask Only When

- The fix requires changing design behavior.
- The fix touches broad architecture, packages, scenes, prefabs, or project settings.
- There are multiple valid fixes with different product feel.

## Completion

- Bug is fixed and verified, or blocked with a concrete missing input.
