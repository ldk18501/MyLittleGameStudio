# Command: generate-art

## Purpose

Run the formal art-asset pipeline from requirement and generation through Unity import, slicing, references, and in-game approval. Concept or placeholder art is allowed only when explicitly marked as such.

## Lead

Technical Artist

## Supporting Agents

- Creative Director for style approval
- UI/UX Developer for layout, readability, and nine-slice requirements
- Unity Architect for import, atlas, Addressables, and reference strategy
- QA Lead for in-game evidence and placeholder checks

## Required artifacts

- `design/art/style-bible.md`
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

1. Read the approved concept, reference analysis, style bible, target platform, render pipeline, and manifest.
2. Add or update one manifest entry per asset. Record `requiredFor`, kind, usage, dimensions, source, license/provenance, output path, and placeholder flag.
3. For generated art, use the `imagegen` skill/tool when available. Generate candidates against the style bible; keep prompt metadata beside the asset and preserve the original source image.
4. Select a candidate against silhouette, palette, readability, camera scale, animation needs, and consistency. Do not approve directly from the generation preview.
5. Process non-destructively: crop, remove background, preserve alpha, trim padding, resize, or create variants. Keep source and processed files separate.
6. Write an import recipe before Unity import. Include texture type, Sprite mode, pixels per unit, pivot, border, mesh type, filter/wrap mode, compression, max size, platform overrides, slicing grid or rectangles, atlas, and Addressables decision.
7. Before writing into Unity production paths, run `tools/preflight-task.ps1 -Command generate-art`. Apply import and slicing with available Unity automation (`unity-importer`, `unity-asset`, `unity-script`, or an approved project-local Editor tool). Do not edit `.meta` files by hand.
8. Wire references through serialized fields, Prefabs, ScriptableObjects, UI documents, or Addressables. Avoid runtime string paths and `Resources.Load` as an unreviewed shortcut.
9. Capture in-game evidence at target resolution. QA verifies missing references, sprite borders/pivots, animation frames, atlas coverage, readability, memory, and fallback behavior.
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
- Vertical Slice and later gates reject placeholders in their required asset scope.

## Completion

The requested assets have validated manifest entries and in-game evidence, or the exact blocked lifecycle step is reported.
