# 性能基准与优化指南

Harbeth 的性能优化应以可重复的数据为基础。无论是单个滤镜、组合滤镜、recipe、mask、analysis 还是 attachment 输出，都建议先记录稳定基线，再判断优化收益。

## 基准目标

一条性能基准应回答：

- 输入是什么？
- 输出是什么？
- 滤镜链包含哪些 pass？
- 是否产生中间纹理？
- 是否发生 CPU readback？
- GPU 和 CPU 各自花费多少时间？
- 结果是否保持一致？

## 建议记录的指标

每条 benchmark 建议记录：

- source type：image / texture / pixelBuffer / sampleBuffer
- resolution：720p / 1080p / 4K / 原图尺寸
- output type：image / texture / frame / pixelBuffer
- filter count
- pass count
- intermediate texture count
- CPU encode time
- GPU command buffer time
- total wall time
- peak transient texture bytes
- allocator reuse hit/miss
- heap count / reserved bytes / used bytes / fallback count
- readback/copy count
- diagnostics fingerprint

这些指标可以通过 `HarbethIO` / `ImageNode` 的 diagnostics、debug snapshot 和测试侧计时工具组合记录。性能治理的入口也只围绕这两条路线展开，不额外引入第三条 runtime 用法。

记录这些指标时有两个前提需要固定：

- `HarbethIO` 的 diagnostics / request / render recipe 必须和真实 effective chain 一致，不能只看初始化时传入的原始 filters
- `ImageNode` 的 request / recipe / snapshot 必须保留原始 source contract，不能因为内部先物化成 texture 就把 `sampleBuffer`、YCbCr、HDR 语义抹掉
- 如果基线依赖 `ImageNode` 的 image-resolution cache，要区分 cold cache 与 hot cache，并记录是否发生过 cache namespace bump

仓库当前已经提供一组可直接运行的基线测试：

- `PerformanceBaselineTests/testHarbethIOFilterChainClockBaseline`
- `PerformanceBaselineTests/testImageNodeFilterChainClockBaseline`
- `PerformanceBaselineTests/testImageNodeGeometrySamplerClockBaseline`
- `PerformanceBaselineTests/testImageNodeEditRouteClockBaseline`
- `PerformanceBaselineTests/testImageNodeLayerCompositeRouteClockBaseline`
- `PerformanceBaselineTests/testImageNodeTransitionRouteClockBaseline`
- `PerformanceBaselineTests/testPixelBufferYCbCrBridgeClockBaseline`

建议命令：

```bash
xcrun swift test --filter PerformanceBaselineTests
xcrun swift test --filter RealtimeRouteBenchmarkTests
```

这组 baseline 的定位不是给出固定门槛，而是保证后续每次优化都在同一批真实链路上回看趋势：

- `HarbethIO` 轻量滤镜链
- `ImageNode` 统一链路
- geometry + sampler override
- edit / layer composite / transition advanced routes
- pixelBuffer / YCbCr bridge

`RealtimeRouteBenchmarkTests` 额外记录五条实时交付路线的真实 cold first frame、avg、p95、p99、stable/dropped frames、fallback 与 resident-memory delta。首帧必须保留执行顺序，不能用排序后的最小值代替；输入缓冲应循环复用，不能让 benchmark 自身一次性常驻数百帧并污染内存结果。

## Texture Pool 与真实 MTLHeap

3.0 的 pool 命中必须满足完整 descriptor contract。尺寸容差只允许放宽 width/height，usage、storage、sample、mipmap、texture type、array/depth、CPU cache 和 hazard tracking 必须一致。

默认 `.exact` 适合短任务和少量纹理。重复尺寸的实时帧或长链路可以对比 `.heapBacked`：

```swift
Shared.shared.defaultTextureAllocationStrategy = .heapBacked
defer { Shared.shared.defaultTextureAllocationStrategy = .exact }
```

比较时至少同时记录：

- `TextureAllocatorSnapshot.heapBackedAllocationCount`
- `heapCount`、`heapReservedMemory`、`heapUsedMemory`
- `heapAllocationFallbackCount`
- `textureReuseHitRatio`
- cold first frame 与 steady-state p95/p99

Heap 的 reserved bytes 是预算成本，不能只看 used bytes；少量纹理场景中，直接分配可能更省。发生 memory pressure 时，Harbeth 会先释放池内闲置纹理，再回收已经没有资源的空 Heap，不会强制回收仍被 in-flight/output texture 使用的 Heap。

仓库当前还补了两类执行证据：

- `RenderGraphTests/testExecutionPrewarmReservationsIncreaseTextureReuseForBoundaryChain`
- `RenderGraphTests/testExecutionPrewarmReservationsIncreaseTextureReuseForDoubleBufferChain`
- `ImageNodeRecipeRouteTests/testEditRoutePersistentCachePolicyAddsPersistentBoundaryAndReservation`
- `ImageNodeRecipeRouteTests/testEditRoutePointFiltersExposeMergedStageBenefit`
- `ImageNodeRecipeRouteTests/testLayerCompositeRouteKeepsLayerLocalPreparationOutsideTopLevelMergeMetrics`
- `ImageNodeRecipeRouteTests/testLayerCompositeRoutePersistentCachePolicyAddsPersistentReservationRelativeToTransientNode`
- `ImageNodeRecipeRouteTests/testTransitionRoutePersistentCachePolicyAddsPersistentReservationRelativeToTransientNode`
- `ImageNodeRecipeRouteTests/testTransitionRouteKeepsTransitionBoundaryWhileMergingTrailingPointFilters`
- `ImageNodeRecipeRouteTests/testLayerCompositeRoutePersistentNodeExposesPrewarmReservations`
- `ImageNodeRecipeRouteTests/testTransitionRoutePersistentNodePreservesBoundaryAcrossGraphAndPlan`

这两条不是时钟基线，而是用 texture pool reuse hit 去证明 optimizer 的 prewarm hint 已经进入真实执行，而不只是停留在 diagnostics。

同时，这批 route-level tests 也明确了另一层边界：

- `edit` 与 `transition` 路线可以在顶层 plan 上直接观察到 `mergeCompatibleStages`
- `layerComposite` 的 layer-local filter preparation 当前仍封装在组合语义内部，不会虚假抬高顶层 `mergedStageCount`
- `edit`、`layerComposite`、`transition` 三条高级路线现在都已经有 route-level `covered / partial / metadataOnly` sampler coverage 证据
- 对于等价的普通 filters 链，`HarbethIO` 与 `ImageNode` 现在也有 diagnostics 对齐测试，确保 `mergedStageCount`、`fusionEligibleNodeCount`、`prewarmReservations` 等 optimization metrics 不会漂移

## 基准场景

### 单滤镜

用途：

- 测量单个滤镜的 GPU 成本
- 检查参数变化是否影响 pipeline cache
- 比较 `factors` 和 `kernelParameterBindings` 的编码成本

建议覆盖：

- color adjustment
- blur
- LUT / CUBE
- geometry
- blend
- render primitive
- MPS filter

### 普通滤镜链

用途：

- 观察连续 pass 的成本
- 检查 transient texture reuse
- 发现不必要的 alpha / color conversion

示例：

```swift
let filters: [C7FilterProtocol] = [
    C7Exposure(exposure: 0.1),
    C7Contrast(contrast: 1.08),
    C7Saturation(saturation: 0.95),
    C7Vignette(vignette: 0.2)
]
```

### 组合滤镜

用途：

- 比较普通 filter chain 和组合滤镜的成本
- 观察 sequential / `parallelFromSource` pipeline 的纹理峰值
- 检查 final blend leaf 的额外 pass 成本

建议覆盖：

- `C7CombinationCinematic`
- `C7CombinationFilmSimulation`
- `C7CombinationBeautiful`
- `C7CombinationModernHDR`

### Recipe、Mask 和 Layer

用途：

- 测量局部调整成本
- 测量 mask composite 成本
- 比较 preview 和 export profile
- 识别可缓存或可提前物化的中间结果

建议覆盖：

- `EditRecipe` with local effect
- `MaskCompositeRecipe` add/subtract/intersect
- `LayerCompositeRecipe`

这些场景的推荐执行入口统一是 `ImageNode`。

### Geometry 与 Sampler Contract

用途：

- 比较 render geometry path 与历史 compute geometry path
- 观察 `withSamplerDescriptor(_:)` 在已覆盖路径上的真实成本
- 识别 sampler override 是否引入额外 pass 或只是改变同一 pass 的执行参数

建议覆盖：

- `RenderQuadTransform`
- `RenderQuadRectifyTransform`
- `PerspectiveTransform`
- `GuidedUpright`
- `C7Crop`
- `C7Rotate`
- `C7Transform`
- `C7LensDistortionCorrection`
- `C7ChromaticAberrationCorrection`

当前判断：

- render geometry path 直接受 `MTLSamplerState` 控制
- 历史 compute geometry / optics path 已经补齐到 nearest/linear + clamp/repeat 这类可映射 sampler 语义
- 如果 sampler descriptor 超出当前 compute family 可表达范围，diagnostics 仍会保守标记为 `metadataOnly` 或 `partial`

### Analysis 和 Attachment

用途：

- 区分 GPU histogram、CPU readback 和 attachment analysis 的成本
- 避免实时预览路径误触发 readback
- 为调试和质量检查选择合适 profile

建议覆盖：

- `renderAnalysisBundle(scope:)`
- `renderHistogram(...)`
- `renderAttachmentSet(...)`
- `renderAttachmentAnalysisBundle(...)`

## 优化方向

优先观察：

- pass count 是否可以减少
- 中间纹理是否可以复用
- readback 是否只发生在需要 CPU 数据的路径
- alpha / color contract 是否产生冗余转换
- 组合滤镜是否复用公共 final kernel
- diagnostics 是否足够解释当前执行成本

常见收益点：

- 默认 `HarbethIO + filters` texture path
- 线性滤镜链的 transient texture reuse
- `RenderOptimizationPlan.prewarmReservations` 驱动的同步 texture pool 预热
- `ImageNode` persistent image-resolution cache 的 hot-path 命中
- namespace bump 后旧 resolution 指纹失效带来的冷启动回退成本
- 组合滤镜 sequential pipeline 的中间纹理生命周期
- analysis / attachment 路径的 readback 控制
- graph optimizer 对透明 wrapper 和冗余节点的消除

## Profile 选择

推荐按场景选择 profile：

| 场景 | 推荐 profile |
| --- | --- |
| 滑杆拖动、实时交互 | `.interactiveLatency` |
| 普通预览 | `.stablePreview` |
| 放大检查 | `.inspectionQuality` |
| 最终导出 | `.exportQuality` |
| histogram / analysis / readback | `.readbackQuality` |

## 应用侧基线建议

集成 Harbeth 的应用可以至少建立这些真实链路 benchmark：

1. 轻量 preset：3 到 5 个普通滤镜。
2. 复杂 look：8 到 12 个滤镜，包含 blur / grain / LUT。
3. 组合滤镜：一个 `C7Combination*`。
4. 局部调整：shape/gradient mask + local effect。
5. 导出路径：最高质量输出。

对 `ImageNode` 还建议补一条执行面一致性基线：

- `makeFrame(profile:)`
- `transmitFrame(profile:completion:)`
- `startRenderFrameTask(profile:)`
- `makeFrameAsync(profile:)`

这四个入口应共享同一条 route contract、diagnostics 语义和结果指纹；如果其中某一路出现额外 prewarm、额外 readback 或 diagnostics 漂移，应视为回归而不是“异步实现差异”。
6. 分析路径：histogram + color probe。
7. 大图路径：由应用自己的大图策略或 tile runtime 承接。

每条链应固定输入素材、尺寸、profile 和输出类型，避免每次测试都在比较不同问题。

## 注意事项

- 不建议为了减少 pass 破坏 alpha 正确性。
- 不建议为了减少分配丢失 texture owner retention。
- 实时预览路径应避免非必要 CPU readback。
- 优化 `ImageNode` 或 graph 路径时，也应确认默认 `HarbethIO + filters` 路径没有退化。
- 性能结论建议附带 benchmark 数据或 diagnostics，而不是只依赖主观感受。
