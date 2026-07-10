# Command: dashboard

## Purpose

Refresh and explain the MLGS staff dashboard.

## Lead

Producer

## Read

- resolved runtime `runtime.json`
- resolved runtime `logs/activity.jsonl`
- `dashboard/index.html`
- resolved project state

## Write

- `dashboard/studio-data.js`

## Flow

1. Run `tools/export-dashboard.ps1`.
2. Run `tools/get-project-status.ps1 -AllowTemplate` when available.
3. Report the dashboard file path.
4. Summarize latest staff activity and active project snapshot.
5. Record trace.

## Completion

Dashboard data is refreshed, or the blocker is clear.
