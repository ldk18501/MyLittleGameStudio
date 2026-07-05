---
name: mlgs-status
description: "MLGS 直接指令：查看当前项目状态、阶段、参与度、员工活动、缺口、风险和下一步建议。用于用户输入 /mlgs-status、看状态、下一步、现在该做什么、我卡住了，或希望 MLGS 自动推荐下一步。"
---

# MLGS Status

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/status.md`。优先响应 `/mlgs-status`，同时兼容 `/mlgs status`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/status.md`、`agents/producer.md`。
3. 运行 `tools/get-project-status.ps1 -AllowTemplate`。
4. 如果只有模板状态，给出一个清晰下一步：`/mlgs-start`、`/mlgs-adopt <path>` 或 `/mlgs-help`。
5. 如果已有项目，优先用结构化状态对象输出：项目、阶段、参与度、最近活动、已完成/缺失产物、风险、推荐指令。
6. under `low` participation 时可以主动选择最可能下一步并说明将如何推进；`medium/high` 给 A/B/C/D 选项。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


