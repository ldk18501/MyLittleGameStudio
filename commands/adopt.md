# Command: adopt

## 目的

接管已有 Unity 项目、原型、设计文档或代码库，并把它转成 MLGS 能继续引导的活动项目。`adopt` 负责盘点差距，不负责直接改生产代码。

## 主负责人

Producer

## 支持角色

- Unity Architect：检查 Unity 项目结构、版本、包和生产写入边界。
- Creative Director：检查概念、参考和视觉方向材料。
- Game Designer：检查系统设计、玩法文档和任务拆解。
- QA Lead：检查测试、QA 证据和阶段就绪风险。

## 读取

- `workflow/onboarding.yaml`
- `workflow/phases.yaml`
- `rules/state.md`
- 用户提供的 project path 或 state path
- 目标路径中的 `.mlgs/state.yaml`
- Unity 项目常见文件：
  - `ProjectSettings/ProjectVersion.txt`
  - `Packages/manifest.json`
  - `Assets/`
- 已有产物：
  - `design/`
  - `docs/`
  - `prototype/`
  - `production/`
  - `tests/`
  - `src/`

## 写入

- 用户确认接管后，写入或更新 `<ProjectRoot>/.mlgs/state.yaml`
- `studio/current-project.local.yaml`
- 可选：project `.mlgs/project.md`
- 不自动迁移或重写用户已有设计文档；只记录缺口和下一步

## 流程

1. 解析用户提供的路径。若没有路径，只问一个问题：项目路径或已有材料在哪里？
2. 运行或等价执行 `tools/detect-project-stage.ps1 -ProjectRoot <path>`。
3. 报告：
   - 是否是 Unity 项目
   - 是否已有 `.mlgs/state.yaml`
   - Unity version
   - 设计/参考/概念/系统/原型/production/test 产物是否存在
   - 代码或 Assets 规模
   - 当前最可能阶段
   - 主要缺口
4. 根据结果给一个推荐：
   - 已有 `.mlgs/state.yaml`：用 `tools/repair-pointer.ps1 -StatePath <state>` 指向它，然后运行 `status`
   - Unity 项目无 MLGS 状态：用 `tools/init-project-state.ps1` 初始化为 `external-adopted`
   - 非 Unity 但有文档/原型/代码：创建 internal workspace，并把旧材料作为参考来源
   - 路径为空或无关：回到 `start` 的 A/B/C/D 选择
5. 只问一个确认问题：是否按推荐接管并写入 `.mlgs/state.yaml` / pointer？
6. 用户确认后才写入状态；写入后把 next action 设为最具体的下一步：
   - 缺 references：`references`
   - 缺 concept：`concept`
   - 缺 design-plan：`design-plan`
   - 有计划但未解锁 production：`prototype` 或 `review`
   - production ready：`status` 或 `implement`

## 完成条件

- 用户看到了已有项目的差距盘点和一个推荐动作；或
- 项目已被接管，pointer 指向有效 `.mlgs/state.yaml`，next action 已记录。
