# Formal Art: Processing And Import

This stage covers `selected`, `processed`, and `imported`.

## Processing

1. Preserve the selected source, prompt metadata, target references, and processing recipe.
2. Remove matte locally, crop or split only from declared layouts, center, downsample, and sharpen as required.
3. Run `tools/test-sprite-integrity.ps1` before `processed`. Transparent margin, edge contact, significant foreign objects, frame baseline, and frame-size consistency fail closed.
4. Registered sheets must pass `tools/split-art-sheet.ps1`; one failed cell blocks the sheet.
5. Load `rules/nine-slice.md` only for nine-slice candidates.
6. Skeletal characters must reach `parts-validated` before `processed`.

## Import

Create the import recipe and Unity usage metadata only for processed, selected assets. Acquire a lease for the actual project paths, run generate-art preflight, import through approved Unity automation, and record real Unity Importer evidence.

`imported` means technical import succeeded. It is not visual approval. Skeletal characters must use deterministic assembly and later reach `unity-integrated`.
