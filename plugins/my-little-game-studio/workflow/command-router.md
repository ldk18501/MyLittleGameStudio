# MLGS 自然语言路由

`workflow/catalog.json` 保存意图数据，`workflow/routes.json` 保存模型执行 packet。两者由工具读取，不作为每次任务的固定对话上下文。

## 流程

1. 从用户意图选择一个 command；美术请求同时选择 mode，formal 再选择当前 stage。
2. 运行 `tools/get-route-packet.ps1 -Command <id> -View model`，已知项目时传入 `-ProjectRoot` 或 `-ContextPath`。
3. 默认只使用 compact packet；只读取 packet 指定且当前成立的 policy。
4. 仅在 packet 不足以处理专项细节时读取 `detailFile`、完整 agent 或 conditional file。
5. 项目写入仍须绑定 context、申请 lease、preflight、validate、terminal trace、释放 lease。
6. phase/gate 目录只在阶段评估时读取；完整状态和审计快照留给工具与 dashboard。

对用户保持 `/mlgs` 加自然语言的单入口，并只给一个清晰下一步。
