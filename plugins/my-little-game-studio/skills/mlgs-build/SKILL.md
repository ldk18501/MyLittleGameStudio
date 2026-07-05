---
name: mlgs-build
description: "MLGS 直接指令：执行 Unity 构建预检、构建准备、平台风险检查或实际构建。用于用户输入 /mlgs-build、打包、构建 APK、构建预检、发布检查。"
---

# MLGS Build

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/build.md`。优先响应 `/mlgs-build`，同时兼容 `/mlgs build`。

## 执行

1. 找到 MyLittleGameStudio 根目录，并读取 `AGENTS.md` 与 MLGS 必读文件。
2. 读取 `commands/build.md`、`agents/qa-lead.md`、`agents/unity-architect.md`、`agents/producer.md`。
3. 先做构建预检：Unity 版本、平台、包、签名、场景、Addressables、测试/QA 证据。
4. 修改项目设置、包、签名或构建配置前必须确认。
5. 构建后记录产物路径、失败日志或剩余 blocker。
6. 用 `tools/trace.ps1` 记录路由、文件、假设、决策和验证。


