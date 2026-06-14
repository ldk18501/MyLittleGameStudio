# Command: fix

## 目的

诊断并修复 bug、试玩问题、构建失败、UI 问题、编译错误或 QA 失败。

## 主负责人

根据问题类型由 Gameplay Developer 或 UI/UX Developer 负责。

## 支持角色

- 架构/构建/包问题由 Unity Architect 支持
- 复现和验证由 QA Lead 支持
- 视觉/VFX 问题由 Technical Artist 支持

## 流程

1. 捕获症状和期望行为。
2. 复现问题或检查相关证据。
3. 定位最小责任区域。
4. 做窄范围修复。
5. 运行最相关验证。
6. 在任务或 QA 记录中写明修复和证据。
7. 记录 trace event，包含 symptom、agent handoff、files read/written、decision 和 verification result。

## 只在以下情况询问

- 修复需要改变设计行为。
- 修复触及大范围架构、包、场景、Prefab 或项目设置。
- 存在多个有效修复方案，且产品手感不同。

## 完成条件

- Bug 已修复并验证，或因具体缺失输入而 blocked。
