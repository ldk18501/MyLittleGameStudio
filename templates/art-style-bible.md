# Art Style Bible

## Product target

- Game / milestone：
- Target platform and resolution：
- Camera and typical on-screen size：
- Render pipeline：

## Visual anchors

- Approved visual target IDs and images:
- Non-negotiable target traits:
- Explicitly forbidden prototype/placeholder treatments:
- `visual-target.json.styleLock` completed and approved:

- Shape language：
- Silhouette rules：
- Palette roles and exact color anchors：
- Color temperature / saturation / contrast：
- Lighting/material rules：
- Line/edge treatment：
- Texture/detail density：
- UI treatment (panel fill, title bar, border, highlight, typography)：
- Preserve on every generation/edit：
- Reject as visual drift：

## Asset specifications

| Kind | Master size | In-game size | PPU/DPI | Alpha | Filter | Compression | Notes |
|---|---:|---:|---:|---|---|---|---|
|  |  |  |  |  |  |  |  |

## Generation constraints

- Prompt anchors：
- Negative constraints：
- Consistency references：
- Candidate count and selection rule：
- Source preservation：
- Small-asset batch eligibility (icon / portrait / thumbnail only)：
- Registered-sheet rectangles, matte, gutter, and split report：
- Model canvas size versus local final size：
- Background removal and downsample policy：

## Unity import defaults

- Sprite mode / slicing：
- Pivot / border：
- Mesh / mipmaps：
- Atlas groups：
- Addressables policy：
- Platform overrides：
- Required `production/assets/usage/<asset-id>.json` fields and review owner：

## Approval checklist

### UI effect-image decomposition

- Screen ID, approved target image, and exact reference resolution：
- Every visible button, frame, close control, dropdown, checkbox, progress segment, selection row, icon, separator, and typography region audited：
- Pixel rectangle `[x, y, width, height]`, required states, and stable reuse key recorded：
- Production decision is explicit: generated asset, reused asset, procedural Unity rendering, or runtime typography：
- Generated/reused images have matching `screen-derived` asset-manifest entries：
- Component-specific shape, bevel, border, fill, material, wear, palette roles, prompt core, preserve rules, avoid rules, and text policy recorded：
- Art Director approved the component audit before any linked asset entered `prompt-ready`：

- [ ] Matches approved visual anchors
- [ ] Side-by-side in-game comparison matches linked visual-target IDs
- [ ] Reads at gameplay scale
- [ ] Source and provenance recorded
- [ ] Prompt metadata copies the approved style lock and uses the target image as an input
- [ ] Processed non-destructively
- [ ] Imported and referenced in Unity
- [ ] Unity usage metadata matches tint, material, sizing, anchors, sorting, and states
- [ ] In-game evidence captured
- [ ] Performance and fallback accepted
