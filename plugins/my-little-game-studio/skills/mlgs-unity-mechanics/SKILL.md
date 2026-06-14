---
name: mlgs-unity-mechanics
description: "MyLittleGameStudio 的 Unity 游戏机制、手感、玩法循环、调参、性能优化、DOD 数据导向实现和 QA 验收技能。用于 MLGS agent 设计、原型、实现、审查或测试 Unity gameplay systems，例如 Roguelike 成长、输入缓冲、土狼时间、战斗手感、juice、经济系统、反馈系统、对象池、批处理、GPU instancing、DrawMeshInstanced/RenderMeshInstanced、弹幕、海量对象、空间查询、帧预算、移动端性能、调参范围、验收标准和性能风险分析。"
---

# MLGS Unity 机制库

本技能把 `game-mechanics-optimizations` 知识库提炼成 Unity 项目可执行的工作方法。使用时不要照搬 Godot/GDScript 示例；先抽取机制意图、参数、边界条件和验证方式，再翻译成 Unity/C#、ScriptableObject、Prefab、Scene、测试或原型任务。

## 快速流程

1. 先判断任务类型：
   - **玩法设计**：读 `references/mechanics-map.md`。
   - **Unity 实现**：读 `references/unity-recipes.md`。
   - **性能优化**：读 `references/performance-checklist.md`。
   - **DOD/海量对象/弹幕/Instancing**：读 `references/dod-performance.md`。
   - **验收/测试**：读 `references/qa-acceptance.md`。
2. 把需求压成一个“机制卡”：
   - 玩家目标：玩家为什么需要这个系统。
   - 核心规则：输入、状态、奖励、失败、冷却、限制。
   - 调参范围：默认值、最小值、最大值、单位。
   - 反馈通道：动画、音效、VFX、UI、震动、相机。
   - 性能风险：热路径、对象数量、GC、Draw Call、物理查询。
   - 验收证据：可手测步骤、自动测试点、Profiler 指标。
3. 产物必须能被 MLGS 角色继续执行：
   - Game Designer 输出系统规则和调参表。
   - Unity Architect 输出架构和性能约束。
   - Gameplay Developer 输出聚焦实现计划和 Unity 文件改动。
   - QA Lead 输出验收标准、烟测步骤和剩余风险。

## Unity 默认落地方式

- 用 `[SerializeField] private` 暴露调参字段，避免 public 数据随意漂移。
- 稳定数据优先用 `ScriptableObject`，运行状态放组件或纯 C# runtime model。
- 高频对象使用对象池；热路径避免 LINQ、装箱、临时 `new`、字符串拼接。
- 数量巨大且行为同质的实体，优先考虑 manager/system 统一管理数据数组，而不是每个实体一个 `MonoBehaviour.Update`。
- 依赖通过 Inspector、构造/初始化方法或小型服务注入；不要在热路径使用 `Find`。
- 输入宽容类机制必须记录时间窗，例如 0.08-0.20 秒，而不是写成“手感好一点”。
- 视觉和音频反馈要能降级：低端设备可关粒子密度、屏幕效果和昂贵后处理。

## 输出要求

当本技能被用于 MLGS 命令时，在 trace 的 `skills used` 中写入 `mlgs-unity-mechanics`。设计或实现文档里至少留下：

- 选用的机制模式。
- 关键参数和默认值。
- Unity 组件/资产边界。
- 性能注意点。
- QA 验收步骤。

## 外部资料

本技能来源于本地 `game-mechanics-optimizations` 文档集的归纳。若用户提供该知识库路径，或当前机器可访问同名目录，可以按文件名检索更长说明；否则只使用本技能的 bundled references。

`references/dod-performance.md` 还吸收了 `UnityDodNoEcs`、`BulletHellPerf` 示例工程，以及视频评论区里关于 DOD、cache、对象池、instancing、碰撞、动画和实际落地风险的有效讨论。
