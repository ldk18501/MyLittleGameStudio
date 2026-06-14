# Command: build

## 目的

准备或产出 Unity 构建，尤其是 Android APK 构建。

## 主负责人

Unity Architect

## 支持角色

- QA Lead
- Gameplay Developer

## 流程

1. 解析目标平台。
2. 在可行时检查 Unity 版本、build settings、scenes、packages、Addressables 和 player settings。
3. 执行预检：
   - compile errors
   - required scenes
   - target platform
   - Addressables content
   - development build flag
   - product name/version
4. 修改项目设置、包或构建配置前先询问。
5. 当环境和权限允许时执行构建。
6. 记录构建路径、大小、警告和下一步测试动作。
7. 记录 trace event，包含 platform、preflight result、build output、warnings 和 blockers。

## 完成条件

- 构建成功，或列出 blockers 及其精确修复方案。
