# MyLittleGameStudio

MyLittleGameStudio is a lightweight AI game studio workflow for Unity indie game development.

It keeps the useful structure from larger multi-agent game studio templates, but now preserves the part that matters most for first-time use: guided onboarding. The default behavior is:

- Guide first when the user is starting, returning, or adopting existing work.
- Act proactively once the project context is clear.
- Record assumptions.
- Ask only when the decision is high-risk, ambiguous, destructive, changes the game direction, or chooses a project entry path.
- Keep project state in one source of truth.

## Design Goals

This version is written around six practical goals:

1. **Guided onboarding**: `start`, `status`, and `adopt` produce one clear next question or one clear next command.
2. **Readable text**: all source files are UTF-8 and Chinese trigger phrases are written plainly.
3. **Project-scoped state**: live game state follows the active game project.
4. **Installable shortcut**: the bundled Codex plugin provides the `mlgs` entry point.
5. **Production-ready commands**: implementation, fix, review, test, and build workflows are included.
6. **Flexible prototype policy**: prototypes are recommended by default, but can be skipped with a recorded risk.
7. **Auditable activity**: routed work records agents, skills, files, decisions, and verification.

## Structure

```text
MyLittleGameStudio/
  AGENTS.md              # main instruction entry
  studio/                # state template, local pointer, runtime trace
  workflow/              # phases, command routing, onboarding state machine
  agents/                # small studio role definitions
  commands/              # executable workflow commands
  dashboard/             # static office-style activity dashboard
  plugins/               # Codex plugin source
  .agents/plugins/       # local Codex marketplace entry
  templates/             # project artifact templates
  adapters/              # Codex / Claude Code usage notes
  rules/                 # lightweight project rules
  tools/                 # state, adoption, trace, and dashboard helpers
```

## Default Role Roster

- Producer
- Creative Director
- Game Designer
- Unity Architect
- Gameplay Developer
- UI/UX Developer
- Technical Artist
- QA Lead

## Core Commands

- `start`: guided onboarding, initialization, or pointer recovery.
- `adopt`: inspect and adopt an existing Unity project, prototype, docs, or codebase.
- `status`: show current state, missing artifacts, risks, and the next question.
- `references`: collect reference games, images, and avoidances.
- `concept`: produce the concept package.
- `design-plan`: create system design, technical plan, and tasks.
- `prototype`: build or skip an HTML/Unity playable prototype.
- `implement`: implement a production task.
- `fix`: diagnose and fix a bug or quality issue.
- `review`: review code, design, or production readiness.
- `test`: run or define verification.
- `build`: prepare or produce a Unity build.

## Recommended Use

Use MyLittleGameStudio as a workflow layer beside or inside your Unity project.

Recommended for most users:

- Clone this repository anywhere convenient.
- Install the bundled Codex plugin from this repository.
- Run `mlgs start`.
- Pick the starting point that fits you:
  - `A) No idea yet`
  - `B) Vague idea`
  - `C) Clear concept`
  - `D) Existing work`
- Answer the one next question MLGS asks.

If you already have a Unity project or design/code folder, run `mlgs adopt` or say “接管项目”. MLGS will inspect the project, report gaps, and ask whether to initialize or repair its `.mlgs/state.yaml` pointer.

The workflow does not assume any specific Unity project name or local framework directory.

## State And Recovery Tools

```powershell
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -Clear
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
```

`check-state` returns a warning, not a hard failure, when the local pointer is stale but the root template is intact. In that case, run `mlgs status` or `mlgs start` to repair the pointer through the guided flow.

## Activity Trace And Dashboard

Every MLGS command should record an event in:

```text
studio/logs/activity.jsonl
```

The current office state lives in:

```text
studio/runtime.json
```

Open the static dashboard to see which agents and skills participated:

```text
dashboard/index.html
```

If you need to refresh dashboard data manually:

```powershell
powershell -ExecutionPolicy Bypass -File tools/export-dashboard.ps1
```

Generated runtime files are ignored by git:

```text
studio/current-project.local.yaml
studio/runtime.json
studio/logs/activity.jsonl
dashboard/studio-data.js
```

A fresh clone opens with a clean dashboard.
