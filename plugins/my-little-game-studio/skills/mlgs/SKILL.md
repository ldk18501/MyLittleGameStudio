---
name: mlgs
description: "MyLittleGameStudio shortcut. Use when the user says MLGS, MyLittleGameStudio, GameStudio, start/status/references/concept/design-plan/prototype/implement/fix/review/test/build/generate-art for a Unity indie game workflow, or asks to avoid repeating the MyLittleGameStudio AGENTS.md setup phrase."
---

# MLGS Shortcut

This skill is the short entry point for MyLittleGameStudio.

When triggered, do not ask the user to repeat:

```text
Please use MyLittleGameStudio/AGENTS.md as the workflow entry.
```

Instead, load and follow the workflow automatically.

## Workflow Root

Find the MyLittleGameStudio checkout root before routing:

1. Prefer the repository root that contains this plugin source.
2. Otherwise find the nearest accessible directory containing all of:
   - `AGENTS.md`
   - `studio/state.yaml`
   - `workflow/command-router.md`
3. If the checkout root cannot be discovered, ask the user once for the path to their `MyLittleGameStudio` directory.

Do not use machine-specific paths from another user's environment.

Before routing any request, read:

1. `<MyLittleGameStudio>/AGENTS.md`
2. `<MyLittleGameStudio>/studio/config.md`
3. `<MyLittleGameStudio>/rules/state.md`
4. `<MyLittleGameStudio>/workflow/command-router.md`

Then read only the selected command and relevant agent files.

## Unity Project Target

Resolve the target Unity project from the project-local `.mlgs/state.yaml`.

Use this order:

1. Explicit project/state path from the user.
2. `<MyLittleGameStudio>/studio/current-project.local.yaml`.
3. `.mlgs/state.yaml` in the current working directory or nearest parent.
4. `<MyLittleGameStudio>/studio/state.yaml` as an initialization template only.

If no project is configured yet, route to `commands/start.md` or ask for the Unity project path once. Do not assume any machine-specific project name, framework directory, or local path.

## Command Routing

Route short user requests as follows:

| User Says | Route To |
|---|---|
| `mlgs start`, `GameStudio start`, `开始` | `commands/start.md` |
| `mlgs status`, `看状态`, `下一步` | `commands/status.md` |
| `mlgs references`, `整理参考`, `分析竞品` | `commands/references.md` |
| `mlgs concept`, `生成概念包`, `核心玩法` | `commands/concept.md` |
| `mlgs design-plan`, `设计方案`, `技术方案`, `拆系统` | `commands/design-plan.md` |
| `mlgs prototype`, `做原型`, `验证玩法` | `commands/prototype.md` |
| `mlgs implement`, `实现`, `继续开发` | `commands/implement.md` |
| `mlgs fix`, `修复`, `修 bug` | `commands/fix.md` |
| `mlgs review`, `审查`, `review` | `commands/review.md` |
| `mlgs test`, `测试`, `验证` | `commands/test.md` |
| `mlgs build`, `打包`, `构建 APK` | `commands/build.md` |
| `mlgs generate-art`, `生成美术`, `占位图` | `commands/generate-art.md` |

If the request is ambiguous, ask one concise clarification question.

## Trace Recording

For every routed MLGS task, record an audit event before finalizing the answer.

Prefer:

```powershell
powershell -ExecutionPolicy Bypass -File tools/trace.ps1
```

Record at least:

- command name and short task title
- lead agent and supporting agents used
- external skills used, if any
- files read and files written
- assumptions and decisions
- verification performed or why verification could not run
- final status: `completed`, `blocked`, or `partial`

The trace must update:

- `studio/logs/activity.jsonl`
- `studio/runtime.json`
- `dashboard/studio-data.js`

## Behavior

- Act as the Producer by default.
- Use high automation for planning and medium automation for production unless the resolved project state says otherwise.
- Ask only for high-risk, destructive, architecture-changing, package-changing, or genuinely ambiguous decisions.
- Keep project state in the resolved `.mlgs/state.yaml`; keep `studio/state.yaml` as a template only.
- Never reintroduce per-file "May I write?" prompts.
