# Command: generate-art

## 目的

为活动 Unity 项目生成或规格化占位/概念美术。

## 主负责人

Technical Artist

## 支持角色

- Creative Director
- Unity Architect

## 流程

1. 读取视觉方向和资产需求（如果存在）。
2. 起草 prompt 和目标用途。
3. 只有在 provider config 可用且用户明确请求生成时，才使用配置好的图像生成。
4. 把输出保存到已批准的 Unity art 路径。
5. 保存不含密钥的 prompt metadata。

## 安全

- 不要把 API keys 存入共享工作流文件或 prompt metadata。
- 如果 provider 成本不清楚，付费/联网生成前先询问。
