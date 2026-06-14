# Command: test

## 目的

为当前任务或项目阶段运行、定义或总结验证。

## 主负责人

QA Lead

## 支持角色

- Gameplay Developer
- Unity Architect
- UI/UX Developer

## 流程

1. 确定目标：
   - current task
   - Unity compile
   - smoke test
   - balance simulation
   - UI walkthrough
   - build preflight
2. 使用 `mlgs-unity-mechanics` 为玩法机制推导正常、边界、失败、反馈和性能检查。
3. 环境支持时运行可用检查。
4. 如果无法运行检查，创建手动验证计划。
5. 记录结果：
   - command/check
   - pass/fail
   - evidence path
   - issues found
   - next fix if needed
6. 记录 trace event，包含 checks run、agents used、skills used 和 evidence。

## 完成条件

- 存在验证结果或测试计划。
