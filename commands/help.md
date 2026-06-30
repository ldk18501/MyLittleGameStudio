# Command: help

## Purpose

Show the compact MLGS command menu and the most likely next command.

## Lead

Producer

## Flow

1. Resolve project state.
   Prefer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/get-project-status.ps1 -AllowTemplate
   ```
2. Show the active project, if any.
3. Show the short command menu:
   - `/mlgs start`
   - `/mlgs brainstorm`
   - `/mlgs adopt <path>`
   - `/mlgs status`
   - `/mlgs plan`
   - `/mlgs prototype`
   - `/mlgs implement`
   - `/mlgs fix`
   - `/mlgs review`
   - `/mlgs test`
   - `/mlgs build`
   - `/mlgs dashboard`
4. Recommend one next command based on state.
5. Record trace.

## Completion

The owner sees the command menu and one recommended next step.
