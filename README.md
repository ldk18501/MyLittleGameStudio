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
codex plugin add my-little-game-studio@my-little-game-studio-local
```

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
- Technical Artist: shaders, VFX, generated art integration
- QA Lead: verification, smoke checks, build readiness

## Project State

The root `studio/state.yaml` is only a template.

Live project state belongs in:

```text
<UnityProject>/.mlgs/state.yaml
```

The local pointer is:

```text
studio/current-project.local.yaml
```

It is ignored by git.

## Dashboard

MLGS records routed work in:

```text
studio/logs/activity.jsonl
studio/runtime.json
dashboard/studio-data.js
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
```

## Design Position

MLGS keeps the useful studio structure from larger agent templates, but avoids their heavy process:

- no Claude Code compatibility layer
- no Claude hooks
- no approval before every file write
- no multi-engine abstraction
- no long mandatory document chain

The default goal is simple: let Codex behave like a small Unity studio that can ask good questions when needed, then get real work done.

