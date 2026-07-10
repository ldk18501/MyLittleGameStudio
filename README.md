# MyLittleGameStudio

MyLittleGameStudio is a Codex-first AI game studio workflow for Unity + C# indie development.

It is inspired by Claude Code Game Studios, but intentionally simplified:

- Codex plugin entry instead of Claude Code hooks/settings.
- Unity + C# only.
- A compact specialist staff instead of dozens of agents.
- A single `/mlgs` entry; describe the work in natural language and the studio routes it to start, brainstorm, plan, implement, fix, test, build, or review.
- Owner participation levels so the studio can be either autonomous or collaborative.
- A dashboard that shows staff activity and project state.

## Quick Start

Install the local Codex plugin from this repository root:

```powershell
codex plugin marketplace add .
```

Then install **my-little-game-studio** from the Codex app plugin page. CLI builds that expose `codex plugin add` may instead run `codex plugin add my-little-game-studio@my-little-game-studio-local`; check `codex plugin --help` first because current desktop builds do not all expose the same subcommands.

Open a new Codex thread and run:

```text
/mlgs I want to start a new Unity game with low participation
```

MLGS will ask whether you want to:

- A) start a new game
- B) adopt an existing Unity project
- C) continue the current project
- D) repair or switch project

It will also ask your owner participation level:

- A) Low: hands-off owner, MLGS acts autonomously and asks only at major gates
- B) Medium: balanced collaboration, the default
- C) High: hands-on owner, more options and draft review

## Common Phrases

You only need to memorize one entry:

```text
/mlgs your request
```

Examples:

| Phrase | Purpose |
|---|---|
| `/mlgs start a new Unity game with low participation` | Guided start, participation, or pointer recovery |
| `/mlgs adopt D:\path\to\YourUnityGame` | Inspect and attach an existing Unity project |
| `/mlgs show current status and next step` | Project state, staff activity, risks, next options |
| `/mlgs brainstorm a cozy roguelite farming game` | Explore ideas, references, pitch, pillars, concept package |
| `/mlgs turn the current concept into a plan` | Systems, Unity tech plan, tasks, prototype policy |
| `/mlgs build a small prototype for the core feel` | Build/evaluate a focused prototype or skip with risk |
| `/mlgs implement the next task` | Implement an approved Unity/C# task |
| `/mlgs generate and integrate the next final art assets` | Generate, process, slice/import, reference, and approve art in Unity |
| `/mlgs move the game to Vertical Slice` | Enforce final-look, integration, architecture, performance, and art-pipeline evidence |
| `/mlgs review Content Complete readiness` | Reject placeholders, unwired features, missing references, and production-code blockers |
| `/mlgs prepare icon localization and crash checks` | Validate the MLGS-owned game-content release subset |
| `/mlgs fix this compile error` | Diagnose and fix a bug, compile issue, or QA failure |
| `/mlgs review whether this task is ready` | Review code, design, task, phase, build, or workflow |
| `/mlgs run verification` | Run or define verification |
| `/mlgs do a build preflight` | Unity build or build preflight |
| `/mlgs open dashboard` | Refresh dashboard data |
| `/mlgs help` | Compact menu |

See `workflow/command-index.md` for the grouped intent index.

## Studio Staff

- Producer: routing, scope, state, task assignment
- Creative Director: fantasy, pitch, pillars, references
- Game Designer: systems, rules, tuning, acceptance criteria
- Unity Architect: Unity architecture, packages, scenes, build risk
- Gameplay Developer: C# gameplay implementation
- UI/UX Developer: HUD, runtime UI, input ergonomics
- Technical Artist: shaders, VFX, formal generated-art lifecycle, Unity import/slicing/references
- QA Lead: verification, smoke checks, build readiness

## Project State

The root `studio/state.json` is only a validated template.

Live project state belongs in:

```text
<UnityProject>/.mlgs/state.json
```

The local pointer is:

```text
$CODEX_HOME/mlgs/current-project.json
```

Legacy `.mlgs/state.yaml` and `studio/current-project.local.yaml` remain readable until explicitly migrated.

It is ignored by git.

## Dashboard

MLGS records routed work in:

```text
$CODEX_HOME/mlgs/logs/activity.jsonl
$CODEX_HOME/mlgs/runtime.json
$CODEX_HOME/mlgs/dashboard/studio-data.js
```

Open:

```text
dashboard/index.html
```

The dashboard shows staff status, recent events, active project, phase, owner participation, and next command.

## Tools

```powershell
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project -Apply
powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/init-project-state.ps1 -ProjectRoot E:/path/to/project -Name "My Game"
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -Clear
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
powershell -ExecutionPolicy Bypass -File tools/run-smoke-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/preflight-task.ps1 -Command implement
powershell -ExecutionPolicy Bypass -File tools/validate-changes.ps1
powershell -ExecutionPolicy Bypass -File tools/migrate-state.ps1 -ProjectRoot E:/path/to/project
```

## Design Position

MLGS keeps the useful studio structure from larger agent templates, but avoids their heavy process:

- no Claude Code compatibility layer
- no Claude hooks
- no approval before every file write
- no multi-engine abstraction
- no long mandatory document chain

The default goal is simple: let Codex behave like a small Unity studio that can ask good questions when needed, then get real work done.

