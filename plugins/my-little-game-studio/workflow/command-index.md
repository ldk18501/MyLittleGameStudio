# MLGS Command Index

> Generated from `workflow/catalog.json`. Do not edit by hand.

MLGS publicly exposes only `/mlgs`; the Producer selects one internal route.

| Route | Lead | Supporting | Intent examples |
|---|---|---|---|
| `start` | producer | - | 开始, 新游戏, 空项目, 参与度, 修复指针, 继续当前项目 |
| `help` | producer | - | 帮助, 菜单, 怎么使用, 支持什么 |
| `brainstorm` | creative-director | - | 头脑风暴, 想点子, 玩法主题, 参考, pitch, 概念包 |
| `adopt` | producer | unity-architect, qa-lead | 接管项目, 已有项目, Unity 项目, 项目路径 |
| `status` | producer | - | 状态, 下一步, 卡住, 员工动态 |
| `plan` | game-designer | producer, unity-architect, qa-lead, technical-artist | 规划, 设计方案, 技术方案, 拆系统, 任务计划 |
| `prototype` | gameplay-developer | game-designer, qa-lead | 原型, 验证玩法, 验证风险, 跳过原型 |
| `implement` | gameplay-developer | unity-architect, qa-lead, producer | 实现, 继续开发, 下一个任务, 写代码, 做功能 |
| `fix` | gameplay-developer | qa-lead | 修 bug, 修复, 编译错误, 测试失败, 回归 |
| `review` | qa-lead | producer, unity-architect | 审查, review, 代码审查, 设计评审, 阶段评审, 工作流评审, 成品度评审 |
| `test` | qa-lead | - | 测试, 验证, smoke, QA, 验收, 成品度检查 |
| `build` | unity-architect | qa-lead | 打包, 构建, 构建预检, APK |
| `dashboard` | producer | - | dashboard, 看板, 刷新看板, 员工状态 |
| `generate-art` | technical-artist | creative-director, unity-architect, ui-ux-developer, qa-lead | 生成美术, 正式美术, 概念图, 切图, Sprite, 图集, 美术导入, 资源引用, 资产清单 |
| `productize` | producer | game-designer, unity-architect, gameplay-developer, ui-ux-developer, technical-artist, qa-lead | 成品化, 去 Demo, 垂直切片, vertical slice, 内容完成, content complete, alpha, beta, 打磨 |
| `release` | qa-lead | unity-architect, technical-artist, ui-ux-developer | 发布候选, release candidate, 正式版本, 图标, 本地化, 崩溃检查, 发布验收 |

## Phases

| Phase | Lead | Gate | Routes |
|---|---|---|---|
| intake | producer | project-selected | start, adopt, status, help |
| concept | creative-director | concept-approved | brainstorm, generate-art, review, status |
| plan | game-designer | plan-approved | plan, generate-art, review, test, status |
| prototype | gameplay-developer | prototype-passed-or-skipped | prototype, test, review, status |
| vertical-slice | producer | vertical-slice-approved | productize, implement, generate-art, fix, review, test, build, status |
| production | unity-architect | content-complete-approved | productize, implement, generate-art, fix, review, test, build, status |
| alpha | qa-lead | alpha-approved | productize, implement, generate-art, fix, review, test, build, status |
| beta | qa-lead | beta-approved | productize, release, fix, review, test, build, status |
| release-candidate | qa-lead | release-candidate-approved | release, fix, review, test, build, status |
| release | qa-lead | release-approved | release, fix, review, test, build, status |
