# 命令：generate-art

## 目标

把正式美术从需求、生成、选择、处理、完整性门禁、Unity 导入、引用推进到游戏内验收。概念图与占位图必须明确标记，不能冒充正式资源。

## 主责角色

Art Director。

## 协作角色

- Technical Artist：生产、无损处理、完整性检查、导入、引用与性能。
- Creative Director：风格方向与视觉目标。
- UI/UX Developer：界面层级、可读性、状态与九宫格规范。
- Unity Architect：导入、图集、Addressables 与引用策略。
- QA Lead：自动门禁、游戏内证据和占位资源排查。

## 必需产物

- `design/art/style-bible.md`
- `design/art/visual-target.json` 及已批准目标图
- `design/art/visual-scene-contract.json`
- `production/assets/asset-manifest.json`
- `production/assets/prompts/`
- `production/assets/import-recipes/`
- `production/assets/reviews/`
- `production/qa/evidence/sprite-integrity.json`
- `production/qa/evidence/visual-comparisons/`

缺失时使用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/init-art-pipeline.ps1 -ProjectRoot <UnityProject>
```

## 生命周期

```text
planned -> prompt-ready -> generated -> selected -> processed -> imported -> referenced -> approved
```

不得跳级。每次推进必须在 `statusHistory` 中记录时间与项目内证据；验证器要求从 `planned` 到当前状态逐级且不缺项。`processed` 之前必须保留真实来源、原图、prompt、处理方式和完整性合同；`imported` 只表示技术导入成功；`approved` 必须有真实 Unity 游戏内证据。

## 正式流程

1. 用 `tools/new-project-context.ps1` 绑定目标项目，再读取视觉目标、风格圣经、场景合同、发布范围、目标平台、渲染管线和资源清单。
2. 先锁定代表性场景的分辨率、相机、锚点、深度层、渲染归属、视觉焦点和最低分数；场景构图未对齐前不进行大批量生产。
3. 把发布范围展开为逐项资源清单。每个资源必须关联已批准的 `visualTargets`、真实 `sourceFile`、使用位置、导入配方和 `integrity` 合同。
4. 先制作小规模代表性试产批次，至少覆盖：单体建筑或道具、角色动画、普通 UI 图标和九宫格面板。试产批次未通过完整性检查与 Unity 预览时，禁止扩大批量。
5. 生成式正式资源默认“一次输出一个语义对象”：主体完整、四周有明确安全边距、无相邻对象、无文字、无网格、无投影污染。使用 `imagegen` 时保留精确 prompt 和原图。
6. 拼版只允许作为候选源。未经注册验证的拼版不得按等宽等高网格直接切分。固定网格裁切仅适用于已证明分隔线、留白、帧尺寸和对象边界稳定的 `registered-sheet`；否则使用逐对象生成、对象感知提取或显式矩形，并逐项检查。
7. 动画帧必须逐帧提取、逐帧校验，再重组为统一画布；禁止把存在不均匀留白或串行污染的整行直接缩放。检查帧数、帧内安全边距、脚底基线、锚点、比例和邻行残片；合同必须声明允许的基线与轮廓尺寸偏差。
8. UI 图标按语义独立制作。九宫格面板必须专门设计稳定四角和可重复边缘，不能把任意插画或按钮截图直接设为 Sliced；图标和面板不能靠无关资源染色冒充。
9. 非破坏处理后运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-sprite-integrity.ps1 -ProjectRoot <UnityProject>
   ```

   空图、边缘接触、安全边距不足、显著异物超限、动画缺帧/串帧、未验证拼版或非法固定网格裁切均失败关闭。把报告路径和 `pass` 结果写回资源的 `integrity`；报告失败不得进入 Unity 正式目录。
10. 导入前写完整 import recipe：Texture Type、Sprite Mode、PPU、Pivot、Border、Mesh Type、Filter/Wrap、压缩、平台覆盖、切片、图集和 Addressables 决策。运行 `tools/test-art-import-recipe.ps1`；导入后写入 Unity Importer 证据，九宫格批准前必须有三种尺寸证据。不得手改 `.meta`。
11. 为计划中的资源、配方、Prefab/场景引用申请项目 lease，运行 `tools/preflight-task.ps1 -Command generate-art -ContextPath <context-path>`，再通过 Unity 自动化或经批准的项目内 Editor 工具导入、切片和登记 Addressables。
12. 通过序列化字段、Prefab、ScriptableObject、UI 文档或 Addressables 接线；不得用未审查的运行时字符串路径或 `Resources.Load` 代替正式引用。
13. 在场景合同规定的 Unity Game View、相机和分辨率下截图。使用 `tools/test-visual-comparison.ps1` 生成逐资源与整屏可复现对比报告；它只提供客观漂移信号，不能替代 Art Director/QA。随后运行 `tools/test-visual-scene-contract.ps1`、`tools/test-art-review.ps1` 和 `tools/validate-art-manifest.ps1`。
14. 运行 `tools/validate-changes.ps1 -ContextPath <context-path>`，记录改动、生命周期变化、自动报告和 Unity 证据；用同一 context/invocation 写 trace 后释放 lease。

## 失败关闭规则

- 一个正式资源对应一个 review 文件；不能用一份技术导入报告替代逐资源审查。
- `test-sprite-integrity`、Unity 导入成功、Sprite 数量和 Addressables 数量只证明结构与技术接入，不证明风格、构图或游戏内效果通过。
- 缺少对比能力、Unity 游戏内截图、目标图、可解析的 `comparisonReport`、自动报告，或任何 verdict 为 unavailable/error/fail/pending，都不能标记 `approved`。
- 目标匹配低于 80、任一维度低于 70、场景合同低于门槛或仍有 blocker，都必须返工。
- 返工受 `maxAttempts` 限制；耗尽后状态为 `blocked`，不能降低门槛放行。
- Vertical Slice 及以后拒绝所需范围内的占位图、串图、缺边、错误九宫格和未经验证的拼版裁切资源。

## 完成条件

请求范围内的资源具有真实来源、通过的 Sprite 完整性报告、正确 Unity 导入与引用、真实游戏内证据和 Art Director/QA 双通过；否则明确报告卡在哪个生命周期阶段。
