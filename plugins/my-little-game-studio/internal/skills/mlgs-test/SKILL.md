---
name: mlgs-test
description: "MLGS 直接指令：运行或定义 Unity/C# 验证、编译检查、smoke test、QA 计划或手动验收证据。用于用户输入 /mlgs-test、测试、验证、跑检查、QA、smoke。"
---

# MLGS Test

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/test.md`。优先响应 `/mlgs-test`，同时兼容 `/mlgs test`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/test.md`、`agents/qa-lead.md`、`agents/gameplay-developer.md`、`agents/unity-architect.md`、`agents/producer.md`。
3. 优先运行已有自动化：编译、Unity Test Runner、smoke 脚本或项目提供的检查命令。
4. 没有可运行自动化时，写清楚手动 QA 步骤、预期结果和证据缺口。
5. 验证输出要能支撑下一步 `/mlgs-implement`、`/mlgs-fix`、`/mlgs-build` 或阶段推进。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


