# Command: generate-art

## Purpose

Run the formal art-asset pipeline from requirement and generation through Unity import, slicing, references, and in-game approval. Concept or placeholder art is allowed only when explicitly marked as such.

## Lead

Art Director

## Supporting Agents

- Technical Artist for production, processing, import, references, and performance
- Creative Director for style approval
- UI/UX Developer for layout, readability, and nine-slice requirements
- Unity Architect for import, atlas, Addressables, and reference strategy
- QA Lead for in-game evidence and placeholder checks

## Required artifacts

- `design/art/style-bible.md`
- `design/art/visual-target.json` and its approved target images
- `production/assets/asset-manifest.json`
- `production/assets/prompts/`
- `production/assets/import-recipes/`
- `production/assets/reviews/`

Initialize missing artifacts with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/init-art-pipeline.ps1 -ProjectRoot <UnityProject>
```

## Asset lifecycle

Every required asset follows this lifecycle in the manifest:

```text
planned -> prompt-ready -> generated -> selected -> processed -> imported -> referenced -> approved
```

Do not skip directly to `approved`. Each transition must preserve source/provenance, output path, import recipe, references, and evidence.

## Flow

1. Read the approved concept, reference analysis, visual target images, style bible, release-scope art items, target platform, render pipeline, and manifest.
2. Expand every release-scope art item into individual manifest entries before bulk generation. Each entry records one or more approved `visualTargets`; an asset without a visual-target link is not formal art.
3. For generated art, use the `imagegen` skill/tool when available. Generate candidates against the style bible; keep prompt metadata beside the asset and preserve the original source image.
4. Select a candidate against silhouette, palette, readability, camera scale, animation needs, and consistency. Do not approve directly from the generation preview.
5. Process non-destructively: crop, remove background, preserve alpha, trim padding, resize, or create variants. Keep source and processed files separate.
6. Write an import recipe before Unity import. Include texture type, Sprite mode, pixels per unit, pivot, border, mesh type, filter/wrap mode, compression, max size, platform overrides, slicing grid or rectangles, atlas, and Addressables decision.
7. Before writing into Unity production paths, run `tools/preflight-task.ps1 -Command generate-art`. Apply import and slicing with available Unity automation (`unity-importer`, `unity-asset`, `unity-script`, or an approved project-local Editor tool). Do not edit `.meta` files by hand.
8. Wire references through serialized fields, Prefabs, ScriptableObjects, UI documents, or Addressables. Avoid runtime string paths and `Resources.Load` as an unreviewed shortcut.
9. Capture in-game evidence at target resolution, including a side-by-side or annotated comparison against the linked visual target. QA verifies composition, palette, value structure, materials, detail density, UI treatment, missing references, sprite borders/pivots, animation frames, atlas coverage, readability, memory, and fallback behavior.
10. Run `tools/validate-changes.ps1` for changed Unity paths. Mark the asset `approved` only after in-game review and validation:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate-art-manifest.ps1 -ProjectRoot <UnityProject> -RequiredFor <stage> -MinimumStatus approved -DisallowPlaceholders
   ```

11. Record files changed, manifest transitions, validation evidence, and trace.

## Rules

- Ask before paid or unclear-cost generation, visual-direction changes, packages, render-pipeline settings, or broad Prefab/scene rewiring.
- Never store API keys in shared files.
- Never overwrite source art unless the owner explicitly requests it.
- A generated image is not a game asset until it is processed, imported, referenced, and approved in-game.
- A technically valid asset that visibly diverges from its approved target remains unapproved.
- Vertical Slice and later gates reject placeholders in their required asset scope.

## Completion

The requested assets have validated manifest entries and in-game evidence, or the exact blocked lifecycle step is reported.
## Fail-closed review contract

- Create one `production/assets/reviews/<asset-id>.json` per formal asset and link it through `reviewPath`.
- Compare approved target images, candidate source, processed asset, Unity references, and real in-game screenshots.
- Run `tools/test-art-review.ps1`; then run `tools/validate-art-manifest.ps1`.
- Automated comparison unavailable/error, Art Director or QA non-pass, missing evidence, target-match below 80, dimension scores below 70, or remaining blockers all prevent `approved`.
- Rework is limited by `maxAttempts`. Exhaustion becomes `blocked`; never convert it to approval.
## Capability routing

1. Refresh discovery with `tools/get-production-capabilities.ps1`.
2. Map each manifest asset to its required production, processing, Unity import/validation, and comparison capabilities.
3. Run `tools/test-production-capabilities.ps1` for the target stage before generation. A provider is not considered ready until cost/credentials are understood and project-relative evidence exists.
4. Route raster/Sprite, mesh/model, animation, audio/voice/music, and video/cinematic assets through their declared providers. Never substitute a flat-color Unity placeholder because a capability is missing.
5. If a required capability is `manual`, `missing`, or `blocked`, record the blocker and stop that asset lifecycle before generation or approval.
