# Unity 技术方案

## 元数据

- 项目：
- 日期：
- Owner：Unity Architect
- 状态：draft / approved / revise

## 引擎与平台

- Unity version：
- Target platform：
- Render pipeline：
- Input：
- Owner participation：low / medium / high

## 架构摘要

[高层方案。]

## 模块

| 模块 | 目的 | 依赖 | 备注 |
|---|---|---|---|
|  |  |  |  |

## 依赖方向与组合

- Composition root / bootstrap：
- Core/domain：
- Feature modules：
- Unity adapters/presentation：
- UI boundary：
- Editor-only boundary：
- Runtime / Editor / Tests asmdefs：

## 生命周期与错误处理

- Subscription cleanup：
- Cancellation / async ownership：
- Pool reset contract：
- Scene unload behavior：
- Configuration validation：
- Error/logging policy：

## 数据策略

- ScriptableObjects：
- JSON/config：
- Generated assets：
- Save data：
- Save version/migration/failure：
- Localization source and runtime binding：

## Production configuration inventory

| Config ID | Source asset/table | Runtime consumer | Schema/range/reference validation | Failure path | Scope ID |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

- Prototype constants migration/removal plan:

## 场景与 Prefab 策略

- Scenes：
- Prefabs：
- Runtime composition：

## Packages

| Package | 目的 | 状态 | 风险 |
|---|---|---|---|
|  |  | planned / installed / avoid |  |

## 测试策略

- Compile checks：
- Smoke tests：
- Unity Test Runner：
- Manual playtest：

## 实现护栏

- 遵守 `rules/production-code.md`。
- Prototype 之后的临时代码必须带清理任务和移除阶段。
- 功能必须验证真实场景/UI/数据/错误路径接线。

## 风险

- 
