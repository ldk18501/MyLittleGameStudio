# MLGS Natural Language Menu

MLGS exposes one user-facing entry:

```text
/mlgs
```

After `/mlgs`, the owner should describe the goal in normal Chinese or English. The Producer maps the request to an internal command and coordinates specialist agents.

## Good Starters

```text
/mlgs 我想开始一个新的 Unity 游戏，低参与度
/mlgs 接管 E:\Projects\MyUnityGame
/mlgs 帮我头脑风暴一个休闲割草游戏
/mlgs 看看现在项目状态，告诉我下一步
/mlgs 继续实现下一个任务
/mlgs 修一下这个编译错误
/mlgs 跑一轮验证
/mlgs 打开 dashboard
```

## Internal Commands

These are routing labels, not separate slash commands:

| Intent | Internal command | When |
|---|---|---|
| start | `commands/start.md` | first run, new game, empty project, participation, pointer recovery |
| adopt | `commands/adopt.md` | existing Unity project, docs, prototype, code directory |
| status | `commands/status.md` | current state, staff activity, risks, next useful action |
| help | `commands/help.md` | examples and available natural-language requests |
| brainstorm | `commands/brainstorm.md` | idea, references, pitch, pillars, MVP, concept package |
| plan | `commands/plan.md` | systems, Unity tech plan, task plan, prototype policy |
| prototype | `commands/prototype.md` | validate risky loop, input, camera, UI, physics, rendering, performance |
| implement | `commands/implement.md` | execute approved or inferable Unity/C# task |
| fix | `commands/fix.md` | bug, compile issue, QA failure, regression |
| review | `commands/review.md` | code/design/task/phase/build/workflow review |
| test | `commands/test.md` | compile, smoke, QA, manual verification |
| build | `commands/build.md` | build preflight or build output |
| dashboard | `commands/dashboard.md` | refresh/open staff and project dashboard |
| generate-art | `commands/generate-art.md` | concept art, placeholder art, asset prompts |

## Recommendation Style

Recommend natural-language follow-ups:

```text
/mlgs 继续实现下一个任务
```

Do not recommend hidden sub-skills such as `/mlgs-start` or `/mlgs-plan`.
