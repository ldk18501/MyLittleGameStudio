# 机制地图

## 使用方式

把用户的“想要某种体验”映射到机制组合。每次只选能服务当前 MVP 的 2-5 个机制，避免把参考库变成愿望清单。

## 性能与工程基础

| 目标 | 首选机制 | Unity 落地 |
|---|---|---|
| 大量子弹、掉落物、特效 | Object Pooling | 统一 Pool、预热、OnRent/OnReturn 生命周期 |
| 大量单位附近查询 | Spatial Hash / Quadtree | 格子索引、Physics.OverlapNonAlloc、分帧刷新 |
| 稳定物理和回放 | Fixed Timestep | FixedUpdate 驱动物理，Update 采输入，状态缓冲 |
| 避免重复计算 | Dirty Flags | 数据变更时置脏，LateUpdate 或系统 tick 合并刷新 |
| 大量同类渲染物 | Batching / Instancing / Atlas | SRP Batcher、GPU Instancing、SpriteAtlas、材质合批 |
| 低端机稳帧 | LOD / Culling / Dynamic Quality | 距离分级、相机外剔除、粒子数量和后处理降级 |

## 输入与移动手感

| 体验目标 | 机制组合 | 常用参数 |
|---|---|---|
| 跳跃更宽容 | Coyote Time + Jump Buffer | 土狼时间 0.08-0.15s；跳跃缓冲 0.08-0.18s |
| 平台边缘不挫败 | Ledge Forgiveness + Ground Probe | 探测半径 0.05-0.20m；前向/上向辅助范围可调 |
| 移动不飘 | Acceleration Curves + Separate Air/Ground Accel | 地面加速度高于空中；减速曲线单独调 |
| 冲刺容易成功 | Dash Input Leniency + Input Buffer | 方向容差 15-30 度；缓冲 0.10-0.20s |
| 镜头不丢目标 | Camera Lead + Sticky Lock-On | 预测距离、跟随平滑、锁定保持时间独立调 |

## 战斗与反馈

| 体验目标 | 机制组合 | 常用参数 |
|---|---|---|
| 命中更有力 | Hit Pause + Camera Trauma + Hit Confirmation | 小命中 0.03-0.06s；重击 0.08-0.12s；震动强度按伤害缩放 |
| 连招更顺 | Attack Combo Buffering + Animation Cancel Windows | 输入缓冲 0.12-0.25s；取消窗口按动画归一化时间配置 |
| 武器有重量 | Anticipation + Follow Through + Recovery | 前摇、命中帧、后摇分别配置，不把动画速度写死 |
| 远程射击可学习 | Recoil Pattern + Procedural Recoil | 后坐力曲线、恢复速度、随机扰动分离 |
| 表面反馈真实 | Footstep Material Detection + Audio Variation | PhysicMaterial/Tag/SurfaceData 映射音效和粒子 |

## Roguelike 与留存

| 目标 | 机制组合 | 设计注意 |
|---|---|---|
| 每局成长强烈 | Exponential Per-Run Power Curves + Visual Escalation | 用上限和软上限防止数值失控 |
| 局外长期目标 | Meta Currency + Multi-Tier Sinks + Milestone Unlocks | 早期奖励密，后期目标长 |
| 构筑有身份 | Build-Around Items + Synergy Discovery + Effect Stacking | 关键物品改变玩法，而不只是加数值 |
| RNG 不挫败 | Pity/Mercy Systems + Curated Pools | 保底规则要服务体验，不要暴露得像补偿漏洞 |
| 重玩有新鲜感 | Daily Challenges + Procedural Pools + Achievements | 固定种子用于竞争，随机池用于探索 |

## 经济与资源

| 目标 | 机制组合 | 设计注意 |
|---|---|---|
| 决策有取舍 | Multiple Currency Types + Resource Conversion | 每种货币要有独立来源和用途 |
| 商店有期待 | RNG Shop + Pity Rules + Rarity Reveals | 控制刷新成本和稀有物出现节奏 |
| 合成有规划 | Crafting + Collection Progress | 明确短期材料和长期稀缺材料 |

## 选型原则

- 先选“玩家会感到什么”，再选机制名。
- 一个系统最多先落地一个主机制、两个辅助机制。
- 每个机制必须有可调参数和验收方法。
- 任何会放大数值的机制都要定义软上限、硬上限或衰减曲线。
