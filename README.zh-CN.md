# MyLittleGameStudio 中文说明

MyLittleGameStudio 是一套轻量化的 AI 游戏工作室工作流，主要面向 Unity 独立游戏开发。

它不是 Unity 游戏项目本体，而是一套给 AI 使用的工作流大脑：帮助 AI 识别当前阶段、选择合适角色、路由命令、实现功能、修 bug、做 review、跑测试和构建版本。

## 核心特点

- 8 个角色，不模拟大公司。
- 12 个命令，不搞复杂菜单。
- 默认主动推进，少问废话。
- 高风险操作才询问你。
- `studio/state.yaml` 是唯一状态源。
- 自带 Codex 插件源，可以用 `mlgs` 作为短入口。
- 不假设用户有任何特定 Unity 项目或框架目录。

## 目录结构

```text
MyLittleGameStudio/
  AGENTS.md
  README.md
  README.zh-CN.md
  studio/
    state.yaml
    config.md
  workflow/
    command-router.md
    phases.yaml
  agents/
  commands/
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
mlgs status
mlgs start
mlgs implement 下一个 Unity 任务
mlgs fix 这个编译错误
mlgs build APK
```

### 安装步骤

在终端中进入 MyLittleGameStudio 根目录：

```powershell
cd <你的路径>\MyLittleGameStudio
```

然后执行：

```powershell
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

注意：这里传的是 `MyLittleGameStudio` 根目录。不要传 `.\.agents\plugins`，也不要传 `marketplace.json` 文件。

原因是 Codex 期待的 marketplace root 需要同时包含 `.agents/plugins/marketplace.json` 和 `plugins/<plugin-name>/`。

安装后请新开一个 Codex thread，让插件和 skill 刷新。

## 是否需要把 Unity 项目放进 MyLittleGameStudio？

不需要。

推荐方式是：

```text
SomeFolder/
  MyLittleGameStudio/       # 工作流仓库
  YourUnityGame/            # 你的 Unity 项目
```

你也可以把 Unity 项目放在完全不同的位置。初始化时执行：

```text
mlgs start
```

然后告诉它你的 Unity 项目路径即可。

## 三种项目管理方式

### 方式 A：外部 Unity 项目

推荐给大多数用户。

MyLittleGameStudio 保持独立，Unity 项目放在别处。`studio/state.yaml` 记录 Unity 项目路径。

### 方式 B：内部 managed project

适合你想让 MyLittleGameStudio 管理多个小项目：

```text
MyLittleGameStudio/
  projects/
    game-a/
    game-b/
```

### 方式 C：嵌入到 Unity 项目

也可以把 MyLittleGameStudio 放进 Unity 项目，但不推荐默认这样做，因为会混合工作流文件和 Unity 工程文件。

## 切换到 Claude Code

Claude Code 可以先直接读取这套文件：

```text
请读取 MyLittleGameStudio/AGENTS.md，并按 workflow/command-router.md 路由我的请求。
```

如果以后要转换成 Claude Code 原生 agents 和 skills，可以映射：

```text
agents/*.md   -> .claude/agents/*.md
commands/*.md -> .claude/skills/[command]/SKILL.md
```

详见：

```text
adapters/claude-code.md
```

## 最小使用姿势

安装插件后：

```text
mlgs start
```

告诉它你的 Unity 项目路径。

之后：

```text
mlgs status
mlgs implement 下一个任务
mlgs fix 这个问题
mlgs test
mlgs build APK
```

一句话：MyLittleGameStudio 是一个可独立发布的 Unity AI 工作流仓库，别人 clone 下来后，可以直接从这个目录安装 `mlgs` 插件入口。
