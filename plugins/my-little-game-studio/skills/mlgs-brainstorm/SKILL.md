---
name: mlgs-brainstorm
description: "MLGS 直接指令：头脑风暴 Unity 游戏概念、参考、pitch、核心幻想、支柱、MVP 范围和概念包。用于用户输入 /mlgs-brainstorm、头脑风暴、想点子、生成概念、整理参考，或给出游戏主题/玩法种子希望 MLGS 继续发展。"
---

# MLGS Brainstorm

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/brainstorm.md`。优先响应 `/mlgs-brainstorm [idea]`，同时兼容 `/mlgs brainstorm`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/brainstorm.md`、`agents/creative-director.md`、`agents/producer.md`、`agents/game-designer.md`，按需读取 Technical Artist 或 Unity Architect。
3. 解析用户提供的主题、参考、类型、目标平台或情绪关键词。
4. 如果没有 active project：
   - 用户给出任何想法种子时，优先创建或建议一个内部项目工作区并直接起草概念，不要只把用户打回 `/mlgs-start`。
   - 用户完全没有上下文时，给出一个低摩擦 A/B/C/D 创意入口问题。
5. 按 owner participation 执行：`low` 直接起草并标记待确认；`medium` 起草后请批准/修改；`high` 才在重大创意分叉前给 2-4 个选项。
6. 下一步推荐优先写 `/mlgs-plan`。
7. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


