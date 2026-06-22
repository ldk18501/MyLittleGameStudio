# MyLittleGameStudio Agent 说明

## 身份

MyLittleGameStudio 是一个面向 Unity 独立游戏项目的小型 AI 游戏工作室。

用户是项目所有者。AI 以紧凑工作室的方式协作：角色清晰、命令轻量，并默认保持较高自主性。开局、恢复和接管阶段优先降低用户认知负担；生产阶段优先高效执行。

## 优先读取

做任何工作流判断前，先读取：

1. `studio/config.md`
2. `workflow/command-router.md`
3. `workflow/onboarding.yaml`
4. `workflow/phases.yaml`
5. 通过 `rules/state.md` 解析出的项目状态

只在任务需要时读取具体 command、agent、template 和 rule 文件。

## 命令路由

当用户请求工作流动作时，通过 `workflow/command-router.md` 路由。

中文示例：

- "开始" -> `commands/start.md`
- "接管项目" / "已有项目" -> `commands/adopt.md`
- "看状态" / "下一步做什么" -> `commands/status.md`
- "整理参考" / "分析竞品" -> `commands/references.md`
- "生成概念包" / "确定核心玩法" -> `commands/concept.md`
- "做设计和技术方案" / "拆系统" -> `commands/design-plan.md`
- "做原型" -> `commands/prototype.md`
- "实现这个功能" / "继续开发" -> `commands/implement.md`
- "修这个问题" / "修 bug" -> `commands/fix.md`
- "审查一下" -> `commands/review.md`
- "跑测试" / "验证一下" -> `commands/test.md`
- "打包" / "构建 APK" -> `commands/build.md`
- "生成美术图" -> `commands/generate-art.md`

如果用户请求能明确匹配命令，就执行该命令。如果有歧义，只问一个简短澄清问题。

## Guide Kernel

`start`、`status` 和 `adopt` 是用户引导入口，不只是普通命令。

在普通项目命令前：

1. 用 `tools/resolve-state.ps1 -AllowTemplate` 或等价方式检查活动项目。
2. 如果本地 pointer 断裂，先进入恢复分支：问用户提供新路径还是清除 pointer。
3. 如果只有模板状态，进入 `start` 的 A/B/C/D 起点选择。
4. 如果用户提供已有项目路径，进入 `adopt` 做差距盘点。
5. 每次引导只给一个 next question 或一个明确 next command。

## 自动化等级

先读取已解析的项目状态。如果还没有项目状态，只把 `studio/state.yaml` 当初始化模板。若未设置自动化等级，探索规划默认 `high`，生产代码默认 `medium`。

- `high`：做合理决策，写草案，运行检查，记录假设，只在关键关口询问。
- `medium`：先起草，重大方向、架构、依赖或阶段变化前询问。
- `low`：更频繁展示选项，并确认重要写入。

引导阶段不把“少问”理解成“让用户懂内部机制”。应先问用户处境，再映射到内部字段。

## 只在必要时询问

以下情况先问用户：

- 删除或覆盖重要文件。
- 修改引擎、包、项目设置、场景结构或核心架构。
- 跳过必要安全关口。
- 添加第三方依赖。
- 做重大创意或商业化决策。
- 需求确实含糊，继续会造成明显返工。
- 初始化、接管或恢复项目时需要用户选择路径或起点。

普通状态更新、草案、小型文档更新、聚焦代码编辑、测试运行和非破坏性分析不需要提前询问。

## Trace 政策

每个被 MLGS 路由的任务都要留下审计轨迹，方便用户看到哪些工作室角色实际参与。

每个命令需要：

1. 确定 command、lead agent、supporting agents 和使用的外部 skills。
2. 记录读取文件、写入文件、假设、决策和验证。
3. 向 `studio/logs/activity.jsonl` 追加事件。
4. 更新 `studio/runtime.json`。
5. 刷新 `dashboard/studio-data.js`，让 `dashboard/index.html` 展示最新工作室视图。

优先使用 `tools/trace.ps1` 写入 trace 数据。如果工具不可用，按 `studio/trace.schema.json` 的 schema 手动更新同样文件。

## 单一状态规则

每个项目只有一个规范状态文件。优先使用：

- 外部或嵌入 Unity 项目：`<UnityProject>/.mlgs/state.yaml`
- MLGS 内部项目：`projects/<slug>/.mlgs/state.yaml`

`studio/state.yaml` 是模板，不是实时项目状态。`studio/current-project.local.yaml` 可以指向当前项目状态，且必须保持本地文件。

只有在已解析项目状态保持正确后，才能把细节追加到项目笔记或 session log。

## Unity 偏好

本工作室 Unity-first。优先采用：

- Unity 2022 LTS 或 Unity 6 项目约定。
- C# 中使用 `[SerializeField] private` 字段。
- 用 ScriptableObject 承载数据驱动内容。
- 在能降低耦合时使用事件驱动玩法流程。
- 生产中需要生成资产或运行时加载资产时，考虑 Addressables。
- 用 Unity Test Runner 或项目本地 smoke test 验证。
