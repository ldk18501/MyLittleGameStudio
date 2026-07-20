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
- HTML 原型只验证交互，不是视觉实现参考。正式美术必须链接 `design/art/visual-target.json` 中已批准的效果图 ID，并在处理、Unity 导入、真实引用、目标图对比和游戏内证据齐全后才能标记 `approved`。
- 生产前必须建立 `production/scope/release-scope.json`，逐项覆盖功能、内容数量、教学、UI、配置表、音频、美术、本地化、operations readiness 和构建；未列入或未验证的项目不能被“全部完成”吞掉。
- Vertical Slice、Content Complete、Alpha、Beta、Release Candidate 和 Release 使用 `tools/test-quality-gate.ps1`；它联合验证质量报告、美术、release scope 和代码审计，证据必须是存在的项目内文件。
- `0.1.x` 只表示原型/预发布。只有最终 Release gate 通过后，游戏才可以标记 `1.0.0` 或 release-ready。
- MLGS 发布范围仅含图标、本地化、崩溃/错误检查和最终构建证据。

## 验证与 Trace

- 状态：`tools/get-project-status.ps1 -AllowTemplate`
- 接管：`tools/adopt-project.ps1 -ProjectRoot <path>`
- 隔离 smoke：`tools/run-smoke-tests.ps1`
- trace：`tools/trace.ps1`

每个 route 记录 command、lead/support agents、skills、读写文件、假设、决策和验证。低/中参与度下直接执行常规工作；依赖、包、Unity 设置、大范围 scene/prefab、build settings 和核心架构变化仍需 owner 确认。
## Production contracts

- Use `tools/new-work-package.ps1`, `run-objective-checks.ps1`, and `test-work-package.ps1` for production tasks. Completion requires both declared and objective verdicts to pass; rework is bounded.
- Formal assets require Art Director and QA pass in `production/assets/reviews/<asset-id>.json`; comparison errors, unavailable automation, low scores, missing evidence, and attempt exhaustion fail closed.
- Formal assets use manifest schema 1.4. Every lifecycle step through the current status must appear in `statusHistory` with project-local evidence; imported assets require a validated import recipe and Unity Importer evidence.
- Run `tools/test-visual-comparison.ps1` for deterministic asset and scene comparison reports. These metrics detect visual drift but never replace Art Director and QA judgment.
- Select a profile from `profiles/unity/`, expand every profile requirement into release scope, validate coverage, enumerate UI screens, and freeze `design/baseline.json` before production.
- A changed frozen design source invalidates its mapped product stages until impact is reviewed and a new baseline version is deliberately frozen.
- Refresh and validate `production/capabilities/capability-manifest.json` before formal production. Required image/Sprite/mesh/animation/audio/video, Unity import/validation, and visual-comparison entries must be ready with evidence.
- Non-direct work uses `tools/new-execution-strategy.ps1`; logical role groups remain in the current thread unless the owner explicitly requests separate threads.
- Whole-screen fidelity is governed by `design/art/visual-scene-contract.json`. Lock composition anchors, depth layers, renderer ownership, Unity scene/camera/resolution, then run `tools/test-visual-scene-contract.ps1`; isolated asset quality cannot approve a mismatched scene.
- Production implementation requires approved `design/framework-adoption.json` and `design/presentation-architecture.json`. Existing Unity framework integration points are adopted before code is written.
- In 2D non-pure-UI games, core gameplay uses SpriteRenderer/TilemapRenderer scene content. UGUI/UI Toolkit is restricted to UI surfaces and owner-approved exceptions; authoritative gameplay rules never live in UI views.
- Code production is adaptively classified as new-project/lightweight, small-existing/standard, or large-framework/deep. The owner or Unity Architect may override classification with a recorded reason; do not impose deep-project ceremony on a new game.
- Run `tools/inspect-codebase.ps1 -Apply` and approve `design/code/codebase-profile.json` plus `design/code/module-map.json`. Deep structural evidence may come from CodeGraph, Roslyn, or documented manual review.
- Every production code work package links `production/context-packs/<task-id>.json`, `production/change-plans/<task-id>.json`, and `production/quality/code-conformance-<task-id>.json`. Preflight requires a fresh task context; completion requires planned-vs-actual conformance.
- Existing code is evidence rather than an absolute constraint. Extend, adapt, replace legacy code, create a minimal foundation, or isolate a new module according to the approved tradeoff and selected intensity.
