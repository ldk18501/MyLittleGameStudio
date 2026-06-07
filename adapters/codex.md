# Codex Adapter Notes

This workflow is immediately usable in Codex by reading `AGENTS.md`.

## Usage

1. Open the workspace that contains `MyLittleGameStudio`.
2. Ask Codex to use `MyLittleGameStudio/AGENTS.md`.
3. Codex should route commands through `workflow/command-router.md`.
4. Codex should keep `studio/state.yaml` as the only root state source.

## Suggested Prompt

```text
Use MyLittleGameStudio as the workflow system. Read MyLittleGameStudio/AGENTS.md first, then route my request through its command router.
```

## Codex Behavior

- Use normal file tools for implementation.
- Ask before package/project setting changes.
- For Unity tasks, inspect the real Unity project before changing code.
- Run available checks when possible.

