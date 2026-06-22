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

必须包含：

- `start`：guided onboarding，读取 `workflow/onboarding.yaml`。
- `adopt`：existing project adoption，允许读取项目结构并调用只读探测脚本。
- `status`：state report + next question。

建议 allowed tools：

- Guided commands：`Read, Glob, Grep, Bash, AskUserQuestion, Write`
- Planning commands：`Read, Glob, Grep, Write, Edit`
- Production commands：`Read, Glob, Grep, Write, Edit, Bash`
- Art generation：只有存在已配置的本地生成脚本时才添加 `Bash`

## Hooks 建议

不要照搬大型模板的 heavy hooks，但建议保留轻量引导 hook：

- session start status reminder：运行 `tools/resolve-state.ps1 -AllowTemplate`，若 pointer 断裂提示 `/status` 或 `/start`。
- optional state consistency check：运行 `tools/check-state.ps1`。
- optional gap detection：当用户打开已有项目时运行 `tools/detect-project-stage.ps1`。
- optional Unity compile/test helper：只在生产命令中使用。

## 关键规则

不要重新引入逐文件 “May I write?” 要求。保留 `AGENTS.md` 中的自动化等级策略；但在 onboarding、adoption 和 pointer recovery 阶段，必须先问用户处境或路径选择。
