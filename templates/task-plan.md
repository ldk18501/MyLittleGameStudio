# Production 任务计划

## 元数据

- 项目：
- 日期：
- Owner：Producer
- 状态：draft / approved / revise

## Release Scope 任务

Target version: `1.0.0`. Every ID in `production/scope/release-scope.json` must appear in this plan; an uncovered ID is a blocker, not backlog.

| ID | 任务 | Owner | 来源 | 状态 |
|---|---|---|---|---|
| T-001 |  |  |  | not-started |

## Release-scope coverage

| Scope ID | Type | Planned count | Task IDs | Required stage | Coverage status |
|---|---|---:|---|---|---|
|  | feature / content / tutorial / ui-screen / configuration / audio / art / localization / operations / build |  |  |  | missing |

## 建议顺序

1. 

## 成品阶段

| 阶段 | 目标 | 必需证据 | 状态 |
|---|---|---|---|
| Prototype | 验证最高风险 | prototype plan + playtest report | pending |
| Vertical Slice | 一段最终品质完整体验，证明正式美术与生产架构 | quality report + approved scoped art | pending |
| Content Complete | 所有发布范围功能和内容完成，无占位和未接线流程 | quality report + QA + code audit + approved art | pending |
| Alpha | 完整流程稳定，无 blocker | full-flow QA + crash/error smoke | pending |
| Beta | 目标设备回归、图标、本地化、崩溃检查 | Beta report | pending |
| Release Candidate | 锁定候选版本和已知问题 | RC report + release subset evidence | pending |
| Release | 全部 scope verified 后锁定 `1.0.0` | final report + locked build + complete scope evidence | pending |

## Definition of Done

- 功能接入真实场景、UI、数据和错误路径。
- 生产代码符合 `rules/production-code.md`，临时代码有明确移除任务。
- 正式资产在 manifest 中达到目标阶段状态，并有真实 Unity 引用和游戏内证据。
- 必需的编译、测试、smoke、性能和清理路径有证据。
- 失败和偏差进入 blocker、known issue 或 owner 明确接受的风险。

## 依赖

- 

## Prototype Policy

- Policy：recommended / required / skipped-with-risk / not-needed
- 原因：

## Owner Participation

- Level：low / medium / high
- 执行策略：

## 风险

- 
