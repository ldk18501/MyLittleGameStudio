---
name: mlgs
description: "MyLittleGameStudio 快捷入口。用于用户说 MLGS、MyLittleGameStudio、GameStudio，或请求 start/status/references/concept/design-plan/prototype/implement/fix/review/test/build/generate-art 等 Unity 独立游戏工作流动作；也用于用户不想反复输入 MyLittleGameStudio/AGENTS.md 设置语句时。"
---

# MLGS 快捷入口

本技能是 MyLittleGameStudio 的短入口。

触发后，不要要求用户重复：

```text
Please use MyLittleGameStudio/AGENTS.md as the workflow entry.
```

而是自动加载并遵循该工作流。

## 工作流根目录

路由前先找到 MyLittleGameStudio checkout root：

1. 优先使用包含当前 plugin source 的仓库根目录。
2. 否则查找最近的可访问目录，且该目录同时包含：
   - `AGENTS.md`
   - `studio/state.yaml`
   - `workflow/command-router.md`
3. 如果找不到 checkout root，只问用户一次 `MyLittleGameStudio` 目录路径。

不要使用来自其他用户环境的机器特定路径。

路由任何请求前，读取：

1. `<MyLittleGameStudio>/AGENTS.md`
2. `<MyLittleGameStudio>/studio/config.md`
3. `<MyLittleGameStudio>/rules/state.md`
4. `<MyLittleGameStudio>/workflow/command-router.md`

然后只读取被选中的 command 和相关 agent 文件。

## Unity 项目目标

从项目本地 `.mlgs/state.yaml` 解析目标 Unity 项目。

使用以下顺序：

1. 用户显式提供的 project/state path。
2. `<MyLittleGameStudio>/studio/current-project.local.yaml`。
3. 当前工作目录或最近父目录中的 `.mlgs/state.yaml`。
4. 只作为初始化模板的 `<MyLittleGameStudio>/studio/state.yaml`。

如果还没有项目配置，路由到 `commands/start.md`，或只问一次 Unity 项目路径。不要假设任何机器特定项目名、框架目录或本地路径。

## 命令路由

短请求按以下方式路由：

| 用户说 | 路由到 |
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

如果请求有歧义，只问一个简短澄清问题。

## Trace 记录

每个被路由的 MLGS 任务，在最终回复前都要记录 audit event。

优先使用：

```powershell
powershell -ExecutionPolicy Bypass -File tools/trace.ps1
```

至少记录：

- command name 和简短 task title
- lead agent 和 supporting agents used
- external skills used（如有）
- files read 和 files written
- assumptions 和 decisions
- performed verification，或说明为什么无法验证
- final status：`completed`、`blocked` 或 `partial`

Trace 必须更新：

- `studio/logs/activity.jsonl`
- `studio/runtime.json`
- `dashboard/studio-data.js`

## 行为

- 默认以 Producer 身份协调。
- 除非已解析项目状态另有设置，规划使用 high automation，生产使用 medium automation。
- 只在高风险、破坏性、架构变化、包变化或真正含糊的决策前询问。
- 项目状态保存在已解析的 `.mlgs/state.yaml`；`studio/state.yaml` 只保留为模板。
- 不要重新引入逐文件 “May I write?” 提示。
