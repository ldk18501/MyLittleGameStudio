---
name: mlgs-review
description: "MLGS 直接指令：审查 Unity/C# 代码、设计、任务就绪度、阶段就绪度、构建准备度或 MLGS 工作流健康度。用于用户输入 /mlgs-review、审查、代码审查、设计评审、阶段评审、workflow review。"
---

# MLGS Review

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/review.md`。优先响应 `/mlgs-review [mode]`，同时兼容 `/mlgs review [mode]`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/review.md` 和对应 agent：代码/架构读 Unity Architect，设计读 Creative Director 或 Game Designer，阶段/构建读 QA Lead，工作流读 Producer。
3. 只读相关文件，先列 findings，按严重度排序并带文件引用。
4. 评审不是泛泛总结；每条问题要说明影响和建议动作。
5. 如果没有发现问题，明确说明剩余验证缺口。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


