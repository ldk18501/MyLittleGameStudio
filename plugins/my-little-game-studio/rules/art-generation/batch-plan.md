# Art Mode: Batch Plan

Use this mode for several related assets that share a visual target or production purpose.

## Context budget

- Load the visual target once and create one short shared style baseline.
- Represent each asset as a delta: subject, state, final size, usage, and exceptions.
- Keep one parent MLGS task and one project context for the batch. Do not reroute every item as a separate formal task.

## Planning

1. Inventory the requested assets and classify them as draft or formal.
2. Group by visual target, text policy, detail level, generation unit, and final use.
3. Eligible groups of 2–9 low-detail, no-text icons, portraits, or thumbnails may use a registered sheet.
4. Animation frames, nine-slice panels, text UI, fragile outlines, large style differences, or likely cross-cell contact remain one object per generation.
5. For independent generations, schedule at most three concurrent calls. Parallelism reduces wall time, not image usage.

## Registered sheets

Formal registered sheets use `production/assets/batches/<batch-id>.json`, explicit non-overlapping rectangles, matte color, safe margins, final sizes, and `tools/split-art-sheet.ps1`. Never infer a grid from an unregistered AI sheet.

Draft batches may keep their plan under `design/art/drafts/<session-id>/batch-plan.json`. They do not require import, usage, review, or Unity evidence until selected items are promoted.

## Completion

Return the groups, shared baseline, per-item deltas, expected image calls, concurrency, registered-sheet eligibility, and any items forced to individual generation.
