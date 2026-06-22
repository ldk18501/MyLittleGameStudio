# Command: start

## 目的

用低认知负担的方式初始化、接管、恢复或重新选择一个游戏项目。`start` 的第一职责不是写状态文件，而是把用户带到正确入口。

## 主负责人

Producer

## 支持角色

- Creative Director：当用户从想法或概念开始。
- Unity Architect：当用户从现有 Unity 项目开始。
- Game Designer：当用户已有玩法概念但缺系统拆解。

## 读取

- `studio/config.md`
- `rules/state.md`
- `workflow/onboarding.yaml`
- `workflow/phases.yaml`
- `studio/state.yaml` 作为模板
- 如存在，读取 `studio/current-project.local.yaml`
- 如用户提供项目路径，读取该路径下的 `.mlgs/state.yaml`、`ProjectSettings/ProjectVersion.txt`、`Assets/`、`design/`、`prototype/`、`production/`、`docs/`

## 写入

- 只有用户选择或确认项目后，才写入 project `.mlgs/state.yaml`
- `studio/current-project.local.yaml`
- 需要内部项目工作区时写入 `projects/[slug]/.mlgs/project.md`
- 需要时创建本地项目目录

对外部接管的 Unity 项目，不要把 Unity 项目文件复制进 MyLittleGameStudio。只创建或更新 `<UnityProject>/.mlgs/state.yaml`，并让 `studio/current-project.local.yaml` 指向它。

生产编辑前，只有配置了 approved write paths 后才写入外部 Unity 项目。

## 引导协议

1. 先静默运行状态解析或等价检查：
   - `tools/resolve-state.ps1 -AllowTemplate`
   - 如用户提供 project path，可运行 `tools/detect-project-stage.ps1 -ProjectRoot <path>`
2. 如果 `studio/current-project.local.yaml` 指向的状态不存在，不要继续普通初始化。先进入恢复分支：
   - 摘要断开的 `state_path` 和 `project_root`
   - 问一个问题：是提供新路径修复指针，还是清除指针重新开始
   - 推荐使用 `tools/repair-pointer.ps1`
3. 如果已有有效活动项目，且用户没有要求新建：
   - 摘要项目名、阶段、next action
   - 推荐 `status`
   - 不重复询问初始化字段
4. 如果没有有效活动项目，按 `workflow/onboarding.yaml` 展示四个起点选项：
   - A) No idea yet
   - B) Vague idea
   - C) Clear concept
   - D) Existing work
5. 用户选择后只问一个下一步问题：
   - A：问“有什么感觉、类型、幻想或约束听起来有趣？”
   - B：问“用几个词描述你的模糊想法。”
   - C：问“一句话 pitch 是什么？”
   - D：问“项目路径是什么，或已有材料在哪里？”
6. 根据回答路由：
   - A/B/C：创建内部工作区或仅记录想法草案，然后推荐 `concept`
   - D 且存在 `.mlgs/state.yaml`：修复指针后推荐 `status`
   - D 且是 Unity 项目但没有 `.mlgs/state.yaml`：推荐或执行 `adopt`
   - D 且只有文档/代码：推荐 `adopt` 做差距盘点
7. 完成本命令时只交付一件事：
   - 已配置项目并写入 next action；或
   - 已提出一个明确下一问；或
   - 已定位恢复动作

## 创建项目状态

当用户确认要配置项目时，优先使用：

```powershell
powershell -ExecutionPolicy Bypass -File tools/init-project-state.ps1
```

需要传入：

- `ProjectRoot`
- `Name`
- `Mode`: `internal`、`external-adopted` 或 `embedded`
- `UnityVersion`（如果可检测）
- `ApprovedWritePaths`（外部 Unity 项目默认只建议 `Assets/`，确认后记录）
- automation 默认值

## 默认值

- 从零开始：先不强迫 Unity 路径；需要文件工作区时使用 internal workspace。
- 现有 Unity 项目：external-adopted。
- 当前 workspace 内现有项目：只有用户明确要求时才用 embedded。
- Planning automation：high。
- Production automation：medium。

## 完成条件

- 用户知道自己属于哪个起点，并知道下一步只需要回答什么；或
- 活动项目已配置，当前阶段至少为 `idea-alignment`，next action 已记录；或
- 断裂状态已被修复或给出单一恢复问题。
