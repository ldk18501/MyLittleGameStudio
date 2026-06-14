# Claude Code 适配说明

核心工作流是平台中立的。转换到 Claude Code 时按以下方式处理。

## Agents 映射

把 `agents/` 下的文件复制到 `.claude/agents/`，并添加 Claude Code frontmatter。

推荐映射：

- `producer`
- `creative-director`
- `game-designer`
- `unity-architect`
- `gameplay-developer`
- `ui-ux-developer`
- `technical-artist`
- `qa-lead`

## Skills 映射

把 `commands/` 下的文件转换到 `.claude/skills/[command]/SKILL.md`。

建议 allowed tools：

- Planning commands：`Read, Glob, Grep, Write, Edit`
- Production commands：`Read, Glob, Grep, Write, Edit, Bash`
- Art generation：只有存在已配置的本地生成脚本时才添加 `Bash`

## Hooks 建议

默认不要从大型模板复制 heavy hooks。可以先从以下轻量 hook 开始：

- session start status reminder
- optional state consistency check
- optional Unity compile/test helper

## 关键规则

不要重新引入逐文件 “May I write?” 要求。保留 `AGENTS.md` 中的自动化等级策略。
