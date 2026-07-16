# MyLittleGameStudio

MyLittleGameStudio (MLGS) is a Codex-first AI game studio workflow for building production-oriented Unity + C# games.

It keeps the useful idea of a specialist game studio, but replaces heavyweight agent choreography with one `/mlgs` entry, a compact Unity-focused staff, machine-readable production contracts, and evidence-driven quality gates.

MLGS is designed to prevent three common failure modes:

- a polished concept image turning into placeholder panels and flat-color UGUI;
- a prototype being renamed `1.0` without the content, onboarding, configuration, art, audio, QA, and release evidence needed to ship;
- new Unity code ignoring the existing framework—or being forced to copy legacy patterns that are wrong for the new work.

## Current Scope

- Codex only; no Claude Code compatibility layer, hooks, or settings.
- Unity + C# only, using Unity 2022 LTS or Unity 6 conventions.
- One public command: `/mlgs`, followed by a natural-language request.
- New projects, existing-project adoption, planning, prototyping, formal art, implementation, testing, productization, builds, and release preparation.
- Configurable owner participation: low, medium, or high.
- A dashboard and trace log for project state and specialist activity.

## Quick Start

From this repository root, register the local marketplace:

```powershell
codex plugin marketplace add .
```

Install **my-little-game-studio** from the Codex app plugin page, open a new Codex task, and enter:

```text
/mlgs I want to start a new Unity game with low participation
```

If the marketplace was already registered and the source was updated, remove and re-add it, then open a new task so Codex loads the new plugin version:

```powershell
codex plugin marketplace remove my-little-game-studio-local
codex plugin marketplace add .
```

Some CLI builds expose additional plugin commands. Check `codex plugin --help` instead of assuming those commands are available.

## One Entry, Natural-Language Routing

You only need to remember:

```text
/mlgs your request
```

| Example | Internal intent |
|---|---|
| `/mlgs start a new Unity game with low participation` | Guided start and participation setup |
| `/mlgs adopt D:\path\to\YourUnityGame` | Inspect and attach an existing project |
| `/mlgs show current status and next step` | State, risks, staff activity, and next action |
| `/mlgs brainstorm a cozy roguelite farming game` | References, pitch, pillars, and concept package |
| `/mlgs turn the current concept into a production plan` | Systems, technical plan, scope, tasks, and prototype policy |
| `/mlgs build a focused prototype for the core feel` | HTML interaction prototype or Unity greybox |
| `/mlgs implement the next approved task` | Context-aware Unity/C# implementation |
| `/mlgs generate and integrate the next formal art assets` | Generate, process, import, reference, and review art in Unity |
| `/mlgs move the game to Vertical Slice` | Prove one representative final-quality journey |
| `/mlgs review Content Complete readiness` | Find placeholders, missing content, unwired flows, and code blockers |
| `/mlgs prepare icon localization and crash checks` | Release preparation owned by the game project |
| `/mlgs fix this compile error` | Diagnose and fix a scoped issue |
| `/mlgs run verification` | Compile, tests, smoke checks, or QA evidence |
| `/mlgs do a build preflight` | Unity build readiness |
| `/mlgs open dashboard` | Refresh/open project activity data |

The generated grouped menu lives in `workflow/command-index.md`.

## Production Lifecycle

```text
concept -> plan -> prototype -> vertical slice -> production
        -> content complete -> alpha -> beta -> release candidate -> release
```

Version numbers do not advance this lifecycle. `0.1.x` is prototype/pre-release. A game may be called `1.0.0` or release-ready only after the final Release gate passes.

Before production, MLGS requires an explicit release scope covering applicable:

- features and content quantities;
- player journey, onboarding, and tutorial beats;
- UI screens and states;
- configuration/data sources;
- formal art, animation, VFX, and audio;
- localization and target-platform behavior;
- performance, error handling, operations readiness, and builds.

“Complete” means every required item in that approved scope is verified—not merely that the current implementation has no open TODO list.

## Adaptive Unity Code Strategy

MLGS scales code analysis and architecture discipline to the project instead of applying one rigid rule everywhere.

| Project kind | Intensity | Default behavior |
|---|---|---|
| New project | `lightweight` | Establish the smallest useful foundation; no fake requirement to imitate nonexistent legacy code |
| Small existing project | `standard` | Read the target module plus at least two sibling/style examples; prefer local consistency while allowing a better isolated design |
| Large framework project | `deep` | Read at least three exemplars and five context files; require dependency/impact evidence before and after implementation |

Classification is automatic and may be overridden by the owner or Unity Architect with a recorded reason. CodeGraph is optional: deep projects require structural evidence, but that evidence may come from CodeGraph, Roslyn, or a documented manual analysis.

Existing code is evidence, not a prison. A reviewed change plan may choose to:

- extend an existing integration point;
- adapt a framework convention;
- replace a harmful legacy implementation;
- create a minimal new foundation;
- introduce an isolated new module.

Production code tasks follow this chain:

```text
work package -> codebase profile/module map -> task context
             -> change plan -> preflight -> implementation
             -> conformance/impact checks -> objective evidence
```

This prevents design-document-only implementation, undeclared managers/services, unplanned file changes, and demo-only components from being accepted as production work.

## Visual Fidelity and Formal Art

HTML prototypes are interaction evidence only. Their placeholder panels, colors, buttons, and layout are never the production visual specification.

Formal art is governed by:

- an approved visual target and style bible;
- a screen-level visual scene contract;
- a fixed Unity scene, camera, resolution, and capture setup;
- composition anchors, depth layers, renderer ownership, lighting/material language, and detail-density targets;
- an asset manifest and import recipes;
- real Unity references and in-game screenshots;
- fail-closed Art Director and QA comparison reviews.

The lifecycle is:

```text
planned -> prompt-ready -> generated -> selected -> processed
        -> imported -> referenced -> approved in game
```

A good isolated image is not an approved game asset. The representative Unity scene must match the approved whole-screen target closely enough to pass its contract.

For 2D games, core gameplay defaults to `SpriteRenderer`/`TilemapRenderer` scene content. UGUI or UI Toolkit is for HUD, menus, overlays, dialogs, inventories, and approved exceptions. UI views never own authoritative gameplay rules unless the owner explicitly approves a pure-UI game.

## Evidence-Driven Gates

MLGS uses machine-readable artifacts instead of optimistic completion statements:

- work packages separate declared completion from objective verdicts and cap rework attempts;
- game profiles define the minimum scope for the selected game type;
- frozen design hashes invalidate affected work when source decisions change;
- every production UI screen has a state, asset, implementation, and evidence contract;
- capability manifests fail closed when required image, sprite, mesh, animation, audio, video, Unity import, or visual-comparison capability is unavailable;
- Vertical Slice through Release gates require structured reports with resolvable project evidence;
- isolated Demo/Test scenes are not production integration evidence.

## Studio Staff

- **Producer** — routing, scope, state, work packages, and phase gates
- **Creative Director** — fantasy, pitch, pillars, and reference interpretation
- **Art Director** — visual targets, composition fidelity, style consistency, and final in-game approval
- **Game Designer** — systems, rules, tuning, onboarding, and acceptance criteria
- **Unity Architect** — codebase profile, module boundaries, packages, scenes, data, and build risk
- **Gameplay Developer** — modular C# gameplay implementation
- **UI/UX Developer** — HUD, menus, runtime UI, input ergonomics, and screen contracts
- **Technical Artist** — shaders, VFX, asset processing/import, renderer integration, and visual performance
- **QA Lead** — objective checks, smoke tests, regression, and release evidence

These are logical specialist passes inside the current Codex task unless the owner explicitly requests separate tasks.

## Project State and Runtime Data

The repository file `studio/state.json` is a validated template. Each game has one canonical state file:

```text
<UnityProject>/.mlgs/state.json
```

User-specific runtime data defaults to:

```text
$CODEX_HOME/mlgs/current-project.json
$CODEX_HOME/mlgs/runtime.json
$CODEX_HOME/mlgs/logs/activity.jsonl
$CODEX_HOME/mlgs/dashboard/studio-data.js
```

When `CODEX_HOME` is unset, MLGS uses `~/.codex/mlgs/`. Legacy `.mlgs/state.yaml` and `studio/current-project.local.yaml` remain readable until explicitly migrated.

Open `dashboard/index.html` to view the active project, observed phase, participation level, recent work, specialist status, risks, and recommended next command.

## Useful Repository Tools

```powershell
# State and adoption
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate

# Initialize production contracts and classify code intensity
powershell -ExecutionPolicy Bypass -File tools/init-production-pipeline.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/inspect-codebase.ps1 -ProjectRoot E:/path/to/project -Apply

# Prepare and validate one production code task
powershell -ExecutionPolicy Bypass -File tools/new-code-task.ps1 -ProjectRoot E:/path/to/project -TaskId feature-id
powershell -ExecutionPolicy Bypass -File tools/test-code-task.ps1 -ProjectRoot E:/path/to/project -TaskId feature-id
powershell -ExecutionPolicy Bypass -File tools/preflight-task.ps1 -Command implement -TaskId feature-id

# Project and package verification
powershell -ExecutionPolicy Bypass -File tools/test-production-code.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/validate-changes.ps1
powershell -ExecutionPolicy Bypass -File tools/run-smoke-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/generate-workflow.ps1 -Check
powershell -ExecutionPolicy Bypass -File tools/build-plugin-package.ps1 -Check
```

`tools/new-code-task.ps1` expects a matching production work package to exist first. The command route normally creates and coordinates these artifacts for the owner.

## Repository Structure

- `commands/` — internal natural-language routes
- `agents/` — specialist role contracts
- `rules/` — state, production-code, and workflow rules
- `studio/` — schemas, config, and state template
- `templates/` — project artifact templates
- `profiles/unity/` — minimum production profiles for Unity game types
- `tools/` — state, planning, art, code, gate, build, trace, and packaging helpers
- `plugins/my-little-game-studio/` — generated self-contained plugin package
- `dashboard/` — local activity viewer

The repository root is canonical. Do not hand-edit generated mirrored workflow files in `plugins/my-little-game-studio/`; update the root sources and rebuild the package.
