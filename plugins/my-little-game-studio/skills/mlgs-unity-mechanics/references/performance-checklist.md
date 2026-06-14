# 性能清单

## 先定位

- CPU 卡：Profiler 看主线程、脚本、物理、动画、UI。
- GPU 卡：Frame Debugger、RenderDoc 或 Unity Profiler GPU 模块看阴影、后处理、过绘、分辨率。
- 内存卡：Memory Profiler 看贴图、网格、动画、对象数量和托管分配。
- 体感卡顿：看 GC、Shader 编译、资源加载、Instantiate、同步 IO。

## Unity 热路径规则

- 不在 `Update` / `FixedUpdate` / 高频回调中使用 LINQ、反射、字符串拼接、临时集合。
- 不在热路径 `GetComponent`、`Find`、`FindObjectOfType`、`Resources.Load`。
- 对频繁创建销毁的对象使用对象池，池化对象要重置事件订阅、协程、粒子和物理状态。
- 物理查询优先 `OverlapNonAlloc` / `RaycastNonAlloc`，并控制 LayerMask。
- UI 文本、Layout、ContentSizeFitter、ScrollView 内容只在数据变化时刷新。

## 常用预算

| 目标 | 预算 |
|---|---:|
| 60 FPS 总帧时间 | 16.67ms |
| 30 FPS 总帧时间 | 33.33ms |
| 高频玩法系统单项 | 0.1-1.0ms |
| 单帧 GC Alloc | 0B 优先，临时峰值需解释 |
| 移动端 Draw Call | 尽量 <100-200，按项目复杂度调整 |
| 屏幕特效 | 可关闭或降级 |

## 机制对应风险

- 弹幕/掉落物：对象池、空间索引、粒子合批。
- Roguelike 道具叠加：modifier 计算缓存、事件去重、防循环触发。
- 大量敌人：AI 分帧、感知半径、物理 LayerMask、动画 LOD。
- 动态音乐/音效：音源池、同类音效限流、混音组 ducking。
- 相机震动/后处理：强度合并、移动端降级、避免每次命中新建材质。
- 复杂 UI 奖励弹窗：弹窗队列、对象池、批量刷新。

## 优化顺序

1. 复现并记录指标。
2. 找到最大瓶颈，不猜。
3. 先做低风险高收益：对象池、缓存、脏刷新、合批、LayerMask。
4. 再做结构性改动：空间划分、分帧、LOD、数据布局。
5. 最后做平台专项：分辨率、贴图压缩、Shader Variant、Addressables。

## 不要做

- 不要为了“可能会卡”提前引入复杂框架。
- 不要把所有机制都 ECS 化；小项目先保持可读。
- 不要用对象池掩盖生命周期 bug。
- 不要把数值曲线写死在代码里。
- 不要只看平均 FPS；最差 1% 帧和输入延迟更接近玩家感受。
