---
name: mlgs-dashboard
description: "MLGS 直接指令：刷新或打开 MyLittleGameStudio dashboard，查看员工活动、项目状态和下一步。用于用户输入 /mlgs-dashboard、看板、打开看板、刷新看板。"
---

# MLGS Dashboard

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/dashboard.md`。优先响应 `/mlgs-dashboard`，同时兼容 `/mlgs dashboard`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/dashboard.md`、`agents/producer.md`。
3. 运行可用的 dashboard 导出脚本，例如 `tools/export-dashboard.ps1` 或通过 `tools/trace.ps1` 刷新 runtime。
4. 返回 `dashboard/index.html` 的本地路径和当前摘要。
5. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


