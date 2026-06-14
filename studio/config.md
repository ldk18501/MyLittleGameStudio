# MyLittleGameStudio 配置

## 工作室模型

- 工作室风格：小型 Unity 独立游戏工作室。
- 主引擎：Unity。
- 默认自动化：规划阶段 `high`，生产代码阶段 `medium`。
- 项目所有者：用户。
- 协调角色：Producer。

## 状态策略

- 根状态模板：`studio/state.yaml`。
- 本地当前项目指针：`studio/current-project.local.yaml`。
- 规范项目状态：活动游戏工作区内的 `.mlgs/state.yaml`。
- 不要在根目录其他文件里重复记录活动项目或当前阶段。
- 历史笔记可以保存在项目本地 `production/session-log.md`，但不能覆盖已解析的 `.mlgs/state.yaml`。

## 安全策略

- 在所选自动化等级下，可以直接进行普通代码/文档编辑。
- 破坏性操作、依赖变化、包变化、构建设置变化和项目级重写需要明确批准。
- 外部接管项目在生产编辑前必须配置 approved write paths。

## 原型策略

- 对不确定核心循环，推荐 HTML 原型。
- 当真正风险来自 Unity 交互、物理、UI 或渲染时，可以用 Unity greybox 原型。
- 如果用户明确跳过，在已解析项目状态中记录 `prototype.policy: skipped-with-risk` 后可以跳过原型关口。

## 生产策略

满足以下任一条件后可以开始 production：

1. concept 与 design-plan 已批准，且 prototype 已通过；或
2. concept 与 design-plan 已批准，且 prototype 被明确跳过并记录了原因。
