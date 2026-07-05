---
name: mlgs-help
description: "MLGS 直接指令：显示短命令菜单并根据当前项目状态推荐一个下一步。用于用户输入 /mlgs-help、帮助、命令菜单、不知道输什么，或询问 MLGS 支持哪些命令。"
---

# MLGS Help

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/help.md`。优先响应 `/mlgs-help`，同时兼容 `/mlgs help`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/help.md`、`workflow/command-index.md`、`agents/producer.md`。
3. 运行 `tools/get-project-status.ps1 -AllowTemplate` 获取当前推荐。
4. 菜单按启动入口、创意与计划、开发循环、审查与可视化分组展示。
5. 明确标出启动入口：`/mlgs-start`、`/mlgs-adopt <path>`、`/mlgs-status`、`/mlgs-help`。
6. 只给一个主推荐，避免把帮助页变成流程说明书。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


