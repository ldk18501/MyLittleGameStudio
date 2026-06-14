# 图像生成适配说明

图像生成是可选能力。

## 密钥策略

- 真实 provider config 保存在项目本地 `studio/image-generation.config.json`。
- 不要把 API keys 放进共享文件。
- `.gitignore` 排除 `image-generation.config.json`、`*.key` 和 `.env`。
- `studio/image-generation.config.example.json` 必须保持无密钥。

## 工作流

1. Technical Artist 根据已批准视觉方向编写 prompt。
2. 用户或本地 adapter 选择 provider。
3. 生成图片保存到已批准的 Unity art 路径。
4. 保存 prompt metadata，但不保存 API keys。

## 默认立场

如果没有 provider config，就创建 art brief 和 prompt，不尝试联网生成。
