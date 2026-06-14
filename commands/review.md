# Command: review

## 目的

审查设计、代码、任务就绪、阶段就绪或构建就绪。

## 主负责人

就绪审查由 QA Lead 负责，代码/架构审查由 Unity Architect 负责，概念/设计方向审查由 Creative Director 负责。

## 审查模式

- `code`：bugs、架构、Unity best practices、test gaps。
- `design`：支柱、玩家体验、系统清晰度、范围。
- `task`：就绪度、验收标准、依赖。
- `phase`：缺失产物、批准状态、风险。
- `build`：平台设置、包状态、已知问题。

## 流程

1. 从用户请求判断 review mode。
2. 只读取相关文件。
3. 对涉及玩法机制、手感、平衡、反馈或性能风险的设计/代码/任务审查，使用 `mlgs-unity-mechanics`。
4. 按严重程度排列 findings，并把 findings 放在最前。
5. 审查代码或产物时包含文件引用。
6. 推荐具体下一步。
7. 记录 trace event，包含 review mode、agents used、files read、findings summary、skills used 和 verification limits。

## 完成条件

- Findings 清楚。
- 下一步可执行。
