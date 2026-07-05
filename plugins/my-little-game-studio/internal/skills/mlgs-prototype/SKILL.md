---
name: mlgs-prototype
description: "MLGS 直接指令：构建或规划最小原型，验证核心循环、输入、相机、UI、物理、渲染或性能风险；也可记录跳过原型的风险。用于用户输入 /mlgs-prototype、做原型、验证核心玩法、跳过原型。"
---

# MLGS Prototype

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/prototype.md`。优先响应 `/mlgs-prototype`，同时兼容 `/mlgs prototype`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/prototype.md`、`agents/gameplay-developer.md`、`agents/game-designer.md`、`agents/unity-architect.md`、`agents/producer.md`，按需读取 QA Lead、Technical Artist、UI/UX Developer。
3. 识别最小风险问题：核心乐趣、输入/相机/UI、Unity 集成、性能或内容产能。
4. 能用 HTML 验证非引擎风险时优先轻量原型；涉及 Unity 行为时用 Unity greybox。
5. `low` participation 下直接定义原型范围并实现/记录，只有跳过风险、依赖、Unity 设置或大范围场景变更需要确认。
6. 记录验证证据或明确 blocker，下一步推荐 `/mlgs-implement`、`/mlgs-plan` 或 `/mlgs-test`。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


