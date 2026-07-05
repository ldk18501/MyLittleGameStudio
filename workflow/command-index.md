# MLGS Command Index

这是 MyLittleGameStudio 的用户指令速查表。用户不需要记住全部命令；优先记住 4 个入口：

- `/mlgs-start`：第一次使用、空项目、新项目、修复指针。
- `/mlgs-adopt <path>`：已有 Unity 项目或已有资料目录。
- `/mlgs-status`：不知道下一步做什么。
- `/mlgs-help`：查看命令菜单。

Codex skill 名称按工具兼容规则使用 hyphen-case，所以采用 `/mlgs-start`，不采用 `/mlgs_start`。`/mlgs <command>` 仍然兼容，例如 `/mlgs brainstorm`，但普通推荐应使用 `/mlgs-brainstorm` 这种前缀命令，避免和其他插件的 `/start`、`/help` 冲突。

## 启动入口

| 指令 | 什么时候用 | 结果 |
|---|---|---|
| `/mlgs-start` | 从零开始、空项目、修复/切换项目指针、设置参与度 | 进入新游戏、接管项目或状态恢复 |
| `/mlgs-adopt <path>` | 已有 Unity 项目、文档、原型、代码目录 | 分析项目阶段并创建/修复 `.mlgs/state.yaml` |
| `/mlgs-status` | 不知道现在在哪、下一步做什么 | 输出当前阶段、缺口、风险和推荐下一步 |
| `/mlgs-help` | 忘记命令或想看菜单 | 显示分组命令和一个推荐动作 |

## 创意与计划

| 指令 | 什么时候用 | 结果 |
|---|---|---|
| `/mlgs-brainstorm` | 想点子、整理参考、生成 pitch/支柱/MVP | `design/concept-package.md` |
| `/mlgs-plan` | 概念已经够清楚，要拆系统和任务 | 系统设计、技术方案、任务计划、原型策略 |
| `/mlgs-generate-art` | 需要概念图、占位图、素材提示词 | 美术提示词或生成资产接入方案 |

## 开发循环

| 指令 | 什么时候用 | 结果 |
|---|---|---|
| `/mlgs-prototype` | 玩法/输入/相机/UI/性能风险还没验证 | 原型计划、原型产物、playtest 报告 |
| `/mlgs-implement` | 执行下一个开发任务或指定任务 | Unity/C# 改动、任务记录、验证证据 |
| `/mlgs-fix` | 编译失败、bug、QA 失败、回归 | 根因、修复、复测结果 |
| `/mlgs-test` | 跑测试、smoke、手动 QA、验收 | 自动或手动验证证据 |
| `/mlgs-build` | 构建预检或打包 | 构建结果、产物路径或 blocker |

## 审查与可视化

| 指令 | 什么时候用 | 结果 |
|---|---|---|
| `/mlgs-review` | 审查代码、设计、任务、阶段、构建或工作流 | Findings、风险、下一步修复建议 |
| `/mlgs-dashboard` | 看员工活动、项目快照、最近 trace | 刷新 `dashboard/studio-data.js` 并提示 dashboard 路径 |

## 记忆法

- 不知道入口：`/mlgs-start`
- 不知道下一步：`/mlgs-status`
- 不知道命令：`/mlgs-help`
- 真正开始做：`/mlgs-implement`

大多数项目只需要按这个顺序走：

```text
/mlgs-adopt <UnityProject>
/mlgs-brainstorm
/mlgs-plan
/mlgs-prototype
/mlgs-implement
/mlgs-test
/mlgs-build
```
