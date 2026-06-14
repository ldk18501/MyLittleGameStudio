# 命令路由器

把用户请求路由到 command 文件。选择最接近的命令，保持路由轻量。

## 执行任何命令前

读取：

1. `studio/config.md`
2. `rules/state.md`
3. 本 router
4. 已解析项目状态；如果没有项目配置，则只把 `studio/state.yaml` 当模板
5. 被选中的 command 文件
6. 相关 agent 文件

解析：

1. command name
2. lead agent
3. supporting agents
4. 使用的 external skills（如有）
5. 预期读取或写入的文件

如果只有根模板状态可用，项目级请求先路由到 `start`，再进入 production 工作。

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
| `start` | `commands/start.md` | 初始化、接管、恢复或配置项目 |
| `status` | `commands/status.md` | 查看当前状态、下一步、缺失产物 |
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
- "看状态" -> `status`
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
