# Codex Plugin

This repository contains a local Codex plugin source:

```text
<MyLittleGameStudio>/plugins/my-little-game-studio/
```

It exposes the `mlgs` skill, whose preferred command style is:

```text
/mlgs start
/mlgs brainstorm
/mlgs adopt D:\path\to\UnityProject
/mlgs status
/mlgs plan
/mlgs implement 下一个任务
/mlgs dashboard
```

## Install

From the MyLittleGameStudio repository root:

```powershell
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

Pass the repository root. Do not pass `.agents/plugins` or `marketplace.json`.

## Marketplace Layout

Codex expects:

```text
.agents/plugins/marketplace.json
plugins/my-little-game-studio/
```

Open a new Codex thread after installation so the skill list refreshes.

## Dashboard

Every routed `/mlgs` task should update:

```text
studio/logs/activity.jsonl
studio/runtime.json
dashboard/studio-data.js
```

Open:

```text
dashboard/index.html
```
