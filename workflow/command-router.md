# 命令路由器

把用户请求路由到 command 文件。选择最接近的命令，同时先判断用户是否需要 onboarding、恢复或接管。

## 执行任何命令前

读取：

1. `studio/config.md`
2. `rules/state.md`
3. 本 router
4. `workflow/onboarding.yaml`
5. 已解析项目状态；如果没有项目配置，则只把 `studio/state.yaml` 当模板
6. 被选中的 command 文件
7. 相关 agent 文件

解析：

1. command name
2. lead agent
3. supporting agents
4. 使用的 external skills（如有）
5. 预期读取或写入的文件
6. 用户当前需要的是执行、引导、恢复还是接管

## Guide Kernel

在普通命令路由前，先执行轻量状态判断：

1. 运行或等价执行 `tools/resolve-state.ps1 -AllowTemplate`。
2. 如果 `needs_repair: true`，优先路由到 `status` 或 `start` 的恢复分支，下一问是修复路径还是清除 pointer。
3. 如果只有 `studio/state.yaml` 模板可用，优先路由到 `start`，并展示 `workflow/onboarding.yaml` 的 A/B/C/D 起点。
4. 如果用户提供 project path，运行或等价执行 `tools/detect-project-stage.ps1 -ProjectRoot <path>`：
   - 已有 `.mlgs/state.yaml` -> `status` 或 pointer repair
   - 是 Unity 项目但没有 MLGS 状态 -> `adopt`
   - 有文档/原型/代码但不是 Unity 项目 -> `adopt`
   - 空目录或没有材料 -> `start`
5. 如果命令会进入 production 但项目未解锁，先路由到 `status` 或 `design-plan/prototype`，除非用户明确要求带风险继续。

## 用户体验规则

- `start`、`status`、`adopt` 必须输出一个明确 next question，除非已经完成了具体写入动作。
- 不把内部字段名当作第一问题；先问用户处境，再映射到状态字段。
- 同一轮只问一个开放问题；需要选择时提供 2-4 个选项。
- 推荐下一命令后不要自动运行它，除非用户当前请求明确要求执行。

## 执行任何命令后

可行时使用 `tools/trace.ps1` 记录 audit event。

事件应包含：

- command
- task title
- status
- lead agent
- agents used
- skills used
- files read
- files written
- assumptions
- decisions
- verification

这样可以保持 `studio/logs/activity.jsonl`、`studio/runtime.json` 和 `dashboard/studio-data.js` 与 dashboard 对齐。

## 命令表

| Command | File | Use When |
|---|---|---|
| `start` | `commands/start.md` | 从零开始、初始化、恢复断裂 pointer、重新选择项目 |
| `adopt` | `commands/adopt.md` | 接管已有 Unity 项目、文档、原型或代码，并盘点缺口 |
| `status` | `commands/status.md` | 查看当前状态、下一步、缺失产物，并得到下一问 |
| `references` | `commands/references.md` | 收集/分析参考游戏、图片和避让项 |
| `concept` | `commands/concept.md` | 创建或修订概念包 |
| `design-plan` | `commands/design-plan.md` | 系统设计、Unity 技术方案、任务计划 |
| `prototype` | `commands/prototype.md` | 构建、跳过、修订或评估原型 |
| `implement` | `commands/implement.md` | 实现已批准的 Unity 任务 |
| `fix` | `commands/fix.md` | 诊断并修复 bug、试玩问题、编译问题或 QA 失败 |
| `review` | `commands/review.md` | 审查代码、设计、任务计划或阶段就绪 |
| `test` | `commands/test.md` | 运行检查、定义 QA 证据、smoke test |
| `build` | `commands/build.md` | 配置或产出 Unity 构建/APK |
| `generate-art` | `commands/generate-art.md` | 生成占位美术或概念美术 |

## 中文触发示例

- "开始" -> `start`
- "接管项目" / "已有项目" -> `adopt`
- "看状态" / "下一步" -> `status`
- "分析参考" -> `references`
- "生成概念包" -> `concept`
- "做设计方案" -> `design-plan`
- "做原型" -> `prototype`
- "实现这个任务" -> `implement`
- "修这个 bug" -> `fix`
- "审查一下" -> `review`
- "跑测试" -> `test`
- "打包 APK" -> `build`
- "生成美术图" -> `generate-art`

## 歧义规则

如果多个命令都合适，只问一个短问题。除非用户要求，不展示长菜单。
