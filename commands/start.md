# Command: start

## Purpose

Initialize, adopt, or resume a game project.

## Lead

Producer

## Reads

- `studio/state.yaml`
- `studio/config.md`
- `workflow/phases.yaml`

## Writes

- `studio/state.yaml`
- project `studio/project.md`
- project directories as needed

## Procedure

1. Inspect `studio/state.yaml`.
2. If an active project exists and the user did not request a new one, summarize it and recommend `status`.
3. Otherwise collect only essential setup:
   - project name
   - workspace mode: internal, external-adopted, or embedded
   - project path
   - Unity version if known
   - automation level if the user wants to override defaults
4. Create or record the project workspace.
5. Update `studio/state.yaml` as the single source of truth.
6. Recommend `references`, `concept`, or `status`.

## Defaults

- New game: internal workspace.
- Existing Unity project: external-adopted.
- Existing current workspace project: embedded only if the user explicitly asks.
- Planning automation: high.
- Production automation: medium.

## Completion

- Active project is configured.
- Current phase is at least `idea-alignment`.
- Next action is recorded.

