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
xcrun swift test --filter CLAHEFilterTests
```

这组 baseline 的定位不是给出固定门槛，而是保证后续每次优化都在同一批真实链路上回看趋势：

- `HarbethIO` 轻量滤镜链
- `ImageNode` 统一链路
- geometry + sampler override
- edit / layer composite / transition advanced routes
- pixelBuffer / YCbCr bridge

`CLAHEFilterTests/test4KHotPathReusesTemporaryBuffersWithinResourceAndPerformanceGate` 是一条
与趋势型 baseline 分开的结构化门槛：在 `3840×2160`、`8×8` tile grid 下，warmup 后连续四次
render 必须复用同一组 histogram / sample-count / LUT private buffer，不得新增临时 buffer；编码维持
一个 clear、histogram、LUT、apply 共四个 encoder，且 hot-path p95 端到端时间低于 1 秒。它只防止
明显的资源重复分配或不必要同步回归，不替代按设备记录的真实性能 benchmark。

`RealtimeRouteBenchmarkTests` 额外记录五条实时交付路线的 cold first frame、60 Hz steady-state 端到端延迟、GPU duration、deadline、in-flight/backlog、stable/dropped frames、fallback 与 resident-memory delta。输入使用固定数量的环形 slot，不能让 benchmark 自身一次性常驻数百份像素数据并污染内存结果。

### Realtime 五路径证据合同

当前 JSON schema 为 v2，但保留既有根字段、五个 route 字符串、route 顺序、`avgFrameTime` / `p95` / `p99` / `firstFrameTime` / `stableFrames` / `droppedFrames` 等旧键，以及 `NSTemporaryDirectory()/HarbethRealtimeRouteBenchmarks/latest.json` 路径。v2 只追加字段；新 decoder 读取没有 `schemaVersion` 的旧产物时按 v1 处理，并把无法从旧数据证明的 GPU、deadline、in-flight/backlog 指标保留为 `null`，不能用 `0` 冒充“已经测量且没有成本”。旧 decoder 会忽略 v2 追加键。

每条 route 的执行顺序固定为：

1. 单独执行 1 次 cold frame，原序记录 `firstFrameTime` 与 `firstFrameSucceeded`。
2. 执行 20 次串行 warmup，不进入 steady-state 样本和 frame count。
3. 以 16.666666 ms 周期产生 300 个逻辑帧；`avgFrameTime`、`p95`、`p99` 只统计这 300 个帧机会中成功回调的端到端延迟，分位数使用 nearest-rank。

端到端延迟从逻辑帧的计划到达时刻开始，到 route 完成回调为止，因此会包含主线程交接、Harbeth render operation queue 等待、CPU 编码、GPU 完成等待，以及该 route 明确包含的输出 copy 或 host handoff。它不是单纯的 CPU encode time，也不能用 GPU duration 相减得到 CPU time。

前四条处理路线的 GPU 字段来自已完成 `MTLCommandBuffer` 的 `gpuStartTime` / `gpuEndTime`，由 `PerformanceMonitor` 按逻辑帧 identifier 聚合。只有 `status` 完成且时间戳为有限正区间的样本才能进入 `gpuAvgFrameTime` / `gpuP95` / `gpuP99`；设备或环境返回零时间戳时必须输出 `null` 并令 `gpuTimingAvailable=false`。BGRA 固定输入下当前每帧通常只有一个处理 command buffer，但统计合同允许未来按帧聚合多个 command buffer。

队列与丢帧字段按以下语义计算：

- `maxInFlightFrames`：已经被 cadence runner 接受、但完成回调尚未返回的逻辑帧峰值；当前环形 slot 同时构成明确的 `inFlightLimit`。
- `maxBacklogFrames`：提交时观察到的 `renderOperationQueue.operationCount - maxConcurrentOperationCount` 正值峰值；它是 Harbeth frame-operation backlog，不冒充 Metal command queue 的内部深度。
- `schedulerDroppedFrames`：60 Hz producer 自身醒来时，该帧的 16.67 ms 机会已经过期，因此未提交。
- `backpressureDroppedFrames`：所有 in-flight slot 均被占用，输入帧被明确拒绝。
- `deadlineMissedFrames`：route 成功完成，但完成回调晚于该帧 deadline；benchmark 会把这类陈旧结果视为已丢弃，不再交给 host。
- `failedFrames`：route 错误回调或测量超时。
- `stableFrames`：在 deadline 内成功完成并可交付的帧。
- `droppedFrames`：上述 scheduler、backpressure、deadline miss 与 failure 的互斥总和；v2 明确改变了 v1 中“仅等于抛错次数”的旧语义，并保持 `stableFrames + droppedFrames == frameCount`。

证据边界必须随结果一起保留：前三条 `ImageNode -> RenderView.display` 路线测到的是 processing + host handoff，第四条 `HarbethIO -> output` 还包含输出 pixelBuffer copy。测试宿主中的 `RenderView` 没有真实 window/drawable，所以五条路线全部输出 `includesDrawablePresentation=false`；第五条 `RenderView.texture` 只是 host-assignment 对照，没有 command buffer，必须输出 `gpuTimingAvailable=false` 和 `null` GPU 时间。这里的 dropped frame 是由真实 60 Hz 到达、完成回调、deadline 和明确丢弃决策得到的 route-level drop，不代表相机采集丢帧、窗口合成器 present feedback 或物理显示器丢帧。需要后两类结论时必须另做真机/真实 drawable 测试。

## Texture Pool 与真实 MTLHeap

3.0 的 pool 命中必须满足完整 descriptor contract。尺寸容差只允许放宽 width/height，usage、storage、sample、mipmap、texture type、array/depth、CPU cache 和 hazard tracking 必须一致。

默认 `.exact` 适合短任务和少量纹理。重复尺寸的实时帧或长链路可以对比 `.heapBacked`：

```swift
HarbethContext.shared.textureAllocationStrategy = .heapBacked
defer { HarbethContext.shared.textureAllocationStrategy = .exact }
```

比较时至少同时记录：

- `TextureAllocatorSnapshot.heapBackedAllocationCount`
- `heapCount`、`heapReservedMemory`、`heapUsedMemory`
- `heapAllocationFallbackCount`
- `textureReuseHitRatio`
- cold first frame 与 steady-state p95/p99

Heap 的 reserved bytes 是预算成本，不能只看 used bytes；少量纹理场景中，直接分配可能更省。发生 memory pressure 时，Harbeth 会先释放池内闲置纹理，再回收已经没有资源的空 Heap，不会强制回收仍被 in-flight/output texture 使用的 Heap。

## 请求资源门禁与实际观察

`RenderRequest.resourceEstimate` 来自编译后的 optimization plan，适合在分配纹理前做 admission；它不是运行后的真实峰值。需要执行证据时使用：

```swift
let request = try node.makeRenderRequest(profile: .exportQuality)
    .withResourceBudget(RenderResourceBudget(maximumTotalBytes: 256 * 1024 * 1024))

let result = try request.renderFrameWithResourceReport()
let estimate = result.report.admission.estimate
let observation = result.report.observation
```

报告会区分 texture request、实际 allocation、pool reuse、heap-backed allocation、allocated bytes 与 reused bytes。预算拒绝在执行前 fail-fast，不应该通过自动降低质量来掩盖。

## Pointwise fusion

连续 Brightness、Contrast、Saturation、Exposure、Gamma 与 Opacity 在合同兼容时会 lower 为一次 dispatch。性能报告必须同时看真实输出正确性和 dispatch/pass 变化；不能把 diagnostics 中的“eligible”当成已经融合。

以下情况保守保留 barrier：邻域采样、多纹理、全局依赖、readback、不确定 dynamic range 或显式禁止 fusion。验证使用 `PointwiseFusionTests`，其中包含融合链与逐 pass 参考结果的像素对比。

## Binary Archive 与派生资源缓存

`PipelineBinaryArchiveConfiguration.memoryOnly` 可用于当前进程预热；持久化模式必须由宿主提供 URL，并在选定预热完成后显式 serialize。统计 `registeredComputePipelineCount` / `registeredRenderPipelineCount` 与 `loadedFromDisk`，不要把 archive 文件存在等同于本次请求没有 pipeline 编译成本。

output-contract texture、派生 mask 与 3D LUT 共享 `DerivedResourceCacheConfiguration` 的 byte/count budget。监控 `DerivedResourceCacheSnapshot` 的 entry/bytes、hit/miss、eviction 与 rejected insertion；namespace 用于隔离文档/会话，domain invalidation 用于局部清理。generation 拒绝陈旧任务回写，因此 rejected insertion 在主动失效期间可能是正确行为。

## GPU waveform 与 vectorscope

`renderImageScope(_:)` 的 accumulation 和 visualization 都在 GPU 上完成，适合预览检查。只有转换成 `CGImage` 时才产生 CPU readback。基准需要分别记录 GPU scope texture 路径与显式 readback 路径，不能混成一个数字。

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
