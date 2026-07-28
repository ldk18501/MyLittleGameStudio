# 命令：generate-art

## 目标

以最小必要上下文完成美术探索、批量规划或正式资产生产。不要把概念候选自动升级为正式资产，也不要为每张候选图重复执行完整 MLGS 路由。

## 模式选择

显式模式优先，且只对当前调用生效：

- `模式：草稿`、`草稿模式`、`试稿`、`候选图`、`概念探索` -> `draft`
- `模式：批量规划`、`批量规划模式`、`批量生图`、`统一规划`、`分批生成` -> `batch-plan`
- `模式：正式`、`正式模式`、`生产级`、`最终资源`、`接入 Unity`、`完整验收` -> `formal`

未显式指定时：

1. 提到 Unity 导入、切片、引用、发布资源或完整验收 -> `formal`。
2. 提到一组或多个同风格资源 -> `batch-plan`。
3. 提到概念、尝试、候选或“先看看” -> `draft`。
4. 仍不明确时默认 `draft`，避免误触完整正式流程。

只有 owner 明确要求“后续默认使用某模式”时才记录项目偏好。不要推荐新的 slash 子命令；继续使用 `/mlgs` 加自然语言。

## 按需读取

先读取 `rules/studio/art-generation.md`，然后只读取选中模式：

- `draft` -> `rules/art-generation/draft.md`
- `batch-plan` -> `rules/art-generation/batch-plan.md`
- `formal` -> `rules/art-generation/formal.md`

正式模式再根据当前目标或资产状态只读取一个阶段文件：

- 规划、提示词、生成、选择 -> `rules/art-generation/formal-generation.md`
- 处理、切图、导入 -> `rules/art-generation/formal-processing.md`
- Unity 引用、对比、审查、批准 -> `rules/art-generation/formal-approval.md`

只有请求确实跨越多个阶段时才读取多个阶段文件。骨骼角色和九宫格继续按条件读取专用规则。

## 角色

- 主责：Art Director。
- 草稿：默认不加载其他角色。
- 批量规划：处理或裁切时才加载 Technical Artist。
- 正式生成：按阶段加载 Creative Director、UI/UX Developer、Technical Artist、Unity Architect 或 QA Lead；不要预先加载全部角色。

## 共通执行

1. 项目写入前绑定 project context、申请覆盖计划路径的 lease，并运行 `tools/preflight-task.ps1 -Command generate-art -ContextPath <context-path> -View model`。
2. 同一批图片使用一个父任务、同一个 context 和共享视觉目标摘要；子图片调用只携带参考图、共享 prompt 基线和当前对象差异。
3. 对共享输入进行缓存。视觉目标、style lock、UI component audit 和 manifest 不因切换资产而重复读取，除非文件发生变化。
4. 生成图片的并发只改善等待时间，不视为节省用量。默认并发不超过 3，并遵守图像能力限制。
5. 完成项目写入后使用同一 context 运行 `tools/validate-changes.ps1 -View model`，记录 trace，再释放 lease。

## 输出

报告必须包含模式、生成/规划数量、被跳过的正式步骤、实际执行的阶段、结果路径、验证结果、剩余风险和下一步。正式模式还要报告当前 lifecycle 状态。
