---
name: mlgs-adopt
description: "MLGS 直接指令：分析并接管已有 Unity 项目、文档项目、原型或代码目录。用于用户输入 /mlgs-adopt <path>、接管项目、已有项目、导入项目，或提供项目路径希望 MLGS 判断阶段和下一步。"
---

# MLGS Adopt

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/adopt.md`。优先响应 `/mlgs-adopt <path>`，同时兼容 `/mlgs adopt <path>`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/adopt.md`、`agents/producer.md`、`agents/unity-architect.md`、`agents/game-designer.md`。
3. 如果用户给出路径，运行 `tools/detect-project-stage.ps1 -ProjectRoot <path>`；需要应用接管且用户已确认时运行 `tools/adopt-project.ps1 -ProjectRoot <path> -Apply`。
4. 只在缺少路径、写入范围或接管确认时提问。分析报告先给结论，再给一个推荐动作。
5. 后续推荐优先使用 `/mlgs-status`、`/mlgs-brainstorm`、`/mlgs-plan`、`/mlgs-prototype`。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


