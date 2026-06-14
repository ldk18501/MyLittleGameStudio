# Command: implement

## 目的

实现已批准的 Unity 生产任务。

## 主负责人

Gameplay Developer

## 支持角色

- 架构敏感工作由 Unity Architect 支持
- UI 任务由 UI/UX Developer 支持
- 视觉/VFX/生成美术任务由 Technical Artist 支持
- 验证由 QA Lead 支持

## 读取

- 已解析项目 `.mlgs/state.yaml`
- project `production/task-plan.md`
- 如存在，读取 project `production/tasks/[task].md`
- 相关设计/系统文档
- 相关 Unity 文件

## 写入

- 已批准路径中的 Unity 项目文件
- project `production/tasks/[task].md`
- 测试或 QA 证据

## 流程

1. 从用户请求或 task plan 中解析任务。
2. 确认 production 已解锁。如果未解锁，只有在用户明确要求时继续，并记录风险。
3. 读取设计、技术方案和现有代码。
4. 当任务涉及玩法机制、游戏手感、成长、反馈、运行时对象数量、对象池、输入时序或性能敏感代码时，使用 `mlgs-unity-mechanics`。
   - 如果任务涉及弹幕、海量对象、DOD、instancing、对象池升级、批量更新或自定义碰撞，读取 `references/dod-performance.md` 并记录采用 L1/L2/L3/L4 哪一层。
5. 制定聚焦实现计划，写清 Unity 组件/数据边界、调参字段、反馈 hook 和验证方式。
6. 如果编辑会影响受保护路径、包、项目设置、核心架构或不清楚的玩法行为，才询问。
7. 实现任务。
8. 运行可用的编译、smoke 或测试检查。
9. 记录：
   - files changed
   - acceptance criteria covered
   - tests/checks run
   - deviations and risks
   - performance tier and scale target when using DOD/instancing
   - trace event with lead/supporting agents, skills used, files read/written, decisions, and verification

## 完成条件

- 任务已实现，或 blocked 且原因清楚。
- 验证证据已记录。
