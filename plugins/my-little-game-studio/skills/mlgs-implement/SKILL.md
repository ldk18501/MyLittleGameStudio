---
name: mlgs-implement
description: "MLGS 直接指令：实现已批准或可推断的 Unity/C# 游戏开发任务。用于用户输入 /mlgs-implement、实现、继续开发、做下一个任务、开发功能，或希望 MLGS 根据任务计划直接写代码并验证。"
---

# MLGS Implement

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/implement.md`。优先响应 `/mlgs-implement [task]`，同时兼容 `/mlgs implement [task]`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/implement.md`、`agents/gameplay-developer.md`、`agents/unity-architect.md`、`agents/producer.md`，按任务读取 UI/UX Developer、Technical Artist、QA Lead。
3. 从用户请求、`production/task-plan.md`、状态推荐或现有任务文件中选择最小可执行任务。
4. production 未解锁时，只有用户明确接受风险才继续；但可以先做安全的分析、任务拆解或验证准备。
5. `low/medium` participation 下直接实现常规任务；`high` 或高风险改动先给简短计划。
6. 运行可用的编译、smoke、Unity Test Runner 或手动 QA 证据记录。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


