# Codex 适配说明

在 Codex 中读取 `AGENTS.md` 后，本工作流即可使用。

## 使用方式

1. 打开包含 `MyLittleGameStudio` 的 workspace。
2. 让 Codex 使用 `MyLittleGameStudio/AGENTS.md`。
3. Codex 应通过 `workflow/command-router.md` 路由命令。
4. Codex 应通过 `rules/state.md` 解析项目状态，并只把 `studio/state.yaml` 当模板。

## 建议 Prompt

```text
请使用 MyLittleGameStudio 作为工作流系统。先读取 MyLittleGameStudio/AGENTS.md，再通过它的 command router 路由我的请求。
```

## Codex 行为

- 使用普通文件工具完成实现。
- 修改 package 或 project settings 前先询问。
- Unity 任务先检查真实 Unity 项目，再修改代码。
- 可行时运行检查。
