# 状态规则

## 状态文件

`studio/state.yaml` 是新项目模板，不是实时项目状态。

实时状态属于活动游戏项目：

- 外部或嵌入 Unity 项目：`<UnityProject>/.mlgs/state.yaml`
- MLGS 内部项目：`projects/<slug>/.mlgs/state.yaml`

`studio/current-project.local.yaml` 是可选的本地指针，指向活动项目状态：

```yaml
version: 0.1
updated: "2026-06-07T00:00:00+08:00"
state_path: "E:/path/to/YourUnityGame/.mlgs/state.yaml"
project_root: "E:/path/to/YourUnityGame"
```

本地指针必须被 git 忽略。

## 解析顺序

按以下顺序解析项目状态：

1. 用户显式提供的 state path 或 project path。
2. `studio/current-project.local.yaml`。
3. 当前工作目录或最近父目录中的 `.mlgs/state.yaml`。
4. 只作为模板使用的 `studio/state.yaml`。

如果只有模板可用，在进入项目级 production 工作前先路由到 `commands/start.md`。

## 断裂指针恢复

如果 `studio/current-project.local.yaml` 存在，但 `state_path` 或 `project_root` 不存在：

1. 不要继续项目级命令。
2. 报告断裂路径。
3. 只问一个恢复问题：提供新的 project/state path，还是清除当前 pointer 重新开始。
4. 推荐使用 `tools/repair-pointer.ps1` 修复或清除。
5. `status` trace 可记录为 `partial`，因为项目状态尚未恢复。

`tools/check-state.ps1` 在这种情况下应返回可修复警告，而不是把模板状态也视为不可用。

## 接管已有项目

当用户提供已有 Unity 项目、代码、原型或文档路径时：

1. 先运行或等价执行 `tools/detect-project-stage.ps1`。
2. 如果已有 `.mlgs/state.yaml`，优先修复 pointer 后进入 `status`。
3. 如果是 Unity 项目但没有 `.mlgs/state.yaml`，路由到 `commands/adopt.md`。
4. 如果不是 Unity 项目但已有设计/原型/代码，路由到 `commands/adopt.md` 做差距盘点。

## 单一状态规则

对任何一个游戏项目，`.mlgs/state.yaml` 是以下内容的唯一真实来源：

- active project identity
- phase
- approvals
- prototype policy
- risks
- next action
- approved Unity write paths

不要在 MLGS 根目录创建额外的 active-project、stage 或 session state 文件。

允许项目本地日志存在，但不能与已解析的 `.mlgs/state.yaml` 矛盾。

如果文件系统状态与已解析项目状态冲突，先报告冲突，再运行项目级命令。
