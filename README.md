# MyLittleGameStudio

MyLittleGameStudio is a Codex-first AI game studio workflow for Unity + C# indie development.

It is inspired by Claude Code Game Studios, but intentionally simplified:

- Codex plugin entry instead of Claude Code hooks/settings.
- Unity + C# only.
- A compact specialist staff instead of dozens of agents.
- Autocompletable MLGS-prefixed commands such as `/mlgs-brainstorm`, `/mlgs-plan`, and `/mlgs-implement`; `/mlgs ...` remains as a compatibility router. Codex skill names use hyphen-case, so MLGS uses `/mlgs-start` rather than `/mlgs_start`.
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
/mlgs-start
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

## Core Commands

You only need to memorize four entry commands first:

- `/mlgs-start`: first run, empty project, new project, pointer recovery.
- `/mlgs-adopt <path>`: existing Unity project or existing materials.
- `/mlgs-status`: when you do not know what to do next.
- `/mlgs-help`: command menu.

| Command | Purpose |
|---|---|
| `/mlgs-start` | Guided start, adoption, participation, or pointer recovery |
| `/mlgs-brainstorm` | Explore ideas, references, pitch, pillars, concept package |
| `/mlgs-adopt <path>` | Inspect and attach an existing Unity project |
| `/mlgs-status` | Project state, staff activity, risks, next options |
| `/mlgs-plan` | Systems, Unity tech plan, tasks, prototype policy |
| `/mlgs-prototype` | Build/evaluate a focused prototype or skip with risk |
| `/mlgs-implement` | Implement an approved Unity/C# task |
| `/mlgs-fix` | Diagnose and fix a bug, compile issue, or QA failure |
| `/mlgs-review` | Review code, design, task, phase, build, or workflow |
| `/mlgs-test` | Run or define verification |
| `/mlgs-build` | Unity build or build preflight |
| `/mlgs-dashboard` | Refresh dashboard data |
| `/mlgs-help` | Compact command menu |

See `workflow/command-index.md` for the grouped command index.

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

