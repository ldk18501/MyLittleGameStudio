# MLGS Natural Language Router

`workflow/catalog.json` is the routing, agent, phase, and gate source of truth. This file only defines the routing procedure.

## Procedure

1. Read `studio/config.md`, `rules/state.md`, and `workflow/catalog.json`.
2. Run `tools/resolve-state.ps1 -AllowTemplate`.
3. Match the request to one catalog command using `commands[].intents`.
4. Read only that command file, its lead agent, and necessary supporting agents.
5. Read `workflow/onboarding.yaml` only for start, adopt, status, or pointer recovery.
6. Before implementation, fixes, formal art integration, or productization writes, bind a project context, acquire a path lease, and run `tools/preflight-task.ps1 -ContextPath <context-path>`; after writes, run `tools/validate-changes.ps1 -ContextPath <context-path>` with that same active lease, then trace and release it.
7. At Vertical Slice or later, evaluate the structured quality report and any configured art manifest gate; file presence is insufficient.
8. Record trace.

Use one clear next question or natural-language `/mlgs ...` follow-up. Do not expose internal field names first, and do not recommend hidden sub-skills.
