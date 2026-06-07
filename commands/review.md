# Command: review

## Purpose

Review design, code, task readiness, phase readiness, or build readiness.

## Lead

QA Lead for readiness, Unity Architect for code/architecture, Creative Director for concept/design direction.

## Review Modes

- `code`: bugs, architecture, Unity best practices, test gaps.
- `design`: pillars, player experience, system clarity, scope.
- `task`: readiness, acceptance criteria, dependencies.
- `phase`: missing artifacts, approval state, risks.
- `build`: platform settings, package state, known issues.

## Procedure

1. Determine review mode from user request.
2. Read only relevant files.
3. Lead with findings ordered by severity.
4. Include file references when reviewing code or artifacts.
5. Recommend concrete next action.
6. Record a trace event with review mode, agents used, files read, findings summary, and verification limits.

## Completion

- Findings are clear.
- Next step is actionable.
