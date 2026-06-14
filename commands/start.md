# Command: start

## 目的

初始化、接管或恢复一个游戏项目。

## 主负责人

Producer

## 读取

- `studio/config.md`
- `studio/state.yaml` 作为模板
- 如存在，读取 `studio/current-project.local.yaml`
- `workflow/phases.yaml`

## 写入

- project `.mlgs/state.yaml`
- `studio/current-project.local.yaml`
- 需要项目工作区时写入本地 `projects/[slug]/.mlgs/project.md`
- 需要时创建本地项目目录

对外部接管的 Unity 项目，不要把 Unity 项目文件复制进 MyLittleGameStudio。只创建或更新 `<UnityProject>/.mlgs/state.yaml`，并让 `studio/current-project.local.yaml` 指向它。

生产编辑前，只有配置了 approved write paths 后才写入外部 Unity 项目。

## 流程

1. 检查 `studio/current-project.local.yaml`（如果存在），否则使用 `studio/state.yaml` 作为模板。
2. 如果已有活动项目，且用户没有要求新建，摘要当前项目并推荐 `status`。
3. 否则只收集必要设置：
   - project name
   - workspace mode: internal, external-adopted, or embedded
   - project path
   - 已知 Unity version
   - 用户想覆盖默认值时的 automation level
4. 创建或记录项目工作区：
   - external-adopted: `<UnityProject>/.mlgs/`
   - embedded: `<UnityProject>/.mlgs/`
   - internal: `projects/[slug]/.mlgs/`
5. 优先使用 `tools/init-project-state.ps1` 创建或更新项目 `.mlgs/state.yaml`。
6. 更新 `studio/current-project.local.yaml`，让它指向该状态文件。
7. 推荐 `references`、`concept` 或 `status`。

## 默认值

- 新游戏：internal workspace。
- 现有 Unity 项目：external-adopted。
- 当前 workspace 内现有项目：只有用户明确要求时才用 embedded。
- Planning automation：high。
- Production automation：medium。

## 完成条件

- 活动项目已配置。
- 当前阶段至少为 `idea-alignment`。
- Next action 已记录。
