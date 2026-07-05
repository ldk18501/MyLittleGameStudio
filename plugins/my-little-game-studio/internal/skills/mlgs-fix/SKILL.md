---
name: mlgs-fix
description: "MLGS 直接指令：诊断并修复 Unity/C# bug、编译错误、QA 失败、玩法回归或构建问题。用于用户输入 /mlgs-fix、修复、修 bug、编译报错、测试失败，或贴出错误日志希望 MLGS 查根因并改代码。"
---

# MLGS Fix

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/fix.md`。优先响应 `/mlgs-fix [issue]`，同时兼容 `/mlgs fix [issue]`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/fix.md`、`agents/qa-lead.md`、`agents/gameplay-developer.md`、`agents/unity-architect.md`、`agents/producer.md`。
3. 优先收集错误日志、复现步骤、最近改动和相关测试；不要停在泛泛猜测。
4. 在 approved write paths 内做聚焦修复；依赖、项目设置、广泛场景/prefab 或核心架构改动需确认。
5. 修复后运行最相关验证，记录残余风险和下一步。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


