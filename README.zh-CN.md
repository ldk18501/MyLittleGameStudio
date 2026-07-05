# MyLittleGameStudio 中文说明

MyLittleGameStudio，简称 MLGS，是一个面向 Codex 的 Unity + C# 独立游戏 AI 工作室。

它参考过 Claude Code Game Studios 的“多角色游戏工作室”思路，但现在已经明确收敛为：

- 只支持 Codex，不再考虑 Claude Code 兼容。
- 只面向 Unity + C#。
- 保留少量专职 agent，而不是几十个角色。
- 使用可补全的 MLGS 前缀指令，例如 `/mlgs-brainstorm`、`/mlgs-plan`、`/mlgs-implement`；`/mlgs ...` 保留为兼容入口。Codex skill 名称使用 hyphen-case，所以这里用 `/mlgs-start`，不用 `/mlgs_start`。
- 支持老板参与度：你可以当甩手掌柜，也可以当爱管细节的制作人。
- 保留 Dashboard，看员工们的实时工作状态。

## 快速开始

在 MyLittleGameStudio 仓库根目录安装本地 Codex 插件：

```powershell
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

新开一个 Codex thread，然后输入：

```text
/mlgs-start
```

MLGS 会先判断项目状态，然后让你选择：

- A) 新游戏
- B) 接管已有 Unity 项目
- C) 继续当前项目
- D) 修复或切换项目指针

它还会让你选择参与度：

- A) 低参与度：你当甩手掌柜，MLGS 自主推进，只在重大关口问你
- B) 中参与度：默认模式，日常自动做，方向和架构大事先问
- C) 高参与度：你深度参与，MLGS 更常给 A/B/C/D 选项和草案

## 常用指令

只需要先记 4 个启动/找路入口：

- `/mlgs-start`：第一次使用、空项目、新项目、修复指针。
- `/mlgs-adopt <path>`：已有 Unity 项目或已有资料目录。
- `/mlgs-status`：不知道下一步做什么。
- `/mlgs-help`：忘记命令或想看菜单。

| 指令 | 用途 |
|---|---|
| `/mlgs-start` | 启动、接管、参与度设置、指针恢复 |
| `/mlgs-brainstorm` | 想点子、整理参考、生成 pitch/支柱/概念包 |
| `/mlgs-adopt <path>` | 分析并接管已有 Unity 项目 |
| `/mlgs-status` | 查看项目状态、员工动态、风险、下一步选项 |
| `/mlgs-plan` | 拆系统、Unity 技术方案、任务计划、原型策略 |
| `/mlgs-prototype` | 做原型，或记录跳过原型的风险 |
| `/mlgs-implement` | 实现已批准的 Unity/C# 任务 |
| `/mlgs-fix` | 修 bug、编译问题、QA 失败 |
| `/mlgs-review` | 审查代码、设计、任务、阶段、构建或工作流 |
| `/mlgs-test` | 跑验证，或写手动 QA 计划 |
| `/mlgs-build` | Unity 构建或构建预检 |
| `/mlgs-dashboard` | 刷新工作室看板 |
| `/mlgs-help` | 查看简短菜单 |

完整分组说明见 `workflow/command-index.md`。

## 员工角色

| 角色 | 负责 |
|---|---|
| Producer | 路由、状态、范围、任务分配 |
| Creative Director | 核心幻想、pitch、支柱、参考解读 |
| Game Designer | 系统、规则、数值、验收标准 |
| Unity Architect | Unity 架构、包、场景、构建风险 |
| Gameplay Developer | C# 玩法实现 |
| UI/UX Developer | HUD、运行时 UI、输入体验 |
| Technical Artist | Shader、VFX、生成美术接入、视觉性能 |
| QA Lead | 验证、smoke check、构建就绪 |

## 状态文件

根目录的 `studio/state.yaml` 只是模板，不是实时项目状态。

真实项目状态在：

```text
<UnityProject>/.mlgs/state.yaml
```

本地当前项目指针在：

```text
studio/current-project.local.yaml
```

它会被 git 忽略。

## 接管已有 Unity 项目

```text
/mlgs-adopt D:\path\to\YourUnityGame
```

MLGS 会检查：

- Unity version
- `Assets/`、`ProjectSettings/`、`Packages/manifest.json`
- 是否已有 `.mlgs/state.yaml`
- 是否有概念、设计、原型、任务计划、测试证据
- C# 和资产规模
- 当前最可能阶段
- 下一步应该做什么

确认接管后，它只会写：

```text
<UnityProject>/.mlgs/state.yaml
<UnityProject>/.mlgs/project.md
studio/current-project.local.yaml
```

不会默认改你的 Unity 生产文件。

## Dashboard

MLGS 每次执行路由任务都会记录：

```text
studio/logs/activity.jsonl
studio/runtime.json
dashboard/studio-data.js
```

打开：

```text
dashboard/index.html
```

你可以看到员工状态、最近活动、当前项目、阶段、参与度和下一条建议指令。

## 工具脚本

```powershell
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project -Apply
powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/init-project-state.ps1 -ProjectRoot E:/path/to/project -Name "My Game"
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/repair-pointer.ps1 -Clear
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
powershell -ExecutionPolicy Bypass -File tools/run-smoke-tests.ps1
```

## 当前定位

MLGS 现在不是一个兼容多平台的模板仓库，而是 Codex 里的 Unity 小型 AI 工作室。

它的默认目标是：少问废话，保留专业分工，把你想做的游戏一步步推进到可玩的 Unity 项目。

