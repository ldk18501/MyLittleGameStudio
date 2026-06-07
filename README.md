# MyLittleGameStudio

MyLittleGameStudio is a lightweight AI game studio workflow for Unity indie game development.

It keeps the useful structure from larger multi-agent game studio templates, but removes the heavy meeting-style flow. The default behavior is:

- Act proactively.
- Record assumptions.
- Ask only when the decision is high-risk, ambiguous, destructive, or changes the game direction.
- Keep project state in one source of truth.

## Design Goals

This version is written around five practical goals:

1. **Readable text**: all source files are UTF-8 and Chinese trigger phrases are written plainly.
2. **Single state source**: the canonical state is `studio/state.yaml`.
3. **Installable shortcut**: the bundled Codex plugin provides the `mlgs` entry point.
4. **Production-ready commands**: implementation, fix, review, test, and build workflows are included.
5. **Flexible prototype policy**: prototypes are recommended by default, but can be skipped with a recorded risk.

## Structure

```text
MyLittleGameStudio/
  AGENTS.md              # main instruction entry
  studio/                # single-source studio state and config
  workflow/              # phases and command routing
  agents/                # small studio role definitions
  commands/              # executable workflow commands
  plugins/               # Codex plugin source
  .agents/plugins/       # local Codex marketplace entry
  templates/             # project artifact templates
  adapters/              # Codex / Claude Code usage notes
  rules/                 # lightweight project rules
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

- `start`: initialize or adopt a project.
- `status`: show current state and next action.
- `references`: collect reference games, images, and avoidances.
- `concept`: produce the concept package.
- `design-plan`: create system design, technical plan, and tasks.
- `prototype`: build or skip an HTML playable prototype.
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
- Run `mlgs start` and point it at your Unity project.
- Run `mlgs status` to see the next recommended action.

The workflow does not assume any specific Unity project name or local framework directory.
