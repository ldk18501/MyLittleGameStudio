# Command: prototype

## 目的

在 production 前验证核心循环或高风险交互，同时不把原型变成每个项目的僵硬阻塞。

## 主负责人

Gameplay Developer

## 支持角色

- Producer
- Game Designer
- Technical Artist
- UI/UX Developer
- QA Lead

## 读取

- project `design/concept-package.md`
- project `design/systems/*.md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- project `.mlgs/state.yaml`

## 写入

- project `prototype/prototype-plan.md`
- project `prototype/html/` 或 Unity greybox artifacts
- project `prototype/playtest-report.md`
- project `.mlgs/state.yaml`

## 流程

1. 解析活动项目。
2. 从项目状态读取 prototype policy。
3. 如果用户要求跳过，记录：
   - `prototype.policy: skipped-with-risk`
   - `prototype.verdict: skipped`
   - skip reason
   - production risk
4. 如果要构建原型：
   - 定义最小可玩范围
   - 使用 `mlgs-unity-mechanics` 只选择验证核心风险所需的机制模式
   - 优先使用可读视觉占位，而不是纯文字对象
   - 根据风险构建 HTML prototype 或 Unity greybox
   - 实际可行时本地运行
   - 创建 playtest report
5. 记录 verdict：
   - pass
   - revise
   - return-to-design
   - skipped
6. 如果 pass 或 skipped-with-risk，且 design-plan 已批准，设置 production unblocked。

## 完成条件

- 原型存在并已评估，或跳过风险已明确记录。
- 原型报告写明已测试机制、调参假设和 pass/revise 证据。
