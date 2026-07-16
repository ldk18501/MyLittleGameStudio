# MyLittleGameStudio 中文说明

MyLittleGameStudio（简称 MLGS）是一个面向 Codex、用于制作正式 Unity + C# 游戏的 AI 小型工作室流程。

它保留了“由专业角色协作制作游戏”的价值，但去掉了笨重的多 Agent 编排，改为一个 `/mlgs` 入口、少量 Unity 专职角色、机器可读的生产契约，以及必须有真实证据才能通过的质量门禁。

MLGS 重点防止三类常见问题：

- 设计效果图很精致，Unity 实机却只剩纯色背景、普通按钮和占位 UGUI；
- 原型功能稍微补全后就被叫作 `1.0`，实际缺少内容量、引导、配置、美术、音频、QA 和发布证据；
- 新代码无视已有框架，或者反过来被不合适的老代码强制绑架，只能继续堆 Demo 式逻辑。

## 当前定位

- 只支持 Codex，不保留 Claude Code 兼容层、hooks 或 settings。
- 只面向 Unity + C#，默认遵循 Unity 2022 LTS 或 Unity 6 的开发习惯。
- 只公开一个 `/mlgs` 入口，后面直接用自然语言描述需求。
- 覆盖新项目、老项目接管、规划、原型、正式美术、代码实现、测试、成品化、构建与发布准备。
- 支持低、中、高三档老板参与度。
- 通过 Dashboard 和 trace 展示项目状态与各角色活动。

## 快速开始

在仓库根目录注册本地 marketplace：

```powershell
codex plugin marketplace add .
```

然后在 Codex App 的插件页面安装 **my-little-game-studio**，新开一个 Codex 任务并输入：

```text
/mlgs 我想开始一个新的 Unity 游戏，低参与度
```

如果之前已经注册过 marketplace，而仓库刚刚更新，可以重新注册并新开任务，让 Codex 加载新版本：

```powershell
codex plugin marketplace remove my-little-game-studio-local
codex plugin marketplace add .
```

不同 Codex Desktop 版本暴露的插件子命令可能不同，请以 `codex plugin --help` 的实际结果为准。

## 一个入口，自然语言路由

你只需要记住：

```text
/mlgs 你的需求
```

| 你可以输入 | MLGS 会做什么 |
|---|---|
| `/mlgs 开始一个新的 Unity 游戏，低参与度` | 引导启动并设置参与度 |
| `/mlgs 接管 D:\path\to\YourUnityGame` | 检查并接管已有项目 |
| `/mlgs 看看当前状态，告诉我下一步` | 查看状态、风险、员工活动和下一步 |
| `/mlgs 帮我构思一个休闲割草游戏` | 整理参考、pitch、支柱和概念包 |
| `/mlgs 把当前概念拆成正式开发计划` | 拆系统、技术方案、发布范围、任务和原型策略 |
| `/mlgs 做一个最小原型验证核心手感` | 制作 HTML 交互原型或 Unity 灰盒 |
| `/mlgs 继续实现下一个正式任务` | 结合项目框架与代码风格实现 Unity/C# 功能 |
| `/mlgs 生成并接入下一批正式美术` | 生成、处理、导入、引用并在 Unity 实机验收 |
| `/mlgs 把当前版本推进到 Vertical Slice` | 验证一段具有最终品质的代表流程 |
| `/mlgs 检查 Content Complete 成品度` | 查占位内容、缺失内容、未接线流程和代码阻断项 |
| `/mlgs 检查图标、本地化和崩溃错误` | 完成游戏工程负责的发布准备 |
| `/mlgs 修一下这个编译错误` | 诊断并修复明确范围的问题 |
| `/mlgs 跑一轮验证` | 编译、测试、smoke check 或补 QA 证据 |
| `/mlgs 做构建预检` | 检查 Unity 构建就绪状态 |
| `/mlgs 打开 dashboard` | 刷新并打开工作室活动数据 |

完整的分组菜单由 `workflow/command-index.md` 生成。

## 从原型到正式发布

```text
概念 -> 规划 -> 原型 -> Vertical Slice -> 正式生产
     -> Content Complete -> Alpha -> Beta -> Release Candidate -> Release
```

版本号不会自动推进阶段。`0.1.x` 代表原型/预发布；只有最终 Release 门禁通过，游戏才能标记为 `1.0.0` 或“可以上线”。

正式生产前必须建立明确的发布范围，并覆盖适用的：

- 功能和内容数量；
- 玩家流程、首次体验、引导和教学节点；
- UI 页面、状态和交互；
- 配置表与数据来源；
- 正式美术、动画、特效和音频；
- 本地化与目标平台行为；
- 性能、异常路径、运营准备和构建证据。

“全部完成”是指批准范围里的每一项都已经验证，而不是当前实现列表里暂时没有 TODO。

## 三档自适应代码策略

MLGS 不再用一套死规则处理所有工程，而是根据项目规模调整代码理解和架构约束强度。

| 项目类型 | 强度 | 默认处理方式 |
|---|---|---|
| 全新项目 | `lightweight` | 建立当前真正需要的最小正式框架，不强制模仿不存在的旧代码 |
| 小型老项目 | `standard` | 阅读目标模块和至少两个同类/风格范例，优先保持一致，但允许更合理的隔离设计 |
| 大型框架项目 | `deep` | 至少阅读三个范例、五个上下文文件，并在修改前后提供依赖与影响证据 |

项目类型会自动判断，也允许老板或 Unity Architect 写明理由后覆盖。CodeGraph 不是强制依赖：大型项目必须提供结构证据，但证据可以来自 CodeGraph、Roslyn 或经过记录的人工结构分析。

已有代码是重要证据，但不是监狱。经过审查的变更计划可以选择：

- 延续现有接入点；
- 调整已有框架习惯；
- 替换会持续制造耦合或维护问题的旧实现；
- 为全新需求建立最小基础框架；
- 建立边界清晰的新模块。

正式代码任务必须经过：

```text
工作包 -> 代码库画像/模块图 -> 任务上下文
       -> 变更计划 -> 实施前检查 -> 正式实现
       -> 一致性/影响检查 -> 客观验收证据
```

这套流程会拦截“只看策划文档就开写”、未申报的 Manager/Service、计划外文件修改、风格偏离，以及只在 Demo/Test 场景里能运行的伪完成。

## 效果图到 Unity 实机的正式美术链路

HTML 原型只能证明交互，不是生产美术标准。原型里的纯色面板、按钮样式和临时布局不能被直接带入正式版本。

正式美术由以下契约共同约束：

- 已批准的视觉目标和风格圣经；
- 整屏级 `visual scene contract`；
- 固定的 Unity Scene、Camera、分辨率和截图方式；
- 构图锚点、景深层级、渲染器归属、材质/灯光语言和细节密度；
- 资产清单和导入配方；
- 真实 Unity 引用与游戏内截图；
- Art Director 和 QA 的 fail-closed 对比评审。

正式资产生命周期为：

```text
planned -> prompt-ready -> generated -> selected -> processed
        -> imported -> referenced -> approved in game
```

单张图片画得好不等于游戏美术完成。代表性 Unity 场景必须在整屏构图、层次、质感、光照、细节和交互位置上接近批准目标，才能通过验收。

对于 2D 游戏，主玩法默认使用 `SpriteRenderer`/`TilemapRenderer` 等场景内容；UGUI 或 UI Toolkit 只负责 HUD、菜单、弹窗、背包、提示和明确批准的例外。除非老板明确批准“纯 UI 游戏”，否则 UI View 不得持有权威玩法规则。

## 证据驱动的质量门禁

MLGS 不接受一句“已经完成”，而是检查机器可读的生产证据：

- 工作包把主观完成声明和客观检查结果分开，并限制返工轮数；
- Unity 游戏类型 Profile 定义该类型的最低系统、内容、UI、教学、美术、音频和性能规模；
- 设计基线使用哈希冻结，源设计变化会自动使受影响的阶段失效；
- 每个正式 UI 页面都有状态、资产、Unity 实现和证据契约；
- 图片、Sprite、模型、动画、音频、视频、Unity 导入和视觉对比能力缺失时会关闭门禁，而不是允许用占位资源上线；
- Vertical Slice 到 Release 都需要结构化报告和可解析的项目内证据；
- 单独的 Demo/Test 场景不能作为正式接入证明。

## 工作室角色

| 角色 | 负责内容 |
|---|---|
| Producer | 路由、范围、状态、工作包和阶段门禁 |
| Creative Director | 核心幻想、pitch、支柱和参考解读 |
| Art Director | 视觉目标、整屏构图一致性、风格监管和实机最终批准 |
| Game Designer | 系统、规则、数值、引导和验收标准 |
| Unity Architect | 代码库画像、模块边界、包、场景、数据和构建风险 |
| Gameplay Developer | 模块化 C# 玩法实现 |
| UI/UX Developer | HUD、菜单、运行时 UI、输入体验和页面契约 |
| Technical Artist | Shader、VFX、资产处理/导入、渲染接入和视觉性能 |
| QA Lead | 客观检查、smoke test、回归和发布证据 |

这些角色默认是当前 Codex 任务里的逻辑专业环节；只有老板明确要求时才拆成独立任务。

## 项目状态与运行数据

仓库中的 `studio/state.json` 只是经过校验的模板。每个游戏只有一个正式状态文件：

```text
<UnityProject>/.mlgs/state.json
```

用户本地运行数据默认位于：

```text
$CODEX_HOME/mlgs/current-project.json
$CODEX_HOME/mlgs/runtime.json
$CODEX_HOME/mlgs/logs/activity.jsonl
$CODEX_HOME/mlgs/dashboard/studio-data.js
```

没有设置 `CODEX_HOME` 时使用 `~/.codex/mlgs/`。旧 `.mlgs/state.yaml` 和 `studio/current-project.local.yaml` 仍可读取，只有明确执行迁移时才会转换。

打开 `dashboard/index.html` 可以查看当前项目、实际阶段、参与度、最近工作、角色状态、风险和推荐的下一条指令。

## 常用仓库工具

```powershell
# 状态与项目接管
powershell -ExecutionPolicy Bypass -File tools/resolve-state.ps1 -AllowTemplate
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/adopt-project.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate

# 初始化生产契约并判断代码策略强度
powershell -ExecutionPolicy Bypass -File tools/init-production-pipeline.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/inspect-codebase.ps1 -ProjectRoot E:/path/to/project -Apply

# 准备和验证一个正式代码任务
powershell -ExecutionPolicy Bypass -File tools/new-code-task.ps1 -ProjectRoot E:/path/to/project -TaskId feature-id
powershell -ExecutionPolicy Bypass -File tools/test-code-task.ps1 -ProjectRoot E:/path/to/project -TaskId feature-id
powershell -ExecutionPolicy Bypass -File tools/preflight-task.ps1 -Command implement -TaskId feature-id

# 工程与插件验证
powershell -ExecutionPolicy Bypass -File tools/test-production-code.ps1 -ProjectRoot E:/path/to/project
powershell -ExecutionPolicy Bypass -File tools/validate-changes.ps1
powershell -ExecutionPolicy Bypass -File tools/run-smoke-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/generate-workflow.ps1 -Check
powershell -ExecutionPolicy Bypass -File tools/build-plugin-package.ps1 -Check
```

`tools/new-code-task.ps1` 要求先存在同 ID 的正式工作包。正常使用 `/mlgs` 时，Producer 会自动协调这些产物，不需要老板手工维护整条链路。

## 仓库结构

- `commands/`：自然语言意图对应的内部路由
- `agents/`：专业角色契约
- `rules/`：状态、生产代码和工作流规则
- `studio/`：schema、配置和状态模板
- `templates/`：项目生产产物模板
- `profiles/unity/`：不同 Unity 游戏类型的最低生产范围
- `tools/`：状态、规划、美术、代码、门禁、构建、trace 和打包工具
- `plugins/my-little-game-studio/`：生成后的自包含插件包
- `dashboard/`：本地工作室活动看板

仓库根目录是唯一源码。不要手工修改 `plugins/my-little-game-studio/` 中由构建脚本镜像出来的工作流文件；应修改根目录源码后重新生成插件包。
