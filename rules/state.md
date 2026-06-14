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
