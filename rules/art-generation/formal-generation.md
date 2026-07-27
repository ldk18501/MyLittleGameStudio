# Formal Art: Generation

This stage covers `planned`, `prompt-ready`, `generated`, and `selected`.

## Before prompt-ready

1. Bind one project context for the full batch.
2. Confirm the approved visual target, real target image, structured style lock, release-scope mapping, target platform, renderer, and capability manifest.
3. Create one manifest item per semantic asset. UI assets require an approved screen component audit and matching `screen-derived` visual component.
4. Only skeletal, mesh-skin, or hybrid skeletal characters load `rules/character-animation-art.md` and require an animation contract.
5. Create `production/assets/prompts/<asset-id>.json`. Machine metadata still stores exact `styleLockSnapshot` and `manifestComponentSnapshot`; image calls use the compact packet emitted by `tools/get-art-prompt-packet.ps1`.
6. Run `tools/test-art-prompt.ps1`. Free-form “same style” wording is insufficient.

## Image calls

- Default to one semantic object per generation.
- Include the approved target image as an actual reference.
- Repeat preserve/avoid constraints and state exactly what may change.
- Respect current model canvas, aspect ratio, edge, pixel-count, and opaque-background limits. Small game sizes are local post-process outputs.
- Reuse one shared batch baseline; send only per-object differences after it.
- Do not create import recipes, Unity usage, visual comparison, or QA review before an output is selected.

## Selection

Record generation evidence at `generated`. Art Director selection advances only chosen candidates to `selected`; rejected candidates remain generation evidence and do not receive downstream production artifacts.
