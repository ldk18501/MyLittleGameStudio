# Command: concept

## 目的

创建或修订概念包。

## 主负责人

Creative Director

## 支持角色

- Producer
- Game Designer
- Technical Artist
- 界面是核心时加入 UI/UX Developer

## 读取

- project `design/references.md`
- project `design/reference-analysis.md`
- 已存在的 `design/concept-package.md`

## 写入

- project `design/concept-package.md`
- project `.mlgs/state.yaml`

## 流程

1. 解析活动项目。
2. 总结用户意图和参考分析。
3. 起草：
   - 一句话 pitch
   - 核心幻想
   - 目标玩家
   - 3-5 个玩法支柱
   - 反目标
   - 核心循环
   - 视觉方向
   - MVP 和 stretch scope
   - 风险和假设
4. 自动化等级为 high 时，写入推荐概念包并请求关口批准。
5. 自动化等级为 medium/low 时，先展示紧凑草案再定稿。
6. 如果已批准，在项目状态中设置 `approvals.concept_package: true`，并把 next action 设为 `design-plan`。

## 完成条件

- 概念包存在。
- 批准状态已记录。
