# Unity 代码规则

- 优先使用 `[SerializeField] private` 字段，避免 public mutable fields。
- 生产路径避免 `Find`、`FindObjectOfType` 和 `SendMessage`。
- 缓存组件，避免在热路径反复 `GetComponent`。
- 避免在 `Update`、物理回调和紧密循环中分配内存。
- 数量巨大且行为同质的实体，不要默认每个实体一个 `MonoBehaviour.Update`；优先评估 manager/system + arrays 的 DOD 写法。
- 频繁创建销毁的对象先使用对象池；对象池仍不够时，再把热路径实体降级为 runtime data。
- 实际可行时，让玩法规则数据驱动。
- 当内容需要由设计师编辑或生成时，使用 ScriptableObject 承载 content/config。
- UI 代码与核心玩法规则分离。
- 为 production 任务记录 test 或 smoke evidence。
- 使用 instancing 时按 mesh/material/shader/空间块分批，并记录 culling、碰撞、动画和移动端降级策略。
