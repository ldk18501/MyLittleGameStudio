# Codex Plugin 快捷入口

本仓库包含一个本地 Codex plugin 源：

```text
<MyLittleGameStudio>/plugins/my-little-game-studio/
```

它定义了一个技能：

```text
mlgs
```

该技能会从同一个 MyLittleGameStudio checkout 自动加载工作流：

```text
<MyLittleGameStudio>/AGENTS.md
```

因此用户不需要反复输入很长的设置句。

## 安装后的使用方式

可以使用短 prompt：

```text
mlgs start
mlgs adopt E:\path\to\UnityProject
mlgs status
mlgs implement the next Unity task
mlgs fix this compile error
mlgs build APK
```

中文 prompt 也可以：

```text
mlgs 开始
mlgs 接管项目 E:\path\to\UnityProject
mlgs 看状态
mlgs 实现下一个功能
mlgs 修复这个问题
mlgs 打包 APK
```

## 引导入口

`mlgs start`、`mlgs adopt` 和 `mlgs status` 是引导入口：

- `start`：询问 A/B/C/D 起点。
- `adopt`：盘点已有 Unity 项目、原型、文档或代码。
- `status`：展示当前状态并给出一个下一问。

插件技能应读取 `workflow/onboarding.yaml`，不要把内部字段当作第一问题。

## Marketplace 文件

仓库本地 marketplace 入口位于：

```text
<MyLittleGameStudio>/.agents/plugins/marketplace.json
```

从仓库根目录安装：

```powershell
cd <MyLittleGameStudio>
codex plugin marketplace add .
codex plugin add my-little-game-studio@my-little-game-studio-local
```

传入 MyLittleGameStudio 仓库根目录。不要传 `.\.agents\plugins` 或 `marketplace.json` 文件本身。

Codex 期望 marketplace root 同时包含：

```text
.agents/plugins/marketplace.json
plugins/my-little-game-studio/
```

安装后新开一个 Codex thread，让 skill list 刷新。

## 关于 Slash Commands

Codex 内置 slash commands 和 plugin skills 不完全是同一种东西。

这个 plugin 提供短 skill trigger（`mlgs`）和 plugin starter prompts。如果 Codex 在 slash UI 中暴露已安装 plugin skills，它应该会显示在那里。如果没有，输入 `mlgs status` 是可靠 fallback。

## 活动 Trace

`mlgs` skill 应把路由后的工作记录到：

```text
studio/logs/activity.jsonl
studio/runtime.json
dashboard/studio-data.js
```

打开 `dashboard/index.html` 可以查看工作室活动视图。
