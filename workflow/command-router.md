# MLGS Natural Language Router

Routes `/mlgs ...` natural-language requests to the closest Codex-first Unity workflow command. MLGS intentionally exposes only one user-facing slash entry: `/mlgs`.

## Before Any Command

Read:

1. `studio/config.md`
2. `rules/state.md`
3. this router
4. `workflow/onboarding.yaml`
5. resolved project state, or `studio/state.yaml` as template only
6. selected command file
7. relevant agent files

Resolve:

- internal command name
- lead agent
- supporting agents
- external skills
- files expected to be read or written
- whether this is execution, onboarding, recovery, adoption, or review

## Guide Kernel

1. Run or equivalently execute `tools/resolve-state.ps1 -AllowTemplate`.
2. If `needs_repair: true`, route to recovery through `start` or `status`.
3. If only the template exists, route to `start`, unless the current request already provides enough seed/path context to start or adopt directly.
4. If the user provides a project path, run `tools/detect-project-stage.ps1 -ProjectRoot <path>`.
5. If production is requested before `approvals.production_unblocked: true`, route to `status`, `plan`, or `prototype` unless the user explicitly accepts risk.

## User Experience

- `start`, `status`, and `adopt` must produce one clear next question or one clear natural-language `/mlgs ...` follow-up.
- Present A/B/C/D choices when choosing a path or participation level.
- Do not expose internal field names as the first question.
- Do not auto-run a recommended next command unless the user's current request asks for execution.
- Under low participation, ask fewer questions and record assumptions.
- Under high participation, offer more concise options before substantial changes.

## Internal Command Table

| Command | File | Use When |
|---|---|---|
| `start` | `commands/start.md` | Start, recover pointer, choose new/existing project, set participation |
| `help` | `commands/help.md` | Show natural-language examples and current recommendation |
| `brainstorm` | `commands/brainstorm.md` | Explore ideas, references, pitch, pillars, concept package |
| `adopt` | `commands/adopt.md` | Analyze and attach existing Unity/docs/code project |
| `status` | `commands/status.md` | Show project state, staff activity, risks, next options |
| `plan` | `commands/plan.md` | Systems, Unity tech plan, task plan, prototype policy |
| `prototype` | `commands/prototype.md` | Build/evaluate prototype or skip with risk |
| `implement` | `commands/implement.md` | Implement an approved Unity task |
| `fix` | `commands/fix.md` | Diagnose and fix bug, compile issue, QA failure |
| `review` | `commands/review.md` | Review code, design, task, phase, or build readiness |
| `test` | `commands/test.md` | Run or define verification |
| `build` | `commands/build.md` | Unity build or build preflight |
| `dashboard` | `commands/dashboard.md` | Refresh/open dashboard guidance |
| `generate-art` | `commands/generate-art.md` | Generate or specify placeholder/concept art |

## Aliases

- `/mlgs-start` and other old `/mlgs-*` strings are compatibility aliases only; do not recommend them.
- "开始" -> `start`
- "头脑风暴" / "想点子" / "生成概念" -> `brainstorm`
- "接管项目" / "已有项目" -> `adopt`
- "看状态" / "下一步" -> `status`
- "设计方案" / "拆系统" / "技术方案" / `design-plan` -> `plan`
- "做原型" -> `prototype`
- "实现" / "继续开发" -> `implement`
- "修 bug" / "修复" -> `fix`
- "审查" / "review" -> `review`
- "测试" / "验证" -> `test`
- "打包" / "构建 APK" -> `build`
- "看板" / "dashboard" -> `dashboard`
- "生成美术" -> `generate-art`

## Recommended User Phrases

- `/mlgs 开始一个新的 Unity 游戏，低参与度`
- `/mlgs 接管 <UnityProject>`
- `/mlgs 看看当前状态`
- `/mlgs 头脑风暴并创建概念包`
- `/mlgs 规划系统和任务`
- `/mlgs 继续实现下一个任务`
- `/mlgs 修一下这个错误`

## Trace

After any routed command, use `tools/trace.ps1` when possible. Include command, title, status, lead agent, agents used, skills used, files read/written, assumptions, decisions, and verification.


