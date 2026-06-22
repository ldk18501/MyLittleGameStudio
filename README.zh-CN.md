# MyLittleGameStudio 中文说明

MyLittleGameStudio 是一套轻量化的 AI 游戏工作室工作流，主要面向 Unity 独立游戏开发。

它不是 Unity 游戏项目本体，而是一套给 AI 使用的工作流大脑：帮助 AI 识别当前阶段、选择合适角色、路由命令、引导新项目、接管已有项目、实现功能、修 bug、做 review、跑测试和构建版本。

## 核心特点

- 8 个角色，不模拟复杂公司流程。
- 13 个命令，包含 `start`、`adopt`、`status` 三个用户引导入口。
- `start` 会先问你属于 A/B/C/D 哪种起点，而不是要求你懂内部字段。
- `status` 不只报告状态，还会给出下一步要回答的问题。
- `adopt` 用于接管已有 Unity 项目、原型、文档或代码，并盘点缺口。
- 默认主动推进，高风险操作才询问你。
- 具体游戏项目携带自己的 `.mlgs/state.yaml` 状态信息。
- 自带 Codex 插件源，可以用 `mlgs` 作为短入口。
- 不假设用户有任何特定 Unity 项目或框架目录。
- 自带活动追踪和办公室看板，能看到哪些 agent 和 skill 参与了工作。

## 目录结构

```text
MyLittleGameStudio/
  AGENTS.md
  README.md
  README.zh-CN.md
  studio/
    state.yaml
    config.md
    runtime.json
    trace.schema.json
    logs/
      activity.jsonl
  workflow/
    command-router.md
    onboarding.yaml
    phases.yaml
  agents/
  commands/
  dashboard/
  templates/
  adapters/
  rules/
  tools/
  plugins/
    my-little-game-studio/
  .agents/
    plugins/
      marketplace.json
```

## 角色

| 角色 | 用途 |
|---|---|
| Producer | 默认协调者，负责状态、下一步、任务拆解 |
| Creative Director | 创意方向、核心幻想、玩法支柱 |
| Game Designer | 系统设计、规则、数值、验收标准 |
| Unity Architect | Unity 架构、项目设置、构建、技术风险 |
| Gameplay Developer | 玩法代码实现 |
| UI/UX Developer | UI、交互、可读性、移动端操作体验 |
| Technical Artist | Shader、VFX、生成美术、视觉性能 |
| QA Lead | 测试、验收、风险、构建前检查 |

## Commands 是什么？

`commands/` 里的文件不是终端命令，而是 AI 工作流说明书。

例如你说：

```text
mlgs status
```

AI 会读取 `workflow/command-router.md`，然后路由到：

```text
commands/status.md
```

再按这个 command 的流程执行。

## 常用命令

| 你说 | 路由到 |
|---|---|
| `mlgs start` / 开始 / 初始化项目 | `start` |
| `mlgs adopt` / 接管项目 / 已有项目 | `adopt` |
| `mlgs status` / 看状态 / 下一步 | `status` |
| `mlgs references` / 整理参考 / 分析竞品 | `references` |
| `mlgs concept` / 生成概念包 / 核心玩法 | `concept` |
| `mlgs design-plan` / 设计方案 / 技术方案 | `design-plan` |
| `mlgs prototype` / 做原型 / 验证玩法 | `prototype` |
| `mlgs implement` / 实现 / 继续开发 | `implement` |
| `mlgs fix` / 修复 / 修 bug | `fix` |
| `mlgs review` / 审查 / review | `review` |
| `mlgs test` / 测试 / 验证 | `test` |
| `mlgs build` / 打包 / 构建 APK | `build` |
| `mlgs generate-art` / 生成美术 / 占位图 | `generate-art` |

## 安装 Codex 插件

MyLittleGameStudio 自带一个本地 Codex 插件源：

```text
MyLittleGameStudio/plugins/my-little-game-studio/
```

它提供一个快捷 skill：

```text
mlgs
```

安装后，你不用每次说“请使用 MyLittleGameStudio/AGENTS.md 作为工作流入口”，直接输入：

```text
mlgs start
mlgs adopt E:\path\to\UnityProject
mlgs status
mlgs implement 下一个 Unity 任务
mlgs fix 这个编译错误
mlgs build APK
```

### 安装步骤

在终端进入 MyLittleGameStudio 根目录：

```powershell
cd <你的路径>\MyLittleGameStudio
```

然后执行：

```powershell
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

注意：这里传的是 `MyLittleGameStudio` 根目录。不要传 `.\.agents\plugins`，也不要传 `marketplace.json` 文件。

安装后建议新开一个 Codex thread，让插件和 skill 刷新。

## 新项目如何开始？

安装插件后：

```text
mlgs start
```

MLGS 会先问你属于哪种起点：

```text
A) No idea yet
B) Vague idea
C) Clear concept
D) Existing work
```

然后它只问一个下一步问题，例如“一句话 pitch 是什么？”或“项目路径在哪里？”。

## 如何接管已有 Unity 项目？

```text
mlgs adopt E:\path\to\YourUnityGame
```

MLGS 会检查：

- Unity version 和 `Assets/`、`ProjectSettings/`。
- 是否已有 `.mlgs/state.yaml`。
- references、concept、design-plan、prototype、production、tests 是否存在。
- 代码和资源规模。
- 推荐下一步命令。

确认接管后，它只会创建或更新：

```text
<YourUnityGame>/.mlgs/state.yaml
MyLittleGameStudio/studio/current-project.local.yaml
```

它不会复制 Unity 工程，也不会默认修改 Unity 生产文件。

## 状态和恢复工具

```powershell
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -Clear
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
```

如果本地 pointer 指向的项目已移动或删除，`check-state` 会给出可修复警告。此时运行 `mlgs status` 或 `mlgs start`，MLGS 会问你要修复到哪个路径，还是清除当前 pointer 重新开始。

## 如何知道 agent 和 skill 是否真的被用到了？

MLGS 每次执行命令时都应该写入一条活动记录：

```text
studio/logs/activity.jsonl
```

并刷新当前运行状态：

```text
studio/runtime.json
```

记录内容包括：

- 使用了哪个 command。
- 谁是 lead agent。
- 哪些 supporting agents 参与。
- 使用了哪些外部 skills。
- 读取了哪些文件。
- 写入了哪些文件。
- 做了哪些假设和决策。
- 进行了哪些验证。

## 办公室看板

打开这个文件即可查看可视化办公室：

```text
dashboard/index.html
```

如果你手动改了日志，或者想刷新看板数据，可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/export-dashboard.ps1
```

正常情况下，`tools/trace.ps1` 写入活动记录后会自动刷新看板数据。

这些运行时文件会被 `.gitignore` 忽略：

```text
studio/current-project.local.yaml
studio/runtime.json
studio/logs/activity.jsonl
dashboard/studio-data.js
```

所以别人 clone 你的仓库时，会看到一个干净的 dashboard，而不是你的本地测试记录。

## 是否需要把 Unity 项目放进 MyLittleGameStudio？

不需要。

推荐方式是：

```text
SomeFolder/
  MyLittleGameStudio/       # 工作流仓库
  YourUnityGame/            # 你的 Unity 项目
```

你也可以把 Unity 项目放在完全不同的位置。接管时执行：

```text
mlgs adopt E:\path\to\YourUnityGame
```

一句话：MyLittleGameStudio 是一个可独立发布的 Unity AI 工作流仓库。现在它不仅能执行命令，也能在开局、接管和状态恢复时一步步带用户走。
