# Filter Catalog / 滤镜目录

Harbeth currently exposes 183 public filter or encoder execution types across Compute, MPS, Blit, and Render. `C7Blend` additionally provides 30 blend modes through `C7Blend.BlendType`. This inventory must be updated with source changes; it is a navigation aid, not Harbeth's product definition.

Harbeth 当前在 Compute、MPS、Blit 与 Render 四类执行路径中公开了 183 个滤镜或编码执行类型；`C7Blend` 还通过 `C7Blend.BlendType` 提供 30 种混合模式。该清单必须随源码变动更新；它是导航，不是 Harbeth 的产品定义。

This catalog follows the current source tree and only lists public executable types. Editing primitives such as mask recipes, geometry recipes, transitions, layer composition, analysis, and output contracts belong to the `ImageNode` route and are documented separately in the [public API surface](API_SURFACE_CN.md) and [capability map](CAPABILITY_MAP_CN.md).

本文档以当前源码为准，只统计公开可执行类型。Mask Recipe、Geometry Recipe、Transition、Layer Composite、Analysis 与输出合同等编辑 primitive 归入 `ImageNode` 路线，详见[公开 API 分层](API_SURFACE_CN.md)与[能力地图](CAPABILITY_MAP_CN.md)。

## How to use / 如何使用

Every type in this catalog can participate in Harbeth's two normal entry routes:

```swift
let direct = try HarbethIO(
    element: inputImage,
    filters: [C7Exposure(exposure: 0.2), C7Contrast(contrast: 1.08)]
).output()

let node = ImageNode.image(inputImage)
    .applying(C7Exposure(exposure: 0.2))
    .applying(C7Contrast(contrast: 1.08))
```

- `HarbethIO`：已有输入源和滤镜链时直接处理。
- `ImageNode`：需要结构化编辑、图、多源合成、元数据、诊断或多种输出合同。
- Combination 类型仍是 Harbeth 的公开滤镜，通过 `C7FilterPipelineProtocol` 组合普通滤镜与最终 pass。
- MPS、Blit、Render 和 advanced-kernel 类型可能依赖对应设备 capability；它们不是所有设备上都等价的固定路径。

## Quick selection / 快速选择

| Category | Count | Primary use / 主要用途 |
| --- | ---: | --- |
| Color Adjustment | 34 | 曝光、颜色、曲线、局部直方图、tone mapping、传递函数与色彩空间 |
| Blur Effects | 14 | 模糊、散景、降噪、去色带与局部平滑 |
| Edge & Detail | 17 | 锐化、边缘、轮廓与细节增强 |
| Distortion & Warp | 15 | 像素形变、位移场、折射、镜头畸变与形态学 |
| Stylization | 15 | 故障、卡通、油画、像素与视觉风格化 |
| Blend Modes | 5 types + 30 modes | 双纹理混合、蒙版合成与自定义 blend kernel |
| Combination | 13 | 已公开的多阶段组合滤镜 |
| Utility | 16 | Alpha、亮度、量化、色阶、抠像与高光阴影工具 |
| Matrix Processing | 4 | 颜色矩阵、颜色向量与卷积 |
| Geometric Transform | 7 | 裁剪、缩放、旋转、镜像与仿射变换 |
| Lookup Tables | 5 | 1D/2D/3D LUT、Cube 与分区查找 |
| Other Effects | 9 | 暗角、雾化、淡化、场景布光与镜头边缘校正 |
| Generators | 2 | 纯色与渐变纹理生成 |
| MPS | 8 | Metal Performance Shaders 执行路径 |
| Blit | 3 | 区域复制、裁剪与 mipmap 生成 |
| Render | 16 | Render pass、网格/矢量几何、硬件合成与辅助 attachment |

## Color Adjustment / 颜色调整（34）

用于基础曝光、色调、通道、曲线、色彩空间和 HDR/Log 转换。

- `C7AppleLogDecode`, `C7Brightness`, `C7ChannelControl`, `C7Clarity`, `C7ColorBalanceEnhanced`
- `C7CLAHE`, `C7ColorConvert`, `C7ColorCorrection`, `C7ColorGrading`, `C7ColorRGBA`, `C7ColorSpace`, `C7Contrast`
- `C7Curves`, `C7Exposure`, `C7FalseColor`, `C7Gamma`, `C7HSL`, `C7Hue`
- `C7LuminanceAdaptiveContrast`, `C7Monochrome`, `C7Nostalgic`, `C7Opacity`, `C7Posterize`
- `C7RGBColorSpaceConversion`, `C7RGBTransferConversion`, `C7Saturation`, `C7SelectiveHSL`, `C7Sepia`
- `C7Temperature`, `C7ToneMapping`, `C7Vibrance`, `C7Warmth`, `C7WhiteBalance`, `C7WhitesBlacks`

`C7CLAHE` 使用分块亮度直方图、clip/redistribution、CDF LUT 与相邻 tile 双线性插值增强局部对比度；透明和 HDR/EDR 像素保持原值。

## Blur Effects / 模糊效果（14）

覆盖通用模糊、边缘保护平滑、局部模糊、降噪与渐变去色带。

- `C7BilateralBlur`, `C7CircleBlur`, `C7Deband`, `C7DetailPreservingBlur`, `C7GaussianBlur`, `C7HexagonalBokehBlur`
- `C7LocalBlur`, `C7MeanBlur`, `C7MotionBlur`, `C7NoiseReduction`
- `C7RedMonochromeBlur`, `C7SurfaceBlur`, `C7TiltShift`, `C7ZoomBlur`

## Edge & Detail / 边缘与细节（17）

用于边缘检测、锐化、细节增强、轮廓生成和光学校正后的清晰度恢复。

- `C7Canny`, `C7ComicStrip`, `C7Crosshatch`, `C7DetailEnhancer`, `C7DiffractionCorrection`
- `C7EdgeAwareSharpen`, `C7EdgeGlow`, `C7Granularity`, `C7Sharpen`, `C7SharpenDetail`
- `C7SharpenEnhanced`, `C7SharpnessFalloffCorrection`, `C7Sketch`, `C7Sobel`
- `C7StickerOutline`, `C7ThresholdSketch`, `C7UnsharpMask`

## Distortion & Warp / 扭曲与变形（15）

用于局部几何形变、折射、像素化、形态学以及镜头畸变和色差校正。

- `C7Bulge`, `C7ChromaticAberrationCorrection`, `C7ColorPacking`, `C7DisplacementMap`, `C7GlassSphere`
- `C7Halftone`, `C7LensDistortionCorrection`, `C7Morphology`, `C7Pinch`
- `C7Pixellated`, `C7PolarPixellate`, `C7PolkaDot`, `C7SphereRefraction`
- `C7Swirl`, `C7WaterRipple`

## Stylization / 风格化（15）

用于程序化视觉风格；它们是可组合的 GPU primitive，不承担命名 look、preset 或资源包目录。

- `C7CMYKHalftone`, `C7ColorCGASpace`, `C7Fluctuate`, `C7Glitch`, `C7Kuwahara`, `C7OilPainting`
- `C7OilPaintingEnhanced`, `C7RGBADilation`, `C7ShiftGlitch`, `C7SoulOut`
- `C7Palettize`, `C7SplitScreen`, `C7Storyboard`, `C7Toon`, `C7VoronoiOverlay`

`C7Palettize` 提供最多 32 色的逐像素最近调色板量化；`C7CMYKHalftone` 使用四个独立网角生成减色印刷网点。二者都是通用 GPU primitive，不内置命名风格或 preset。

## Blend Modes / 混合模式（5 + 30）

公开执行类型：

- `C7Blend`：统一混合入口，通过 `BlendType` 选择 kernel。
- `C7BlendChromaKey`：以色度键结果参与双纹理混合。
- `C7ColorBurnEnhancedBlend`：增强型 Color Burn。
- `C7MaskedForegroundBlend`：使用独立 mask texture 合成前景。
- `C7ProgrammableBlend`：通过普通 Compute 合同承载外部 library 与 function constants 自定义混合。

`C7Blend.BlendType` 支持：

- `.add`, `.alpha`, `.colorBurn`, `.colorDodge`, `.darken`, `.darkerColor`
- `.difference`, `.dissolve`, `.divide`, `.exclusion`, `.hardLight`, `.hardMix`
- `.hue`, `.lighten`, `.lighterColor`, `.linearBurn`, `.linearLight`, `.luminosity`
- `.mask`, `.multiply`, `.normal`, `.overlay`, `.pinLight`, `.saturation`
- `.screen`, `.softLight`, `.sourceOver`, `.subtract`, `.vividLight`, `.color`

## Combination / 组合滤镜（13）

Combination 滤镜是 Harbeth 已公开的多阶段能力。它们通过 `C7FilterPipelineProtocol` 组织普通滤镜链和可选最终 pass：

- `C7CombinationBeautiful`：肤色、亮度与柔化方向的组合处理。
- `C7CombinationCinematic`：电影感对比度与色彩关系组合。
- `C7CombinationColorGrading`：围绕色温、色调与层次的分级组合。
- `C7CombinationCreativeAtmosphere`：暖光、冷调与情绪氛围组合。
- `C7CombinationCyberpunk`：偏色、对比和边缘方向的赛博风格组合。
- `C7CombinationDreamy`：柔化、暖调与低饱和方向的梦幻组合。
- `C7CombinationFilmSimulation`：胶片色彩与颗粒方向的组合。
- `C7CombinationHDRBoost`：高光、阴影与局部对比增强组合。
- `C7CombinationModernHDR`：现代 HDR 观感的动态范围组合。
- `C7CombinationVintage`：暖色、颗粒与复古层次组合。
- `C7CombinationVintageFilm`：胶片色调、颗粒、暗角与旧化组合。
- `C7DocumentBinarization`：以局部背景估计处理纸张阴影和不均匀照明的文档黑白二值化。
- `C7HighPassSkinSmoothing`：全图高反差保留平滑，支持安全 tone curve 中点和可选最终细节锐化；不包含人脸或皮肤区域检测。

这些类型属于公开 API，但 Harbeth 的项目定位仍由稳定 GPU 能力和执行合同定义，而不是以滤镜数量作为唯一卖点。

## Utility / 实用工具（16）

用于 Alpha 合同、亮度提取、色阶、高光阴影、抠像与像素格式处理。

- `C7ChromaKey`, `C7DepthLuminance`, `C7ForceOpaqueAlpha`, `C7HighlightShadow`
- `C7HighlightShadowTint`, `C7HighlightShadowTone`, `C7Highlights`, `C7Levels`
- `C7Luminance`, `C7LuminanceRangeReduction`, `C7LuminanceThreshold`, `C7OutputQuantization`, `C7PixelFormatChange`
- `C7PremultiplyAlpha`, `C7Shadows`, `C7UnpremultiplyAlpha`

`C7HighlightShadowTone` 使用 MPS Gaussian 局部亮度参考执行双向高光/阴影调整，并额外提供中间调与对比度控制。

## Matrix Processing / 矩阵处理（4）

- `C7ColorMatrix4x4`
- `C7ColorMatrix4x5`
- `C7ColorVector4`
- `C7ConvolutionMatrix3x3`

## Geometric Transform / 几何变换（7）

用于传统滤镜链中的裁剪、缩放和变换。需要结构化、可重放的编辑描述时，优先使用 `ImageNode` 的 Geometry route。

- `C7Crop`, `C7Flip`, `C7LanczosResize`, `C7Mirror`, `C7Resize`, `C7Rotate`, `C7Transform`

## Lookup Tables / 查找表（5）

- `C7ColorCube`：`.cube` / 3D LUT 处理。
- `C7ColorLookup512x512`：512 × 512 2D lookup layout。
- `C7LookupTable`：通用 2D LUT。
- `C7LookupTable1D`：1D lookup curve。
- `C7MultiZoneLookup`：多区域 lookup 处理。

## Other Effects / 其他效果（9）

- `C7DefringeCorrection`, `C7Fade`, `C7Grayed`, `C7Haze`
- `C7LensVignetteCorrection`, `C7Pow`, `C7SceneRelight`, `C7Vignette`, `C7VignetteBlend`

## Generators / 生成器（2）

- `C7SolidColor`
- `C7ColorGradient`

## Metal Performance Shaders（8）

- `MPSBoxBlur`, `MPSCanny`, `MPSConvolution`, `MPSGaussianBlur`, `MPSHistogram`
- `MPSLanczosResize`, `MPSMedian`, `MPSMorphology`

## Blit Operations / Blit 操作（3）

- `C7CopyRegionBlit`
- `C7CropBlit`
- `C7GenerateMipmapsBlit`

## Render Filters / Render 执行类型（16）

Render 类型用于 render pass、投影/画布几何以及可附加到输出合同的辅助结果。

- `RenderBasicFilter`, `RenderGrayscale`, `RenderSepia`, `RenderTransform3D`
- `RenderCylindricalCanvas`, `RenderProjectiveCanvas`, `RenderQuadTransform`, `RenderQuadRectifyTransform`
- `RenderAuxiliaryFalseColorExposure`, `RenderAuxiliaryHighlightClipping`, `RenderAuxiliaryLuminance`
- `RenderAuxiliaryMaskCoverage`, `RenderAuxiliaryShadowClipping`
- `RenderLayerComposite`, `RenderMeshWarp`, `RenderVectorMask`

## Custom filters / 自定义滤镜

根据执行方式选择最小协议：

- `C7FilterProtocol`：普通 Compute / Render / Blit / MPS 叶子滤镜。
- `C7FilterPipelineProtocol`：由多个普通滤镜组成的公开组合滤镜。
- `C7MetalCommandEncodingProtocol`：仅用于标准原子滤镜和 `C7FilterPipelineProtocol` 无法表达的共享 buffer、mesh/object shader 或特殊命令资源图。
- `FilterDestinationTextureContract`：所有滤镜共用的目标纹理 usage、storage mode 与别名策略合同。
- Custom `.metal` / `.metallib` / external library provider：接入自有 Metal 函数与二进制库。

新增、移除或重命名公开滤镜时，应同步更新本目录；若变化影响公开 API、可观察输出或资源/性能合同，还应写入 `CHANGELOG.md` 的 `Unreleased`。
