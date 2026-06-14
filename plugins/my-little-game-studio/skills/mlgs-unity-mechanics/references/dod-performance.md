# Unity DOD / 海量对象性能规范

本规范来源于 `UnityDodNoEcs`、`BulletHellPerf` 示例工程，以及视频 `Unity DOD - Game Objects as Fast as ECS` 评论区中的有效技术讨论。它适用于弹幕、掉落物、草/树/建筑、远景人群、伤害数字、特效碎片、采集点、棋盘格、网格单位等“数量巨大、行为同质、规则清楚”的系统。

## 核心判断

优先问三个问题：

1. 这个对象是否需要完整 GameObject 生命周期、Inspector 组件、Animator、Physics 和独立交互？
2. 它的行为是否大体相同，只是位置、速度、状态、剩余时间、颜色或类型不同？
3. 它的数量是否会达到几百、几千、几万，导致 `Update`、`Transform`、`Instantiate/Destroy` 或 Collider 成为成本？

如果第 2、3 个答案是“是”，优先设计成数据系统，而不是每个实体一个 `MonoBehaviour`。

## 分层策略

| 层级 | 适用情况 | 写法 |
|---|---|---|
| L1：普通 GameObject | 数量少、强交互、开发早期 | 每个对象有组件和 `Update` |
| L2：对象池 | 频繁生成/销毁但仍需组件 | `ObjectPool<T>`，回收时完整重置状态 |
| L3：DOD 系统 | 数量大、行为同质、热路径明确 | 一个 manager/system 管理数组数据并批量更新 |
| L4：Burst/Job/NativeArray | CPU 热点真实存在且可并行 | `NativeArray`/`NativeList` + Burst Jobs |
| L5：GPU/Indirect | 视觉数量极大、交互少 | Instancing、indirect draw、compute/烘焙 |

不要跳级。先用 profiler 证明瓶颈，再提升层级。

## 代码结构规范

- 不要默认写 `Enemy : MonoBehaviour` 管一个敌人；优先考虑 `EnemySystem` 或 `EnemyManager` 管一类敌人。
- 热路径数据放在数组中，例如 `positions[]`、`velocities[]`、`lifetimes[]`、`states[]`，或一个紧凑 `struct[]`。
- GameObject 负责 authoring、少量控制器、发射器、调试视图和可交互代理；海量运行时实体不必都是 GameObject。
- 一个系统集中更新同类实体，避免几千个 `Update`。
- 运行时只更新必要字段，例如只改 `Matrix4x4` 的位置列，而不是重建完整对象图。
- 按 mesh/material/shader/空间块分组，减少 draw call，同时保留 culling 粒度。

## 弹幕推荐结构

```csharp
public struct BulletData
{
    public float Lifetime;
    public Vector3 Velocity;
    public byte Type;
}

public sealed class BulletSystem : MonoBehaviour
{
    [SerializeField] private Mesh _mesh;
    [SerializeField] private Material _material;
    [SerializeField] private int _capacity = 1023;

    private BulletData[] _bullets;
    private Matrix4x4[] _matrices;
    private int _count;
}
```

实现要点：

- 发射器只调用 `BulletSystem.Add(...)`，不要实例化子弹 Prefab。
- `BulletSystem.Update()` 统一扣 lifetime、移动位置、移除过期项。
- 移除元素时用倒序遍历或 write-index compaction，避免 replacement list 漏处理尾部过期元素。
- 若使用 `DrawMeshInstanced`，每批最多 1023；Unity 新版本优先评估 `Graphics.RenderMeshInstanced`。
- 子弹碰撞不要默认每颗一个 Collider；可选方案包括 lifetime、射线/扇形批量检测、空间 hash、近场代理 Collider、预烘焙命中时间曲线。

## Instancing 注意事项

- `DrawMeshInstanced` 适合展示思想，但 Unity 6 文档已建议使用 `Graphics.RenderMeshInstanced`。
- 一批实例会作为整体 bounds 做 culling/sorting，不会逐个实例做视锥或遮挡剔除；大世界必须按空间 chunk 拆 batch。
- 同 mesh/material/shader 才能有效合批；多材质、多 shader 会拆批。
- 需要颜色、类型、随机值等 per-instance 数据时，用 `MaterialPropertyBlock` 或结构化实例数据，不要生成一堆材质实例。
- 透明物体、深度排序、阴影、light probe、动画都会让方案复杂化，先做验证。

## Cache 与数据布局

评论区对 cache 的解释很值得保留：

- CPU 会按 cache line 把连续内存搬进缓存，即使你只读其中一个值。
- 连续数组访问能利用缓存；分散对象引用容易 cache miss。
- OOP 不是不能用，而是“每个对象独立散落 + 虚调用/组件查找/独立 Update”很容易破坏局部性。
- DOD 的目的不是写奇怪代码，而是让 CPU 按顺序处理它马上需要的数据。

实践规则：

- 热路径避免从 `List<GameObject>` 跳到 component，再跳到 transform，再跳到另一个对象。
- 对每帧只读写的小字段，考虑从 authoring 对象中抽到 runtime arrays。
- 大表计算真实变热后，再考虑 `NativeArray`、`NativeList`、Burst 和 Jobs。

## 适用场景

适合：

- 弹幕、投射物、掉落物、金币、伤害数字。
- 草、树、石头、建筑、远景人群等大量同质视觉对象。
- 网格单位、棋子、卡牌池、局内 buff/modifier 列表。
- 大量运行时生成但交互简单的环境物。

谨慎：

- 需要 Animator/SkinnedMeshRenderer 的角色群。
- 每个对象有大量独特行为、复杂 AI、复杂物理交互。
- 强依赖 Unity Editor 场景 authoring 和组件工作流的关卡对象。
- 移动端高 overdraw、高带宽或热量敏感场景。

不适合：

- 数量少、行为复杂的 boss、主角、核心交互物。
- 原型早期还没有证明数量和性能压力的系统。
- 团队没有能力维护自定义 culling、碰撞、调试工具的功能。

## Skinned Mesh / 动画对象

GPU instancing 只复制视觉绘制，不会复制 Animator、组件和骨骼逻辑。大量动画角色需要单独方案：

- 降低活跃 Animator 数量，远处使用动画 LOD。
- 远景用 VAT（Vertex Animation Texture）、GPU skinning 或烘焙动画。
- 只让近处/可交互角色保留完整 GameObject + Animator。
- 把 AI 感知、移动、状态机拆成系统批量更新，视图层只同步必要结果。

## 碰撞与交互

- 可见实例不等于碰撞实例。
- 大量背景对象可无 Collider，只保留少量交互代理。
- 大量投射物优先用数学检测或批量查询，不要每颗子弹都用 Trigger。
- 对静态环境可预烘焙距离、命中时间、空间块、可见性或导航信息。
- 对玩家附近对象可动态提升为 GameObject/Collider，离开范围后降级为数据。

## 风险与反模式

- 不要把 DOD 当成全项目架构宗教；它是性能敏感子系统的工具。
- 不要因为能 instancing，就放弃 Unity 的 authoring 优势。可用 GameObject 做编辑时 authoring，再 bake 成 runtime data。
- 不要只比较 `DrawMeshInstanced` 和 GameObject 实例，这对 GameObject 不公平；要比较完整需求：渲染、碰撞、交互、动画、调试、工具。
- 不要用对象池掩盖生命周期 bug；回收时必须清理事件、协程、粒子、物理速度和状态。
- 不要在没有 culling/chunking 的情况下把整个地图塞进一个 batch。

## 验收清单

- 是否记录了为什么该系统需要 L2/L3/L4 优化？
- 是否列出目标规模，例如 2,000 子弹、50,000 草、1,000 敌人？
- 是否有基线对比：普通 GameObject、对象池、DOD 系统？
- 是否记录 CPU frame time、GPU frame time、GC Alloc、draw calls/batches？
- 是否说明碰撞、交互、动画和调试如何处理？
- 是否给低端设备或移动端降级策略？
- 是否保留 authoring 工作流，或提供 bake/upgrade 工具？
- 是否避免每帧分配、字符串拼接、LINQ、反复 `GetComponent`？

## 可沉淀的项目规范

- 数量少且交互复杂：保留 GameObject。
- 频繁创建销毁：先对象池。
- 数量大且行为同质：用 manager/system + arrays。
- 视觉多、交互少：用 instancing/RenderMeshInstanced。
- CPU 大表计算变热：用 NativeArray/Burst/Jobs。
- 运行时重复查询贵：能预计算就 bake。
