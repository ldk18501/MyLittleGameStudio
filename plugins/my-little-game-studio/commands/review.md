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
- `product`: Vertical Slice, Content Complete, Alpha, Beta, or Release Candidate evidence
- `art`: style consistency, manifest lifecycle, import, slicing, atlas, references, placeholders, and in-game approval
- `production-code`: module boundaries, dependency direction, lifecycle, test seams, error handling, temporary/demo shortcuts
- `workflow`: MLGS project structure, commands, agents, dashboard

## Flow

1. Determine review mode from the request.
2. Read only relevant files.
3. Use `mlgs-unity-mechanics` for gameplay mechanisms, feel, balance, feedback, or performance risks.
4. For a stage review, run the structured quality gate and refuse approval when required checks lack evidence, blockers remain, or owner approval is absent.
5. For art, run the manifest validator at the stage scope; generated or imported files without real references and in-game evidence are incomplete.
6. For production code, apply `rules/production-code.md` and run the audit tool. Distinguish blocking shortcuts from acceptable project-scale tradeoffs.
7. Put findings first, ordered by severity.
8. Include file references for reviewed artifacts.
9. Recommend one concrete next command or fix.
10. Record trace with verification limits.

## Completion

Findings are clear, prioritized, and actionable.
