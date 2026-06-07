# Command Router

Route user requests to command files. Use the closest matching command and keep routing lightweight.

## Before Any Command

Read:

1. `studio/config.md`
2. `rules/state.md`
3. this router
4. the resolved project state, or `studio/state.yaml` as template if no project is configured
5. the selected command file
6. relevant agent files

Resolve:

1. command name
2. lead agent
3. supporting agents
4. external skills used, if any
5. expected files to read or write

If only the root template state exists, route project-specific requests to `start` before production work.

## After Any Command

Record an audit event with `tools/trace.ps1` whenever possible.

The event should include:

- command
- task title
- status
- lead agent
- agents used
- skills used
- files read
- files written
- assumptions
- decisions
- verification

This keeps `studio/logs/activity.jsonl`, `studio/runtime.json`, and `dashboard/studio-data.js` aligned for the dashboard.

## Commands

| Command | File | Use When |
|---|---|---|
| `start` | `commands/start.md` | initialize, adopt, resume, configure project |
| `status` | `commands/status.md` | current state, next action, missing artifacts |
| `references` | `commands/references.md` | collect/analyze reference games, images, avoidances |
| `concept` | `commands/concept.md` | create or revise concept package |
| `design-plan` | `commands/design-plan.md` | system design, Unity technical plan, task plan |
| `prototype` | `commands/prototype.md` | build, skip, revise, or evaluate prototype |
| `implement` | `commands/implement.md` | implement an approved Unity task |
| `fix` | `commands/fix.md` | diagnose and fix bug, playtest issue, compile issue, QA failure |
| `review` | `commands/review.md` | review code, design, task plan, phase readiness |
| `test` | `commands/test.md` | run checks, define QA evidence, smoke test |
| `build` | `commands/build.md` | configure or produce Unity build/APK |
| `generate-art` | `commands/generate-art.md` | generate placeholder or concept art |

## Chinese Trigger Examples

- "开始" -> `start`
- "看状态" -> `status`
- "分析参考" -> `references`
- "生成概念包" -> `concept`
- "做设计方案" -> `design-plan`
- "做原型" -> `prototype`
- "实现这个任务" -> `implement`
- "修这个 bug" -> `fix`
- "审查一下" -> `review`
- "跑测试" -> `test`
- "打包 APK" -> `build`
- "生成美术图" -> `generate-art`

## Ambiguity Rule

If more than one command fits, ask one short question. Do not present a long menu unless the user asks.
