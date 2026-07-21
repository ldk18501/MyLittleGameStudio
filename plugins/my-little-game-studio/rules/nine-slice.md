# 九宫格 Sprite 规则

九宫格先判定可拉伸资格，再计算 Border。不要把“有透明边距或圆角”直接等同于可设为 `Sliced`。

## 资格分类

| classification | 含义 | Unity 导入约束 |
|---|---|---|
| `none` | 不是九宫格资源 | Border 全零，不能使用 `sliced` |
| `xy` | 宽高均可改变 | 允许 `Sliced`，必须验证横向、纵向和双轴拉伸 |
| `x-only` | 只允许改变宽度，高度固定 | 允许 `Sliced`，使用方不得改变高度 |
| `y-only` | 只允许改变高度，宽度固定 | 允许 `Sliced`，使用方不得改变宽度 |
| `composite` | 含尾巴、箭头、页签、徽章等应拆分结构 | 不能直接 `Sliced`；拆成九宫主体和独立装饰 Sprite |
| `reject` | 边缘或中心没有稳定可重复区域 | 不能 `Sliced`，返工或改用其他表现方案 |

边缘中段的突出结构若落入某轴的拉伸带，该轴不可拉伸。气泡左侧中段箭头可在高度固定时分类为 `x-only`；需要改变高度时必须分类为 `composite` 并拆图。

## Border 推导

1. 使用多级 Alpha（建议 `32/128/224`）和 RGB/亮度梯度共同寻找边缘；只看低 Alpha 会过早判定圆角结束。
2. 从四边分别寻找连续稳定的直边或可重复纹理。允许 `1-2px` 抗锯齿波动，稳定段至少连续 `4px`。
3. 透明留白、描边、高光、圆角、阴影和其他不可拉伸像素全部留在固定边带内；找到边界后向中心增加 `1-2px` 安全余量。
4. 独立计算 L、B、R、T。存在底部阴影或单侧装饰时禁止为了对称而强行取相同值。
5. 记录原图尺寸和左上坐标系中的安全中心矩形 `[xMin,yMin,xMax,yMax)`。转换到 Unity `spriteBorder`：

   ```text
   L = xMin
   R = width  - xMax
   T = yMin
   B = height - yMax
   border = [L, B, R, T]
   ```

6. 确认 `L + R < width`、`B + T < height`，且中心矩形不包含圆角、阴影、突出结构或不可重复渐变。

## 突出结构

- `fixed-band`：结构完整落在不参与目标轴缩放的固定边带内；只允许声明的轴变化。
- `separate-sprite`：把突出结构拆为子 `Image`，主体单独使用九宫格；这是需要双轴缩放时的默认方案。
- 无法隔离或边缘连续变化时使用 `reject`，不能靠继续放大 Border 掩盖。

## 验证

- `xy`：至少提供 `reference`、`wide`、`tall`、`expanded` 四种 Unity 尺寸证据。
- `x-only`：至少提供 `reference`、`narrow`、`wide`，并证明高度不变。
- `y-only`：至少提供 `reference`、`short`、`tall`，并证明宽度不变。
- 检查四角轮廓、描边/阴影厚度、边缘接缝、中心纹理以及突出结构的位置和比例。任何变形都必须返工，不能仅以 Importer 成功放行。
