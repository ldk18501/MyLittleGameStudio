# Command: design-plan

## 目的

把概念转成系统设计、Unity 技术方案、任务计划、资产需求和测试策略。

## 主负责人

Game Designer

## 支持角色

- Producer
- Unity Architect
- Gameplay Developer
- UI/UX Developer
- Technical Artist
- QA Lead

## 读取

- project `design/concept-package.md`
- project `design/reference-analysis.md`
- 可用时读取现有 Unity 项目结构

## 写入

- project `design/systems/[system].md`
- project `docs/tech-plan.md`
- project `production/task-plan.md`
- 可选 project `design/assets/asset-requirements.md`
- 可选 project `design/ux/[screen].md`
- project `.mlgs/state.yaml`

## 流程

1. 解析活动项目。
2. 确认概念包存在；如果缺失，先起草必要概念假设。
3. 对涉及玩法机制、游戏手感、经济、成长、反馈或性能敏感运行时行为的 MVP 系统，使用 `mlgs-unity-mechanics`。
   - 如果系统涉及弹幕、海量对象、对象池、GPU instancing、自定义 culling/碰撞或 DOD 数据布局，同时读取 `references/dod-performance.md`。
4. 拆解 MVP 系统。
5. 为每个 MVP 系统创建紧凑系统设计：
   - purpose
   - player experience
   - rules
   - edge cases
   - tuning ranges
   - dependencies
   - acceptance criteria
6. Unity Architect 起草技术方案：
   - Unity version and platform
   - architecture
   - data/content strategy
   - package risks
   - scene/prefab strategy
   - testing strategy
   - 大规模对象系统的 authoring/runtime 边界、优化层级和降级策略
7. Producer 创建 `production/task-plan.md`。
8. QA Lead 检查验收标准，确保每个玩法机制覆盖正常、边界、失败、反馈和性能路径。
9. 决定 prototype policy：
   - 核心循环不确定时推荐原型
   - 风险来自引擎交互时使用 Unity greybox
   - 用户想直接生产时记录 skipped-with-risk
10. 在项目状态中记录批准和 next action。

## 完成条件

- MVP 系统已文档化。
- 技术方案存在。
- 任务计划存在。
- Prototype policy 已记录。
- 使用该技能时，trace 记录 `mlgs-unity-mechanics`。
