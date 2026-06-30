# Command: review

## Purpose

Review code, design, task readiness, phase readiness, build readiness, or studio workflow health.

## Lead

- QA Lead for readiness reviews
- Unity Architect for code/architecture reviews
- Creative Director for concept/design direction reviews
- Producer for workflow reviews

## Modes

- `code`: bugs, Unity best practices, architecture, tests
- `design`: pillars, player experience, rules, scope
- `task`: readiness, acceptance criteria, dependencies
- `phase`: missing artifacts, approvals, risks
- `build`: platform settings, package/build blockers
- `workflow`: MLGS project structure, commands, agents, dashboard

## Flow

1. Determine review mode from the request.
2. Read only relevant files.
3. Use `mlgs-unity-mechanics` for gameplay mechanisms, feel, balance, feedback, or performance risks.
4. Put findings first, ordered by severity.
5. Include file references for reviewed artifacts.
6. Recommend one concrete next command or fix.
7. Record trace with verification limits.

## Completion

Findings are clear, prioritized, and actionable.
