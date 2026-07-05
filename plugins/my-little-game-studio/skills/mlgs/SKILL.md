---
name: mlgs
description: "MyLittleGameStudio Codex 总入口和兼容路由。用于用户输入 /mlgs、MLGS、MyLittleGameStudio，或需要把 Unity/C# 游戏开发请求路由到 /mlgs-start、/mlgs-brainstorm、/mlgs-adopt、/mlgs-status、/mlgs-plan、/mlgs-prototype、/mlgs-implement、/mlgs-fix、/mlgs-review、/mlgs-test、/mlgs-build、/mlgs-dashboard、/mlgs-generate-art 等短指令。"
---

# MLGS Codex Entry

This skill is the compatibility router for MyLittleGameStudio.

Prefer direct commands for normal use because Codex can autocomplete them:

```text
/mlgs-brainstorm [idea]
/mlgs-plan
/mlgs-implement next task
```

The compatibility syntax remains:

```text
/mlgs <command> [details]
```

Also accept `mlgs <command>` and natural-language Chinese/English aliases.

## Scope

- Codex only.
- Unity + C# only.
- Do not load or preserve Claude Code hooks, `.claude` settings, or Claude-specific slash skill behavior.
- Do not ask the owner to repeat "use AGENTS.md"; load the workflow automatically.

## Find The MLGS Root

Before routing, find the MyLittleGameStudio checkout root:

1. Prefer the repository that contains this plugin source.
2. Otherwise find the nearest accessible directory containing:
   - `AGENTS.md`
   - `studio/state.yaml`
   - `workflow/command-router.md`
3. If unavailable, ask once for the MyLittleGameStudio directory path.

Do not use machine-specific paths from another user's environment.

## Required Reads

Before routing any command, read:

1. `<MyLittleGameStudio>/AGENTS.md`
2. `<MyLittleGameStudio>/studio/config.md`
3. `<MyLittleGameStudio>/rules/state.md`
4. `<MyLittleGameStudio>/workflow/command-router.md`
5. `<MyLittleGameStudio>/workflow/onboarding.yaml`

Then read only the selected command and relevant agent files.

## Guide Kernel

`/mlgs-start`, `/mlgs-status`, and `/mlgs-adopt` are guide entries:

1. Resolve project state with `tools/resolve-state.ps1 -AllowTemplate`.
2. If pointer is stale, enter recovery.
3. If only template state exists, route to `/mlgs-start`.
4. If the owner provides a project path, inspect it with `tools/detect-project-stage.ps1`.
5. Each guide response gives one next question or one next command.

Do not ask for internal fields first. Ask the owner's situation and participation preference, then map to state fields.

## Command Routing

| Owner Says | Route |
|---|---|
| `/mlgs-start`, `/mlgs start`, `开始` | `commands/start.md` |
| `/mlgs-brainstorm`, `/mlgs brainstorm`, `头脑风暴`, `想点子`, `生成概念` | `commands/brainstorm.md` |
| `/mlgs-adopt`, `/mlgs adopt`, `接管项目`, `已有项目` | `commands/adopt.md` |
| `/mlgs-status`, `/mlgs status`, `看状态`, `下一步` | `commands/status.md` |
| `/mlgs-plan`, `/mlgs plan`, `设计方案`, `技术方案`, `拆系统`, `design-plan` | `commands/plan.md` |
| `/mlgs-prototype`, `/mlgs prototype`, `做原型` | `commands/prototype.md` |
| `/mlgs-implement`, `/mlgs implement`, `实现`, `继续开发` | `commands/implement.md` |
| `/mlgs-fix`, `/mlgs fix`, `修复`, `修 bug` | `commands/fix.md` |
| `/mlgs-review`, `/mlgs review`, `审查`, `review` | `commands/review.md` |
| `/mlgs-test`, `/mlgs test`, `测试`, `验证` | `commands/test.md` |
| `/mlgs-build`, `/mlgs build`, `打包`, `构建 APK` | `commands/build.md` |
| `/mlgs-dashboard`, `/mlgs dashboard`, `看板` | `commands/dashboard.md` |
| `/mlgs-help`, `/mlgs help`, `帮助` | `commands/help.md` |
| `/mlgs-generate-art`, `/mlgs generate-art`, `生成美术` | `commands/generate-art.md` |

If ambiguous, ask one short clarification question.

## Preferred Tools

- Status: `tools/get-project-status.ps1 -AllowTemplate`
- Adoption report: `tools/adopt-project.ps1 -ProjectRoot <path>`
- Adoption apply after owner confirmation: `tools/adopt-project.ps1 -ProjectRoot <path> -Apply`
- State resolve: `tools/resolve-state.ps1 -AllowTemplate`
- Smoke test: `tools/run-smoke-tests.ps1`

## Owner Participation

Use `owner_participation.level` from project state:

- `low`: act like a trusted staff. Decide routine details, write drafts, run checks, record assumptions.
- `medium`: balanced default. Ask before major creative, architecture, dependency, scope, or phase changes.
- `high`: hands-on owner. Offer A/B/C/D options and concise plans more often.

If unset, assume `medium`.

## Trace

Every routed MLGS task must record trace before the final reply when possible:

```powershell
powershell -ExecutionPolicy Bypass -File tools/trace.ps1
```

Record command, title, status, lead agent, agents used, skills used, files read/written, assumptions, decisions, and verification.

Trace updates:

- `studio/logs/activity.jsonl`
- `studio/runtime.json`
- `dashboard/studio-data.js`

## Behavior

- Producer coordinates by default.
- Specialist agents are roles inside the current Codex thread unless the owner explicitly asks to create separate threads.
- Use `mlgs-unity-mechanics` for gameplay systems, tuning, input feel, performance-sensitive Unity runtime work, object pools, DOD, instancing, QA acceptance, and smoke checks.
- Prefer direct next-step suggestions like `/mlgs-plan`, not `/mlgs plan`.
- Do not ask for routine writes under low or medium participation.
- Always ask before destructive operations, dependencies/packages, Unity settings, broad scene/prefab changes, or core architecture changes.


