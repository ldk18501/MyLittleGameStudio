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
6. Recommend one next phrase based on state.
   Do not recommend old direct aliases such as `/mlgs-start` unless the user explicitly asks about legacy syntax.
7. Record trace.

## Completion

The owner sees the intent menu and one recommended next step.

