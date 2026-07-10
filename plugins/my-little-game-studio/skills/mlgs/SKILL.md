---
name: mlgs
description: "MyLittleGameStudio 单入口智能路由。用于 /mlgs 后以自然语言执行 Unity/C# 游戏工作室流程，包括新项目、接管、规划、原型、正式美术生产与 Unity 接入、模块化实现、Vertical Slice、Content Complete、Alpha/Beta、图标、本地化、崩溃检查、构建、状态和 dashboard。"
---

# MLGS

把当前 skill 目录向上两级解析为插件根目录。插件根必须包含 `workflow/catalog.json`、`commands/`、`agents/`、`tools/` 和 `studio/state.json`；这些资源随插件一起发布，不依赖外部 MyLittleGameStudio checkout。

## 路由

1. 读取插件根下的 `studio/config.md`、`rules/state.md` 和 `workflow/catalog.json`。
2. 运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/resolve-state.ps1 -Root <plugin-root> -AllowTemplate
   ```

3. 从 catalog 的 `commands[].intents` 选择一个内部 route。
4. 只读取对应 command 文件、lead agent 和必要 supporting agents。
5. `start`、`adopt`、`status` 才额外读取 `workflow/onboarding.yaml`；阶段评审才读取 catalog 的 phases/gates。
6. 意图仍然模糊时只问一个短问题。

用户只需记住 `/mlgs`；不要推荐隐藏内部 skill 或一组子 slash 命令。

涉及正式美术、切图、导入或引用时路由 `generate-art`；涉及 Vertical Slice、Content Complete、Alpha、Beta 或去 Demo 化时路由 `productize`；涉及图标、本地化、崩溃/错误检查或 Release Candidate 时路由 `release`。

## 状态与兼容

- 新状态：`<UnityProject>/.mlgs/state.json`。
- 旧 `.mlgs/state.yaml` 可读，但状态输出必须提示可运行 `tools/migrate-state.ps1`；不要未经 owner 允许迁移真实项目。
- 用户级当前项目指针和 dashboard runtime 默认写入 `$CODEX_HOME/mlgs/`，未设置 `CODEX_HOME` 时使用 `~/.codex/mlgs/`。
- 插件安装目录视为只读；不要把 pointer、日志或 dashboard 数据写进插件缓存。

## 生产安全

在 `implement` 或 `fix` 写入前运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/preflight-task.ps1 -Root <plugin-root> -Command implement
```

生产未解锁时停止；只有 owner 明确接受风险后才传 `-AcceptRisk`。完成写入后运行 `tools/validate-changes.ps1`，拒绝 approved write paths 之外的 Unity 改动。

## Unity 机制资料

玩法手感、调参、对象池、DOD、instancing、弹幕、大量对象、输入反馈或性能预算任务，读取：

```text
<plugin-root>/internal/skills/mlgs-unity-mechanics/SKILL.md
```

并在 trace 中记录 `mlgs-unity-mechanics`。

## 成品化门禁

- Prototype 之后的生产代码必须读取 `rules/production-code.md`。
- 正式美术使用 `production/assets/asset-manifest.json`，生成预览只有经过处理、Unity 导入、真实引用和游戏内证据后才能标记 `approved`。
- Vertical Slice、Content Complete、Alpha、Beta、Release Candidate 和 Release 使用 `tools/test-quality-gate.ps1`；不得用文件存在代替质量证据。
- MLGS 发布范围仅含图标、本地化、崩溃/错误检查和最终构建证据。

## 验证与 Trace

- 状态：`tools/get-project-status.ps1 -AllowTemplate`
- 接管：`tools/adopt-project.ps1 -ProjectRoot <path>`
- 隔离 smoke：`tools/run-smoke-tests.ps1`
- trace：`tools/trace.ps1`

每个 route 记录 command、lead/support agents、skills、读写文件、假设、决策和验证。低/中参与度下直接执行常规工作；依赖、包、Unity 设置、大范围 scene/prefab、build settings 和核心架构变化仍需 owner 确认。
