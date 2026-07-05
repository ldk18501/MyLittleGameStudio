---
name: mlgs
description: "MyLittleGameStudio 单入口智能路由。用于用户输入 /mlgs 后用自然语言描述 Unity/C# 游戏开发需求，例如开始新项目、接管项目、头脑风暴、规划、实现、修 bug、测试、构建、看状态或打开 dashboard。"
---

# MLGS 单入口

这是 MyLittleGameStudio 唯一暴露给用户的 Codex skill。不要把内部工作流包装成多个 slash 指令；Codex 插件的斜杠菜单只负责选择 `/mlgs`，后面的内容由自然语言路由器判断。

推荐用户这样说：

```text
/mlgs 我想开始一个新的 Unity 游戏，低参与度
/mlgs 接管 E:\Projects\MyUnityGame
/mlgs 帮我头脑风暴一个休闲割草游戏
/mlgs 看看现在项目状态，告诉我下一步
/mlgs 继续实现下一个任务
/mlgs 修一下这个编译错误
```

兼容旧写法，例如 `/mlgs start`、`/mlgs plan`、`/mlgs implement`，但不要主动推荐 `/mlgs-start` 这类子指令。

## 范围

- Codex only。
- Unity + C# only。
- 用户是 studio owner，Codex 默认扮演 Producer。
- 不保留 Claude Code hooks、`.claude` settings 或 Claude 专属 slash 行为。
- 不让用户管理内部流程；先理解意图，再选择内部 command。

## 找到 MLGS 根目录

路由前先找到 MyLittleGameStudio checkout root：

1. 优先使用包含当前 plugin source 的仓库。
2. 否则查找最近的可访问目录，要求包含：
   - `AGENTS.md`
   - `studio/state.yaml`
   - `workflow/command-router.md`
3. 如果找不到，只问一次 MyLittleGameStudio 目录路径。

不要使用其他机器上的绝对路径。

## 必读文件

每次路由前读取：

1. `<MyLittleGameStudio>/AGENTS.md`
2. `<MyLittleGameStudio>/studio/config.md`
3. `<MyLittleGameStudio>/rules/state.md`
4. `<MyLittleGameStudio>/workflow/command-router.md`
5. `<MyLittleGameStudio>/workflow/onboarding.yaml`
6. `<MyLittleGameStudio>/workflow/phases.yaml`

然后只读取选中的 command 文件、相关 agent 文件和必要 reference。

## 路由内核

先运行或等价执行：

```powershell
tools/resolve-state.ps1 -AllowTemplate
```

路由规则：

- 指针损坏：进入 `status` 或 `start` 的恢复流程。
- 只有模板状态：如果用户没有给想法或路径，路由到 `start`；如果给了想法，路由到 `brainstorm`；如果给了项目路径，路由到 `adopt`。
- 用户给出路径：运行 `tools/detect-project-stage.ps1 -ProjectRoot <path>`，再按结果路由。
- 未解锁生产但用户要开发：路由到 `status`、`plan` 或 `prototype`；只有用户明确接受风险才进入 `implement`。
- 低参与度：合理推断并继续，记录 assumptions；只在重大创意、依赖、架构、破坏性或阶段门决策时询问。

## 自然语言到内部 command

| 用户意图 | 内部 command 文件 |
|---|---|
| 开始、新游戏、空项目、设置参与度、修复指针、继续当前项目 | `commands/start.md` |
| 头脑风暴、想点子、玩法主题、参考、pitch、核心幻想、概念包 | `commands/brainstorm.md` |
| 接管项目、已有 Unity 项目、已有资料目录、项目路径 | `commands/adopt.md` |
| 状态、下一步、卡住了、现在该做什么、员工动态 | `commands/status.md` |
| 规划、设计方案、技术方案、拆系统、任务计划、原型策略 | `commands/plan.md` |
| 原型、验证玩法、验证风险、跳过原型 | `commands/prototype.md` |
| 实现、继续开发、下一个任务、写代码、做功能 | `commands/implement.md` |
| 修 bug、修复、编译错误、测试失败、回归 | `commands/fix.md` |
| 审查、review、代码审查、设计评审、阶段评审、工作流评审 | `commands/review.md` |
| 测试、验证、smoke、QA、验收 | `commands/test.md` |
| 打包、构建、构建预检、APK、发布检查 | `commands/build.md` |
| dashboard、看板、刷新看板、员工状态页面 | `commands/dashboard.md` |
| 帮助、菜单、不知道怎么说、支持什么 | `commands/help.md` |
| 生成美术、概念图、占位图、素材提示词 | `commands/generate-art.md` |

如果意图仍然模糊，只问一个短问题。

## 内部资料

`plugins/my-little-game-studio/internal/skills/` 保存旧的拆分 skill 文档和 `mlgs-unity-mechanics` 机制资料。它们是内部参考，不是用户入口。

玩法手感、调参、对象池、DOD、instancing、弹幕、大量对象、输入反馈、性能预算或 QA 验收相关任务，应读取：

```text
plugins/my-little-game-studio/internal/skills/mlgs-unity-mechanics/SKILL.md
```

并在 trace 的 `skillsUsed` 中记录 `mlgs-unity-mechanics`。

## 常用工具

- 状态：`tools/get-project-status.ps1 -AllowTemplate`
- 接管分析：`tools/adopt-project.ps1 -ProjectRoot <path>`
- 接管应用：`tools/adopt-project.ps1 -ProjectRoot <path> -Apply`
- 状态解析：`tools/resolve-state.ps1 -AllowTemplate`
- 烟测：`tools/run-smoke-tests.ps1`

## Owner Participation

读取项目状态里的 `owner_participation.level`：

- `low`：像可信员工一样工作。日常细节自行决定，写草稿、执行、检查、记录 assumptions。
- `medium`：默认平衡模式。常规工作直接做，重大方向、架构、依赖、范围或阶段变化前询问。
- `high`：owner 深度参与。更常给 A/B/C/D 选项，并在重要编辑前给简短方案。

未设置时按 `medium`。

## Trace

每个 MLGS 路由任务结束前尽量记录 trace：

```powershell
powershell -ExecutionPolicy Bypass -File tools/trace.ps1
```

记录 command、title、status、lead agent、agents used、skills used、files read/written、assumptions、decisions、verification。

Trace 会更新：

- `studio/logs/activity.jsonl`
- `studio/runtime.json`
- `dashboard/studio-data.js`

## 行为原则

- Producer 默认协调。
- Specialist agents 是当前 Codex 线程内的角色，除非 owner 明确要求创建多个线程。
- 回答时推荐下一步用自然语言，例如“继续让我实现下一个任务”，不要把用户导向一堆子 slash 指令。
- 低/中参与度下不要为例行写文档、聚焦代码编辑、trace、dashboard、状态检查反复询问。
- 破坏性操作、依赖/包、Unity 项目设置、大范围 scene/prefab、build settings、核心架构变化必须先问。
