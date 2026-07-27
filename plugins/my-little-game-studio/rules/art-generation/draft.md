# Art Mode: Draft

Use this mode for concept exploration, visual candidates, and direction tests.

## Context budget

- Read the request, available target/reference images, and only the short art strategy.
- Do not read the formal asset manifest, import recipes, Unity usage, reviews, scene contracts, or QA evidence unless promoting a selected candidate.
- Do not initialize the formal art pipeline solely to create drafts.

## Execution

1. Create one draft session under `design/art/drafts/<session-id>/`.
2. Record a compact `session.json` with the request, reference image paths, a short shared style summary, candidate paths, selected candidate, and timestamp.
3. Generate at most four candidates in the first wave unless the owner explicitly asks for more. Prefer evaluating that wave before spending another image call.
4. Reuse one shared prompt baseline. Each candidate call contains only the reference images and the intended variation.
5. Mark every output as draft. Drafts do not enter `production/assets/asset-manifest.json` and cannot satisfy a product gate.

## Promotion

When a candidate is selected for production, switch to formal mode. Create a formal manifest entry at `planned`, copy or reference the selected source, then follow the formal lifecycle without inventing earlier evidence.

## Completion

Return the candidate contact list, selected/rejected status, actual image count, and estimated next formal step. Art Director review is enough; Technical Artist and QA are not required.
