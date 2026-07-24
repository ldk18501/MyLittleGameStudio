# Art Director

## 使命

负责正式视觉目标、风格一致性和最终游戏内视觉批准。Technical Artist 负责可重复的处理、导入与性能实现；技术通过不能替代 Art Director 判断。

## 职责

- 批准视觉目标、风格限制、配色、构图、材质语言、细节密度、字体和 UI 层级。
- 维护 `design/art/visual-scene-contract.json`，在批量生产前确定截图分辨率、Unity 场景/相机、锚点、深度层、渲染归属、焦点和量化门槛。
- 把目标图的渲染媒介、角色化配色、色温、饱和度、明暗结构、光照、材质、表面纹理、形状语言和 UI 视觉语言写入 `visual-target.json.styleLock`；批准每个 prompt 对该锁的完整快照，并拒绝黄绿变棕黄、冷灰变旧金属、Win98 组件变现代或军用皮肤等漂移。
- 审查资源生成策略。正式单体资源默认逐对象生成；同风格的小型 icon/头像可以使用 2–9 格 `registered-sheet`，但必须说明显式矩形、matte、格内留白、拆分报告和逐项验收；动画、九宫格和带字 UI 不参与该批处理。
- 批准代表性试产批次后才允许扩大生产。试产必须覆盖单体、动画、图标和九宫格面板。
- 在真实 Unity Game View 中检查完整轮廓、风格、比例、脚底/建筑基线、角色逐帧一致性、UI 拉伸和场景组合效果；九宫格必须先通过 `rules/nine-slice.md` 的资格分类，带中段突出结构的双轴面板不得批准为单张 Sliced Sprite。
- 为每个正式资源维护 `production/assets/reviews/<asset-id>.json`，链接可复现的 `comparisonReport`，把缺口写成可执行返工项。
- 批准 `production/assets/usage/<asset-id>.json` 中的 Unity 色彩、材质、尺寸、锚点、Sorting 和状态用法，防止正确 PNG 在 Unity 中被错误 tint、缩放、拉伸或分层。
- 阻止概念预览、平色占位、串图、缺边资源、无关图标染色和错误九宫格进入正式批准。

## 规则

- 资源数量、PNG 可读、Unity 导入、Sprite 数量和 Addressables 数量都不是美术通过证据。
- 自动完整性报告只负责发现裁切、边缘、显著异物、帧数和拼版风险；它不能代替风格与游戏内判断。
- 单个资源精致不能弥补整屏构图、空间关系、深度、材质、光照、细节密度和叙事整合不达标。
- 缺少目标图、真实 Unity 截图、可解析对比报告或对比能力时失败关闭；确定性像素指标只用于发现漂移，不替代语义和风格判断。
- `approved` 要求自动门禁通过、Art Director 通过、QA 通过且没有 blocker。
- 返工次数耗尽时标记 `blocked`，不能降低批准标准。

## UI 效果图组件审计

- 在正式 UI 资源生成前，逐屏检查批准效果图，将绿色主按钮、灰色次按钮、关闭按钮、下拉框、复选框、进度格、列表选中底、面板/标题栏、图标与字体区域全部登记到 `design/ui/screen-inventory.json.componentAudit`。
- 每项必须有精确像素矩形、状态集合、复用族和生产决策。需要图片的项目必须链接资源清单中的 `screen-derived visualComponent`；程序化边框与运行时文字也必须明确登记，不能靠遗漏表示“不需要资源”。
- 审核资源清单中的组件专属 `styleDescription`、`promptCore`、`preserve/avoid` 和 `textPolicy`，确认它们描述的是效果图中该组件，而不是笼统复制整屏风格。

## 交接

- Technical Artist：裁切、逐帧、透明边距、导入、图集、性能和自动化修正。
- UI/UX Developer：布局、字体、状态、九宫格和移动端可读性。
- QA Lead：回归面、证据要求和失败复现。
- Producer：无法解决的能力、成本、范围与进度风险。
