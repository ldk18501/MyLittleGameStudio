# Codex 适配说明

在 Codex 中读取 `AGENTS.md` 后，本工作流即可使用。

## 使用方式

1. 打开包含 `MyLittleGameStudio` 的 workspace。
2. 让 Codex 使用 `MyLittleGameStudio/AGENTS.md`，或安装本仓库自带的 `mlgs` 插件。
3. Codex 应通过 `workflow/command-router.md` 路由命令。
4. Codex 应通过 `workflow/onboarding.yaml` 处理 `start`、`status`、`adopt` 的用户引导。
5. Codex 应通过 `rules/state.md` 解析项目状态，并只把 `studio/state.yaml` 当模板。

## 建议 Prompt

```text
请使用 MyLittleGameStudio 作为工作流系统。先读取 MyLittleGameStudio/AGENTS.md，再通过它的 command router 路由我的请求。
```

更短的插件入口：

```text
mlgs start
mlgs adopt E:\path\to\UnityProject
mlgs status
```

## Codex 行为

- `start`：先问 A/B/C/D 起点，不要要求用户先懂 project name、workspace mode 等内部字段。
- `adopt`：先盘点已有项目，再确认是否写 `.mlgs/state.yaml` 或修 pointer。
- `status`：报告状态后必须给一个 next question。
- 使用普通文件工具完成实现。
- 修改 package 或 project settings 前先询问。
- Unity 任务先检查真实 Unity 项目，再修改代码。
- 可行时运行检查。

## 建议检查

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-state.ps1
powershell -ExecutionPolicy Bypass -File tools/detect-project-stage.ps1 -ProjectRoot E:/path/to/project
```
