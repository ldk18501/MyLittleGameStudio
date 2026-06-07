# Codex Plugin Shortcut

This repository includes a local Codex plugin source:

```text
<MyLittleGameStudio>/plugins/my-little-game-studio/
```

It defines one skill:

```text
mlgs
```

The skill automatically loads the workflow from the same MyLittleGameStudio checkout:

```text
<MyLittleGameStudio>/AGENTS.md
```

So the user does not need to repeat the long setup phrase.

## How To Use After Installation

Use short prompts such as:

```text
mlgs status
mlgs start
mlgs implement the next Unity task
mlgs fix this compile error
mlgs build APK
```

Chinese prompts also work:

```text
mlgs 看状态
mlgs 实现下一个功能
mlgs 修复这个问题
mlgs 打包 APK
```

## Marketplace File

A repo-local marketplace entry is available at:

```text
<MyLittleGameStudio>/.agents/plugins/marketplace.json
```

Install from the repository root:

```powershell
cd <MyLittleGameStudio>
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

Pass the MyLittleGameStudio repository root. Do not pass `.\.agents\plugins` or the `marketplace.json` file directly.

Codex expects the marketplace root to contain both:

```text
.agents/plugins/marketplace.json
plugins/my-little-game-studio/
```

After installing, start a new Codex thread so the skill list refreshes.

## Note About Slash Commands

Codex built-in slash commands and plugin skills are not exactly the same thing.

This plugin gives you a short skill trigger (`mlgs`) and plugin starter prompts. If Codex exposes installed plugin skills through its slash UI, it should become selectable there. If not, typing `mlgs status` is the reliable fallback.

## Activity Trace

The `mlgs` skill should record routed work in:

```text
studio/logs/activity.jsonl
studio/runtime.json
dashboard/studio-data.js
```

Open `dashboard/index.html` to inspect the office-style activity view.
