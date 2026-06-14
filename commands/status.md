# Command: status

## 目的

展示当前项目状态、缺失产物、风险和最合适的下一步。

## 主负责人

Producer

## 读取

- 已解析项目 `.mlgs/state.yaml`，没有配置项目时读取 `studio/state.yaml` 模板
- `workflow/phases.yaml`
- 如存在，读取 `studio/runtime.json`
- 如存在，读取 `studio/logs/activity.jsonl` 最新条目
- 活动项目产物（如果存在）

## 写入

- 只有在修正过期 next action 或记录观察到的风险时，才写入已解析项目 `.mlgs/state.yaml`。

## 流程

1. 解析并读取项目状态。
2. 如果已配置活动项目路径，验证路径存在。
3. 检查当前阶段所需产物。
4. 报告：
   - active project
   - current phase
   - approvals
   - prototype policy and verdict
   - latest studio activity and agents used
   - completed/missing artifacts
   - risks
   - recommended next command
5. 如果状态与文件系统冲突，说明冲突并推荐 `start` 或 state repair。
6. 记录 `status` trace event。

## 完成条件

- 用户知道当前真实状态和下一步该做什么。
