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
```

Install the plugin from the Codex app plugin page. Only use `codex plugin add my-little-game-studio@my-little-game-studio-local` when `codex plugin --help` confirms that subcommand exists.

Pass the repository root. Do not pass `.agents/plugins` or `marketplace.json`.

## Marketplace Layout

Codex expects:

```text
.agents/plugins/marketplace.json
plugins/my-little-game-studio/
```

Open a new Codex thread after installation so the skill list refreshes.

The published plugin is self-contained: it includes the workflow catalog, commands, agents, tools, schemas, templates, and dashboard shell. Mutable state is never written into the plugin cache.

## Dashboard

Every routed `/mlgs` task should update:

```text
$CODEX_HOME/mlgs/logs/activity.jsonl
$CODEX_HOME/mlgs/runtime.json
$CODEX_HOME/mlgs/dashboard/studio-data.js
```

Open:

```text
$CODEX_HOME/mlgs/dashboard/index.html
```
