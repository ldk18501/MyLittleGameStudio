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
2. Read `workflow/command-index.md`.
3. Show the active project, if any.
4. Show the grouped command menu:
   - `/mlgs-start`
   - `/mlgs-adopt <path>`
   - `/mlgs-status`
   - `/mlgs-help`
   - `/mlgs-brainstorm`
   - `/mlgs-plan`
   - `/mlgs-prototype`
   - `/mlgs-implement`
   - `/mlgs-fix`
   - `/mlgs-review`
   - `/mlgs-test`
   - `/mlgs-build`
   - `/mlgs-dashboard`
5. Mark startup commands clearly: `/mlgs-start`, `/mlgs-adopt <path>`, `/mlgs-status`, `/mlgs-help`.
6. Recommend one next command based on state.
   Use direct commands first; mention `/mlgs ...` only as a compatibility fallback.
7. Record trace.

## Completion

The owner sees the command menu and one recommended next step.

