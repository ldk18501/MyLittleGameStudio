---
name: mlgs
description: "MyLittleGameStudio 单入口路由；通过 /mlgs 加自然语言推进 Unity/C# 游戏工作。"
---

# MLGS

插件根目录位于本 skill 上两级，安装目录只读。用户只需要 `/mlgs` 加自然语言，不推荐内部子命令或隐藏 skill。

## Compact 路由

先从下列意图选择一个 command：

- `start/adopt/status/help`：开始、接管、状态、帮助
- `brainstorm/plan/prototype`：创意、规划、原型
- `implement/fix/review/test`：实现、修复、审查、测试
- `build/dashboard`：构建或看板
- `generate-art/productize/release`：美术、成品化、发布

然后运行一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/get-route-packet.ps1 -Root <plugin-root> -Command <command> [-Mode <mode>] [-Stage <stage>] [-ProjectRoot <path> | -ContextPath <path>]
```

默认只使用返回的 compact packet。不要预读完整 `workflow/catalog.json`、`studio/config.md`、`rules/state.md`、command 或 agent 文件。

- 只读取 packet 的 `policies` 和当前实际成立的 `conditionalPolicies`。
- `conditionalFiles`、`onDemandModeFiles` 和 `detailFile` 仅在当前任务确实需要其细节时读取。
- Agent 默认作为 trace 中的角色 ID；只有专项判断无法由 packet/policy 完成时才读取完整 agent 文件。
- phase/gate 目录仅在阶段或门禁评估时读取。
- start、adopt、status 或指针恢复才按需读取 onboarding。

## 项目与写入安全

已知项目路径时只绑定一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/new-project-context.ps1 -ProjectRoot <path>
```

整个任务固定使用返回的 `contextPath`、`projectId`、`projectRoot`、`runtimeRoot` 和 `invocationId`。项目 canonical state 为 `<ProjectRoot>/.mlgs/state.json`。正常路由不读取或比较全局/legacy 指针；仅在显式兼容恢复时使用 `-AllowUserPointer` 或 `-AllowLegacyPointer`，且指针不能授权写入。

`implement`、`fix`、正式美术接入和 `productize` 写入必须：

1. 为计划路径申请非重叠 lease。
2. 使用同一 context 运行 `preflight-task.ps1 -View model`。
3. 只修改批准且被 lease 覆盖的路径。
4. 使用同一 context 运行 `validate-changes.ps1 -View model`。
5. 记录 terminal trace 后释放 lease。

优先用 `tools/start-route.ps1` 合并 context/lease/preflight，用 `tools/finish-route.ps1` 合并 validate/trace/dashboard/lease release；任一步失败时仍按上述顺序 fail-closed。

生产未解锁时停止；`-AcceptRisk` 只接受 owner 已明确记录的风险，不能绕过代码上下文、架构或门禁。

## 美术与构建

- `generate-art` 模式为 `draft`、`batch-plan`、`formal`；不明确时默认 `draft`。
- formal 只加载当前生命周期阶段，保持 fail-closed。
- 普通开发至 Beta 使用 compile/editor/PlayMode/data/platform-preflight。
- 后续开发包体需要 owner 当前消息明确请求；自动打包仅在 Release Candidate/Release 恢复。

## Trace

每个路由任务记录 command、角色、skill、读写文件、假设、决策和验证，并刷新绑定项目的 dashboard。完整机器快照保存在项目/runtime；对话中只返回 compact verdict、blocker 和下一步。
