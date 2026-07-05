---
name: mlgs-generate-art
description: "MLGS 直接指令：生成或规划 Unity 游戏占位图、概念图、UI/角色/场景提示词和美术接入方案。用于用户输入 /mlgs-generate-art、生成美术、占位图、概念图、素材提示词。"
---

# MLGS Generate Art

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/generate-art.md`。优先响应 `/mlgs-generate-art`，同时兼容 `/mlgs generate-art`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/generate-art.md`、`agents/technical-artist.md`、`agents/creative-director.md`、`agents/producer.md`。
3. 先确认视觉方向、用途、尺寸、输出路径和成本/模型风险。
4. 不要擅自改变已批准的视觉方向；付费或成本不清的生成动作先确认。
5. 输出资产或提示词后记录接入方式、命名和验证。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


