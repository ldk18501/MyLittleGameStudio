---
name: mlgs
description: "MyLittleGameStudio single-entry router for Unity/C# game-studio work through /mlgs plus natural language."
---

# MLGS

Resolve the plugin root two levels above this skill. It must contain `workflow/catalog.json`, `commands/`, `agents/`, `tools/`, and `studio/state.json`. The installed plugin root is read-only.

## Route

1. Read only:
   - `studio/config.md`
   - `rules/state.md`
   - `workflow/catalog.json`
2. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/resolve-state.ps1 -Root <plugin-root> -AllowTemplate
   ```

3. Select one command from `commands[].intents`.
4. Read that command, its lead agent, and only the supporting agents needed for the current stage.
5. Load route-specific policies listed by `studio/config.md`.
6. Read the referenced phase catalog or gate catalog only for phase/gate evaluation. Read `workflow/onboarding.yaml` only for start, adopt, status, or pointer recovery.

Users need only `/mlgs` plus natural language. Do not recommend hidden sub-skills or nested slash commands.

## Project context

When a project path is known, bind it once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <plugin-root>/tools/new-project-context.ps1 -ProjectRoot <path>
```

Keep the returned `contextPath`, `projectId`, `projectRoot`, `runtimeRoot`, and `invocationId` for the whole task. Never switch back to a global pointer during that task.

- Canonical state: `<ProjectRoot>/.mlgs/state.json`.
- Legacy `.mlgs/state.yaml` is readable but migrates only with owner approval.
- User and legacy pointers are read-only navigation fallbacks.
- Same-project writes require a non-overlapping path lease.
- Pass the bound context to preflight, status, trace, dashboard, and validation.

## Write safety

Before `implement`, `fix`, `generate-art`, or `productize` writes:

1. Acquire a lease for the planned project-relative paths.
2. Run `tools/preflight-task.ps1 -ContextPath <context-path>` with the selected command.
3. Perform only approved writes.
4. Run `tools/validate-changes.ps1 -ContextPath <context-path>` before releasing the lease.
5. Record terminal trace, then release the lease.

Production that is not unblocked stops unless the owner explicitly accepts the recorded risk.

## Art routing

Image requests route to `generate-art`, which selects one mode:

- `draft`: candidates and concept exploration; default when ambiguous.
- `batch-plan`: shared style baseline plus per-item deltas and grouping.
- `formal`: production lifecycle, Unity integration, and approval.

Explicit phrases such as `模式：草稿`, `模式：批量规划`, or `模式：正式` win. Read only the chosen mode and formal lifecycle stage. Drafts do not enter the formal manifest until promoted. Formal gates remain fail-closed.

## Production and release

Load the relevant policy under `rules/studio/` rather than carrying every production contract in the router.

- Product depth and research: `content-design.md`
- Production code: `adaptive-code.md` plus `rules/production-code.md` after prototype
- Art: `art-generation.md` and selected `rules/art-generation/` files
- Verification/build cadence: `verification-build.md`
- Product gates: `productization.md` plus referenced gate catalog

Use Unity/C# only. Prototype evidence never substitutes for production visual or architecture evidence.

Ordinary development through Beta uses compile/editor/PlayMode/data/platform-preflight checks. A later development package requires an explicit owner request in the current message; automatic packaging resumes only for Release Candidate or Release.

## Trace

Every routed task records command, lead/support roles, skills, files read/written, assumptions, decisions, and verification. Prefer `tools/trace.ps1`, update the bound runtime dashboard, and never write runtime data into the installed plugin.
