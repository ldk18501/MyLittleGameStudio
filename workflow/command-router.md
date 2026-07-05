# MLGS Command Router

Routes direct MLGS slash commands, `/mlgs ...` compatibility requests, and natural-language requests to the closest Codex-first Unity workflow command.

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

- command name
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

- `start`, `status`, and `adopt` must produce one clear next question or one clear next command.
- Present A/B/C/D choices when choosing a path or participation level.
- Do not expose internal field names as the first question.
- Do not auto-run a recommended next command unless the user's current request asks for execution.
- Under low participation, ask fewer questions and record assumptions.
- Under high participation, offer more concise options before substantial changes.

## Command Table

| Command | File | Use When |
|---|---|---|
| `/mlgs-start` (`/mlgs start`) | `commands/start.md` | Start, recover pointer, choose new/existing project, set participation |
| `/mlgs-help` (`/mlgs help`) | `commands/help.md` | Show compact command menu and current recommendation |
| `/mlgs-brainstorm` (`/mlgs brainstorm`) | `commands/brainstorm.md` | Explore ideas, references, pitch, pillars, concept package |
| `/mlgs-adopt` (`/mlgs adopt`) | `commands/adopt.md` | Analyze and attach existing Unity/docs/code project |
| `/mlgs-status` (`/mlgs status`) | `commands/status.md` | Show project state, staff activity, risks, next options |
| `/mlgs-plan` (`/mlgs plan`) | `commands/plan.md` | Systems, Unity tech plan, task plan, prototype policy |
| `/mlgs-prototype` (`/mlgs prototype`) | `commands/prototype.md` | Build/evaluate prototype or skip with risk |
| `/mlgs-implement` (`/mlgs implement`) | `commands/implement.md` | Implement an approved Unity task |
| `/mlgs-fix` (`/mlgs fix`) | `commands/fix.md` | Diagnose and fix bug, compile issue, QA failure |
| `/mlgs-review` (`/mlgs review`) | `commands/review.md` | Review code, design, task, phase, or build readiness |
| `/mlgs-test` (`/mlgs test`) | `commands/test.md` | Run or define verification |
| `/mlgs-build` (`/mlgs build`) | `commands/build.md` | Unity build or build preflight |
| `/mlgs-dashboard` (`/mlgs dashboard`) | `commands/dashboard.md` | Refresh/open dashboard guidance |
| `/mlgs-generate-art` (`/mlgs generate-art`) | `commands/generate-art.md` | Generate or specify placeholder/concept art |

## Aliases

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

## Trace

After any routed command, use `tools/trace.ps1` when possible. Include command, title, status, lead agent, agents used, skills used, files read/written, assumptions, decisions, and verification.


