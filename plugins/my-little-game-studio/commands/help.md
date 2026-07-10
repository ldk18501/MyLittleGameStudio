# Command: help

## Purpose

Show the compact MLGS natural-language menu and the most likely next phrase.

## Lead

Producer

## Flow

1. Resolve project state.
   Prefer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate
   ```
2. Read `workflow/command-index.md`.
3. Show the active project, if any.
4. Show a grouped menu of natural-language examples, all beginning with `/mlgs`.
5. Mark startup phrases clearly:
   - `/mlgs 开始一个新的 Unity 游戏`
   - `/mlgs 接管 <path>`
   - `/mlgs 看看当前状态`
   - `/mlgs 帮助`
   Also show production phrases when a project is active:
   - `/mlgs 生成并接入下一批正式美术`
   - `/mlgs 把当前版本推进到 Vertical Slice`
   - `/mlgs 检查 Content Complete 成品度`
   - `/mlgs 检查图标、本地化和崩溃错误`
6. Recommend one next phrase based on state.
   Do not recommend old direct aliases such as `/mlgs-start` unless the user explicitly asks about legacy syntax.
7. Record trace.

## Completion

The owner sees the intent menu and one recommended next step.

