# Command: start

## Purpose

Initialize, adopt, or resume a game project.

## Lead

Producer

## Reads

- `studio/config.md`
- `studio/state.yaml` as template
- `studio/current-project.local.yaml` if present
- `workflow/phases.yaml`

## Writes

- project `.mlgs/state.yaml`
- `studio/current-project.local.yaml`
- local project workspace `projects/[slug]/.mlgs/project.md` when a project workspace is needed
- local project directories as needed

For an external adopted Unity project, do not copy Unity project files into MyLittleGameStudio. Create or update `<UnityProject>/.mlgs/state.yaml` and point `studio/current-project.local.yaml` to it.

For production edits, only write to the external Unity project after approved write paths are configured.

## Procedure

1. Inspect `studio/current-project.local.yaml` if present, otherwise use `studio/state.yaml` as a template.
2. If an active project exists and the user did not request a new one, summarize it and recommend `status`.
3. Otherwise collect only essential setup:
   - project name
   - workspace mode: internal, external-adopted, or embedded
   - project path
   - Unity version if known
   - automation level if the user wants to override defaults
4. Create or record the project workspace:
   - external-adopted: `<UnityProject>/.mlgs/`
   - embedded: `<UnityProject>/.mlgs/`
   - internal: `projects/[slug]/.mlgs/`
5. Prefer `tools/init-project-state.ps1` to create or update project `.mlgs/state.yaml`.
6. Update `studio/current-project.local.yaml` to point at that state file.
7. Recommend `references`, `concept`, or `status`.

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
