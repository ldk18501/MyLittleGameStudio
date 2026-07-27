# Art Mode: Formal

Formal mode produces assets that may enter Unity and satisfy product gates. Its safeguards remain fail-closed, but work and context are loaded by lifecycle stage.

## Lifecycle

```text
planned -> prompt-ready -> generated -> selected -> processed -> imported -> referenced -> approved
```

Every status through the current status appears exactly once in `statusHistory` with project-local evidence. Never skip or backfill a transition without real evidence.

## Stage selection

- Read `formal-generation.md` for `planned` through `selected`.
- Read `formal-processing.md` for `selected` through `imported`.
- Read `formal-approval.md` for `imported` through `approved`.
- Read multiple stage files only when the current request explicitly spans them.

## Required production roots

- `design/art/visual-target.json`
- `production/assets/asset-manifest.json`
- `production/assets/prompts/`
- `production/assets/batches/` when registered sheets are used
- `production/assets/import-recipes/`
- `production/assets/usage/`
- `production/assets/reviews/`
- `production/qa/evidence/`

Initialize missing formal structures with `tools/init-art-pipeline.ps1 -ProjectRoot <UnityProject>`.

## Shared-context rule

Within one batch, resolve the visual target, style lock, component audit, capability manifest, and manifest once. Use `tools/get-art-prompt-packet.ps1` to emit the compact image-call packet instead of copying full machine snapshots into every model-facing request.
