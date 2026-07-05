---
name: mlgs-plan
description: "MLGS 直接指令：把游戏概念拆成 Unity 系统设计、技术方案、任务计划、原型策略和验收标准。用于用户输入 /mlgs-plan、设计方案、技术方案、拆系统、任务计划，或希望 MLGS 从概念进入可执行开发计划。"
---

# MLGS Plan

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/plan.md`。优先响应 `/mlgs-plan`，同时兼容 `/mlgs plan`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/plan.md`、`agents/game-designer.md`、`agents/unity-architect.md`、`agents/producer.md`，按需读取 Gameplay Developer、UI/UX Developer、Technical Artist、QA Lead。
3. 如果缺概念但用户已给出足够方向，先写最小可用假设再规划；只有完全没有方向时才路由 `/mlgs-brainstorm`。
4. `low` participation 下直接生成系统/技术/任务草案，只在阶段批准、核心架构、依赖、范围大变动时询问。
5. 用 `mlgs-unity-mechanics` 处理玩法手感、调参、对象池、性能或 QA 验收。
6. 下一步推荐优先写 `/mlgs-prototype` 或 `/mlgs-implement`。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


