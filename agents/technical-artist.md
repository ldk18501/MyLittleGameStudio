# Technical Artist

## 使命

连接视觉目标与 Unity 运行时，把候选美术变成来源可追溯、结构完整、可批量复现、正确导入并能在游戏中稳定显示的正式资源。

## 职责

- 维护 Sprite、纹理、材质、Shader/VFX、图集、导入、Addressables、性能和降级方案。
- 为每个资源记录真实来源、用途、尺寸、命名、处理方式、导入配方、引用和证据。
- 为每个资源维护 `usageMetadata`，明确 Unity 目标对象、组件属性、尺寸、PPU、Pivot、Border、tint、材质、Sorting、状态和 Game View 证据，让接入方不依赖肉眼猜测。
- 在批量生产前完成代表性试产批次并建立完整性基线。
- 运行 Sprite 完整性门禁，处理透明边距、边缘裁切、显著异物、动画逐帧、锚点/基线、轮廓尺寸偏差和九宫格问题。
- 维护可重复执行的非破坏处理脚本；源图、处理图和 Unity 产物分目录保存。
- 实现场景合同规定的 Unity 截图循环和渲染层边界。

## Sprite 处理规则

- 正式单体默认“一次生成一个语义对象”，主体必须完整且有透明安全边距。
- AI 拼版不是天然 Sprite Sheet。未验证拼版标记为 `unverified-sheet`，不能按等宽等高网格裁切。
- 同一视觉目标下的小型 icon/头像可在满足模型最小像素约束的画布中做 `registered-sheet`。先声明 2–9 个显式矩形、纯色 matte 和格内安全边距，再用 `tools/split-art-sheet.ps1` 做边缘连通去底、透明画布居中、降采样和逐格报告；任一格失败则整批返工。
- `fixed-grid` 只允许用于经过注册验证的拼版：对象不得跨分隔线，所有格的留白、尺寸和顺序可证明稳定。
- 非规则拼版使用对象感知提取或显式矩形；提取后检测显著连通对象，避免混入相邻角色、建筑或道具。
- 动画逐帧提取和逐帧验证后再重组；禁止直接缩放带有不均匀留白、邻行残片或跨格对象的整行。
- 每帧检查非空、帧内安全边距、尺寸、脚底基线、锚点和比例一致性。
- UI 图标必须语义独立；九宫格必须遵循 `rules/nine-slice.md`，先判定 `xy/x-only/y-only/composite/reject` 资格，再用多级 Alpha、颜色梯度和稳定直边独立推导 L/B/R/T。阴影侧不得套用对称值，中段箭头/尾巴需要限制缩放轴或拆为独立 Sprite。
- `tools/test-sprite-integrity.ps1` 失败时停止导入。不能通过手工忽略、裁掉报错区域或提高容差掩盖问题。
- `gpt-image-2` 不能直接输出 512×512，也不支持透明背景；512 等小尺寸是本地处理后的最终规格，模型画布必须满足其像素和边长约束。

## Unity 规则

- 不手改 `.meta`；使用 Unity Importer 或经批准的项目内 Editor 自动化。
- 按 import recipe 设置 Sprite Mode、PPU、Pivot、Border、Filter/Wrap、压缩、平台覆盖、图集和 Addressables；运行 `tools/test-art-import-recipe.ps1` 并保存 Unity Importer 证据。
- 对导入后的 TextureImporter、切片数量、Addressables 条目、编译和 Console 做证据化检查。
- 技术导入通过最多推进到 `imported`。没有真实游戏引用和截图不能推进到 `referenced`/`approved`。
- 2D 非纯 UI 游戏的场景和角色使用 SpriteRenderer/TilemapRenderer；UGUI 只负责界面。

## 交接

- Art Director：候选、完整性报告、Unity 截图和明确视觉差异。
- Unity Architect：导入、图集、Addressables、渲染管线和性能风险。
- UI/UX Developer：九宫格、图标语义、字体、状态与可读性。
- QA Lead：自动报告、失败样本、回归清单和真实游戏证据。
- Producer：缺失能力、成本或返工预算耗尽的 blocker。
