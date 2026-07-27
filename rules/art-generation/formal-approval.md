# Formal Art: Unity Reference And Approval

This stage covers `referenced` and `approved`.

## Reference

1. Link the asset to real Unity objects and components recorded in its usage metadata.
2. Verify size, PPU, pivot, border, material, tint/color preservation, sorting, states, and Addressables policy where applicable.
3. Record real scene or prefab references before advancing to `referenced`.

## Approval

1. Capture deterministic Game View evidence with the configured scene, camera, and resolution.
2. Run `tools/test-visual-comparison.ps1` for asset and relevant whole-scene comparison.
3. Write the asset review with automated, Art Director, and QA verdicts.
4. Validate the manifest at the required lifecycle status.
5. Skeletal characters must pass the animation contract at `approved`.

Missing target images, comparison reports, Unity screenshots, semantic review, or any unavailable/error/fail/pending verdict blocks approval. Rework is bounded by `maxAttempts`; exhaustion sets the asset to blocked rather than lowering the threshold.
