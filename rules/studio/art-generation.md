# Studio Policy: Art Generation

## Modes

- `draft`: concept candidates only. Default for ambiguous image requests. No formal manifest, import, usage, comparison, or QA artifacts.
- `batch-plan`: one shared visual baseline plus per-item deltas. Plan grouping and concurrency before generation.
- `formal`: production lifecycle, Unity integration, and fail-closed approval.

Explicit mode wording wins. Unity import, final assets, or complete acceptance imply formal mode; ambiguous concept work falls back to draft.

## Context and cost

- Use one parent task and one bound context for a batch.
- Resolve visual targets, style locks, component audits, and manifests once per unchanged batch.
- Do not load downstream formal stages before they are needed.
- Review only selected candidates. Drafts and rejected outputs do not receive import, usage, comparison, or QA work.
- Use compact model-facing prompt packets. Keep full machine snapshots in project metadata for deterministic validation, not repeated conversational context.
- Default first draft wave is at most four images. Default generation concurrency is at most three.

## Formal invariants

- Approved targets have a structured style lock and a real target image reference.
- Every formal prompt copies the style lock and manifest component exactly, repeats preserve/avoid rules, and passes `tools/test-art-prompt.ps1`.
- Formal lifecycle is `planned -> prompt-ready -> generated -> selected -> processed -> imported -> referenced -> approved`, with exact status history and project-local evidence.
- Small same-style, low-detail, no-text icons/portraits/thumbnails may use a registered sheet of 2–9 items with explicit rectangles. Other assets remain per object.
- Processed sprites pass integrity checks. Imported assets have import recipes and Unity Importer evidence. Referenced assets have usage metadata and real Unity references.
- Approval requires deterministic visual comparison, Game View evidence, and passing Art Director plus QA review.
- Skeletal art and nine-slice rules are loaded only for those asset types.
