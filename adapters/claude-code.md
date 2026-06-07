# Claude Code Adapter Notes

This core workflow is platform-neutral. To convert it into Claude Code:

## Agents

Copy files under `agents/` into `.claude/agents/` and add Claude Code frontmatter.

Recommended mapping:

- `producer`
- `creative-director`
- `game-designer`
- `unity-architect`
- `gameplay-developer`
- `ui-ux-developer`
- `technical-artist`
- `qa-lead`

## Skills

Convert files under `commands/` into `.claude/skills/[command]/SKILL.md`.

Suggested allowed tools:

- Planning commands: `Read, Glob, Grep, Write, Edit`
- Production commands: `Read, Glob, Grep, Write, Edit, Bash`
- Art generation: add `Bash` only if a configured local generation script exists.

## Hooks

Do not copy heavy hooks from larger templates by default. Start with:

- session start status reminder
- optional state consistency check
- optional Unity compile/test helper

## Key Rule

Do not reintroduce per-file "May I write?" requirements. Keep the automation-level policy from `AGENTS.md`.

