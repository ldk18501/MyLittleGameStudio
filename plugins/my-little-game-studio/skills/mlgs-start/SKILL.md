---
name: mlgs-start
description: "MLGS 直接指令：启动 MyLittleGameStudio、接管新/已有 Unity 项目、修复项目指针、设置 owner participation。用于用户输入 /mlgs-start、开始、启动、接管项目、继续当前项目，或想让 MLGS 判断下一步从哪里开始。"
---

# MLGS Start

这是 MyLittleGameStudio 的直接入口，对应仓库内 `commands/start.md`。优先响应 `/mlgs-start`，同时兼容 `/mlgs start`。

## 执行

1. 找到 MyLittleGameStudio 根目录：优先使用包含本插件源码的仓库，否则查找含 `AGENTS.md`、`studio/state.yaml`、`workflow/command-router.md` 的目录。
2. 读取根目录 `AGENTS.md` 以及其中要求的 MLGS 必读文件。
3. 运行或等价执行 `tools/resolve-state.ps1 -AllowTemplate`。
4. 读取 `commands/start.md`、`agents/producer.md`，必要时读取 Creative Director、Unity Architect、Game Designer。
5. 先检测再提问。能从用户输入推断项目路径、想法种子或继续意图时，直接推进并记录假设；只在路径/参与度/重大方向确实未知时问一个问题。
6. 所有后续推荐优先使用短指令，例如 `/mlgs-brainstorm`、`/mlgs-adopt <path>`、`/mlgs-status`。`/mlgs ...` 只作为兼容写法。
7. 用 `tools/trace.ps1` 记录本次路由、读取、写入、决策和验证。


