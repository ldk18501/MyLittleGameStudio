# Command: status

## 目的

展示当前项目状态、缺失产物、风险和最合适的下一步；同时把下一步翻译成用户现在要回答的一个问题。`status` 是教练入口，不只是报告。

## 主负责人

Producer

## 读取

- `workflow/onboarding.yaml`
- 已解析项目 `.mlgs/state.yaml`，没有配置项目时读取 `studio/state.yaml` 模板
- `workflow/phases.yaml`
- 如存在，读取 `studio/current-project.local.yaml`
- 如存在，读取 `studio/runtime.json`
- 如存在，读取 `studio/logs/activity.jsonl` 最新条目
- 活动项目产物（如果存在）

## 写入

- 只有在修正过期 next action、记录观察到的风险或修复本地 pointer 后，才写入已解析项目 `.mlgs/state.yaml` 或 `studio/current-project.local.yaml`。
- 如果 pointer 断裂，不要写项目状态；先提出恢复问题。

## 流程

1. 解析并读取项目状态，优先运行或等价执行：
   - `tools/resolve-state.ps1 -AllowTemplate`
2. 如果本地 pointer 存在但目标状态不存在：
   - 报告断裂的 `state_path` 和 `project_root`
   - 推荐两个动作之一：提供新的 Unity/project path 修复，或清除 pointer 重新开始
   - 下一问必须是：“要修复到哪个项目路径，还是清除当前指针？”
   - 可使用 `tools/repair-pointer.ps1`
   - 记录 `status` trace event，状态为 `partial`
   - 停止，不继续项目级命令
3. 如果只有模板可用：
   - 报告“当前没有活动项目”
   - 展示 `workflow/onboarding.yaml` 的 A/B/C/D 起点
   - 下一问必须是：“你现在属于 A、B、C、D 哪一种？”
4. 如果已配置活动项目路径，验证路径存在。
5. 检查当前阶段所需产物。
6. 报告：
   - active project
   - current phase
   - approvals
   - prototype policy and verdict
   - latest studio activity and agents used
   - completed/missing artifacts
   - risks
   - recommended next command
   - next question
7. 用以下规则生成 next question：
   - 缺 references：询问用户是否提供 2-5 个参考，或让 MLGS 先起草临时参考
   - 缺 concept：询问一句话 pitch，或是否从 references 推导
   - 缺 design-plan：询问是否把概念拆成系统与技术方案
   - 缺 prototype：询问是否做聚焦原型，或记录跳过风险
   - production ready：询问优先实现哪个已批准任务
8. 如果状态与文件系统冲突，说明冲突并推荐 `start`、`adopt` 或 pointer repair。
9. 记录 `status` trace event。

## 完成条件

- 用户知道当前真实状态。
- 用户知道推荐下一命令。
- 用户看到一个可以马上回答的下一问。
