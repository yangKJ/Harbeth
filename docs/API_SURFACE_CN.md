# Harbeth 公开 API 分层

Harbeth 对外只保留两条主路线：

- `HarbethIO`
- `ImageNode`

`Recipe` family、`Analysis`、`Kernel`、`Runtime` 都继续存在，但它们不再被表达成额外的使用路线。

## 1. 两条主路线

### 路线一：HarbethIO

定位：

- 轻量默认路径
- 表达最直接的 `source + filters -> output`
- 适合一张图或一帧输入经过滤镜链直接得到结果

`HarbethIO` 当前真实输入面：

- `C7Image`
- `CGImage`
- `MTLTexture`
- `CVPixelBuffer`
- `CMSampleBuffer`
- `Data`
- `URL`
- `ImageAsset`

最小用法：

```swift
let filters: [C7FilterProtocol] = [
    C7Brightness(brightness: 0.08),
    C7Contrast(contrast: 1.05),
    C7Saturation(saturation: 1.1)
]

let image = try HarbethIO(element: inputImage, filters: filters).output()
```

texture-first / frame-first：

```swift
let io = HarbethIO(element: inputTexture, filters: filters)

let texture = try io.renderTexture(profile: .stablePreview)
let frame = try io.renderFrame(profile: .stablePreview)
let request = try io.makeRenderRequest(profile: .stablePreview)
```

buffer / encoded output：

```swift
let pixelBuffer = try io.renderPixelBuffer(profile: .exportQuality)
let pngData = try HarbethIO(element: inputImage, filters: filters).renderPNGData()
let jpegData = try HarbethIO(element: inputImage, filters: filters)
    .renderJPEGData(compressionQuality: 0.92)
```

deferred / async：

```swift
let task = try io.startRenderTextureTask(profile: .interactiveLatency)
let request = try io.makeRenderRequest(profile: .stablePreview)

io.transmitOutput { result in
    // handle result
}
```

输入类型上的实际判断：

- `C7Image / CGImage / MTLTexture / CVPixelBuffer / CMSampleBuffer` 支持 `output()` typed round-trip
- `Data / URL / ImageAsset` 会先通过 `makeImageSource()` 进入统一 source contract，但不保证 `output()` 还能 typed round-trip 回原始输入类型
- 对 `Data / URL / ImageAsset`，推荐使用 `renderTexture(...)`、`renderFrame(...)` 或 `makeRenderRequest(...)`

示例：

```swift
let frame = try HarbethIO(element: imageData, filters: filters)
    .renderFrame(profile: .stablePreview)

let texture = try HarbethIO(element: imageURL, filters: filters)
    .renderTexture(profile: .stablePreview)
```

`OpticsSettings` / `LensProfile` 继续按 filter builder 接入：

```swift
let optics = OpticsSettings(
    profile: lensProfile,
    defringe: .init(purpleAmount: 0.2)
)

let output = try HarbethIO(
    element: inputImage,
    filters: optics.makeFilters()
).output()
```

边界：

- `HarbethIO` 不负责结构化编辑描述
- 不负责 graph / optimizer / snapshot 的主心智
- 不新增 optics runtime、kernel runtime 或 recipe runtime facade

### 路线二：ImageNode

定位：

- 高级统一入口
- 承接 graph、cache、diagnostics、analysis
- 承接 recipe-driven editing
- 承接 kernel-aware execution、transition、layer composite

`ImageNode` 当前真实 source 面：

- `.image(...)`
- `.cgImage(...)`
- `.texture(...)`
- `.pixelBuffer(...)`
- `.sampleBuffer(...)`
- `.data(...)`
- `.asset(...)`

直接 source + filters：

```swift
let node = ImageNode
    .texture(inputTexture)
    .applying(C7Brightness(brightness: 0.1))
    .applying(C7Contrast(contrast: 1.05))
    .withCachePolicy(.persistent)

let texture = try node.makeTexture(profile: .stablePreview)
let frame = try node.makeFrame(profile: .stablePreview)
let diagnostics = try node.makeDiagnostics(profile: .stablePreview)
let graph = try node.makeImageGraph(profile: .stablePreview)
let snapshot = try node.makeDebugSnapshot(profile: .stablePreview)
let request = try node.makeRenderRequest(profile: .stablePreview)
```

通过 `Data / ImageAsset / pixelBuffer / sampleBuffer` 接入：

```swift
let frame = try ImageNode
    .data(imageData)
    .applying(C7Exposure(exposure: 0.1))
    .makeFrame(profile: .stablePreview)

let assetNode = ImageNode.asset(
    ImageAsset(
        storage: .url(imageURL),
        loadingOptions: .init(
            sizePolicy: .thumbnail(maxPixelSize: 1024),
            appliesEXIFOrientation: true
        )
    )
)

let assetDiagnostics = try assetNode.makeDiagnostics(profile: .stablePreview)
```

kernel-aware 路径：

```swift
let node = ImageNode
    .texture(inputTexture)
    .applyingKernel(C7Brightness(brightness: 0.1))
    .applyingKernel(C7PremultiplyAlpha())

let texture = try node.makeTexture(profile: .stablePreview)
```

recipe-driven editing：

```swift
let recipe = EditRecipe(
    geometry: ImageTransformRecipe(
        targetSize: CGSize(width: 1600, height: 900),
        aspectPolicy: .fit
    ),
    localEffects: [
        LocalEffectRecipe(
            filters: [C7Exposure(exposure: 0.12)],
            mask: MaskDescriptor(texture: maskTexture, opacity: 1)
        )
    ]
)

let node = ImageNode
    .recipe(source: .texture(inputTexture), recipe: recipe, mode: .preview)
    .applying(C7Brightness(brightness: 0.08))

let previewFrame = try node.makeFrame(profile: .stablePreview)
```

layer composite：

```swift
let recipe = LayerCompositeRecipe(
    background: .texture(backgroundTexture),
    layers: [
        ImageLayer(
            content: .texture(foregroundTexture),
            normalizedFrame: CGRect(x: 0.15, y: 0.2, width: 0.5, height: 0.5),
            opacity: 0.9,
            blendMode: .normal
        )
    ]
)

let frame = try ImageNode
    .layerComposite(recipe)
    .makeFrame(profile: recipe.profile, derivative: recipe.derivative)
```

transition：

```swift
let recipe = TransitionRecipe(
    from: .texture(fromTexture),
    to: .texture(toTexture),
    kernel: .directionalWipe(angleDegrees: 45, softness: 0.08),
    progress: 0.35
)

let snapshot = try ImageNode
    .transition(recipe)
    .makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
```

Geometry 在 `ImageNode` 里的结构化入口：

- `ImageTransformRecipe`
- `PerspectiveTransform`
- `GuidedUpright`

示例：

```swift
let recipe = EditRecipe(
    geometry: ImageTransformRecipe(
        perspectiveTransform: perspective,
        projectiveViewportMode: .aspectFit
    )
)

let frame = try ImageNode
    .recipe(source: .texture(inputTexture), recipe: recipe)
    .makeFrame(profile: .stablePreview)
```

`GuidedUpright` 也通过 `ImageTransformRecipe` 进入，而不是要求调用方自己手动拼投影滤镜：

```swift
let recipe = EditRecipe(
    geometry: ImageTransformRecipe(
        guidedUpright: uprightGuides,
        projectiveViewportMode: .aspectFill
    )
)
```

`withSamplerDescriptor(_:)` 的当前收口判断：

- 它仍然是稳定的 node metadata、cache key 和 diagnostics 输入
- 它在 `ImageNode` 的已覆盖执行路径上已经会真实影响输出
- 当前仍然不应表述成“所有 compute/render filter 都已统一严格执行这个 sampler state”

当前已覆盖的执行面：

- 普通 `RenderProtocol` filters：通过 runtime sampler state 绑定生效
- `RenderQuadTransform` / `RenderQuadRectifyTransform`：通过 geometry adapter 映射到 `SpatialSamplingMode` / `SpatialEdgeMode`
- `EditRecipe` / `TransitionRecipe` / `LayerCompositeRecipe` 进入 `ImageNode` 后，最终执行会继续沿用同一个 sampler contract

当前仍是 metadata-only 的历史 family：

- `C7Crop`
- `C7Rotate`
- `C7Transform`
- `C7LensDistortionCorrection`
- `C7ChromaticAberrationCorrection`

调用方应通过 diagnostics 判断当前链路到底属于哪一类：

```swift
let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

diagnostics.samplerDescriptor
diagnostics.samplerExecutionCoverage.mode
diagnostics.samplerExecutionCoverage.coveredFilterTypes
diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes
```

普通用户可以把它理解成高级 node contract，而不是全局采样策略总开关。

## 2. Supporting Public

这些类型仍然公开，但它们是两条主路线的配置、结果或描述对象，不是第三条入口。

### Editing Primitives

- `EditRecipe`
- `LayerCompositeRecipe`
- `TransitionRecipe`
- `ImageTransformRecipe`
- `LocalEffectRecipe`
- `MaskDescriptor`
- `MaskCompositeRecipe`
- `MaskGradientRecipe`
- `MaskShapeRecipe`
- `ImageLayer`

边界：

- 顶层 recipe 不再承载全局 `filters`
- 全局 filters 统一放在 `HarbethIO(filters:)` 或 `ImageNode.applying(...)`
- 局部结构内 filters 继续保留，例如 `LocalEffectRecipe.filters`、`ImageLayer.filters`

与 editing primitive 一起暴露的 supporting descriptor：

- `MaskGraphDescriptor`
- `MaskCompositeStepDescriptor`
- `MaskGradientDescriptor`
- `MaskShapeDescriptor`

定位：

- 这些 descriptor 主要服务 diagnostics、render recipe、debug snapshot 和 host-side inspection
- 它们不是新的 mask 执行入口

### Deferred / Results / Diagnostics

- `RenderRequest`
- `RenderTask`
- `RenderPlanDiagnostics`
- `RenderGraphDebugSnapshot`
- `ImageGraph`
- `RenderedFrame`
- `RenderedAttachmentSet`
- `RenderedAnalysisBundle`
- `RenderedAttachmentAnalysisBundle`
- `ReplayBaseContract`
- `RenderCacheIdentity`

定位：

- 它们是两条主路线的返回值或延迟执行面
- 不应被包装成新的 runtime facade

其中：

- `ReplayBaseContract` 描述某个结果允许从哪一级 source 重放
- `RenderCacheIdentity` 描述 host-side cache 读取时可复用的稳定身份
- 它们是 replay/cache supporting surface，不是第三条执行路线

### Output / Render Contracts

- `RenderOutputContract`
- `RenderOutputAttachmentContract`
- `ImageAlphaContract`
- `ImageColorSpaceContract`
- `PixelFormatContract`
- `PixelBufferContract`
- `SampleBufferContract`
- `ImageSamplerDescriptor`
- `ImageCachePolicy`
- `RenderProfile`
- `ImageDerivativeSpec`

定位：

- 它们负责描述 source / output / diagnostics contract
- 它们不是独立执行入口

### Structured Filter Builders

- `LensProfile`
- `OpticsSettings`

定位：

- 它们是带语义的 filter builders
- 最自然的接法仍然是产出 filters 后交给 `HarbethIO` 或 `ImageNode`

## 3. Analysis 如何使用

`Analysis` 不是第三条路线。

它的定位固定为：

- `HarbethIO` / `ImageNode` 负责算出结果
- `Analysis` 负责读取和检查结果

也就是固定模式：

1. 先 render
2. 再 inspect

从 `RenderedFrame` 分析：

```swift
let frame = try HarbethIO(element: inputImage, filters: filters)
    .renderFrame(profile: .stablePreview)

let histogram = frame.makeHistogram(channel: .luminance)
let statistics = frame.makeStatistics()
let probe = frame.makeColorProbe()
```

从 `ImageNode` 分析：

```swift
let node = ImageNode
    .texture(inputTexture)
    .applying(C7Brightness(brightness: 0.1))

let frame = try node.makeFrame(profile: .stablePreview)
let histogram = frame.makeHistogram(channel: .red)

let attachmentSet = try node.makeAttachmentSet(profile: .readbackQuality)
let analysisBundle = try node.makeAttachmentAnalysisBundle(profile: .readbackQuality)
```

局部分析：

```swift
let scope = TextureAnalysisScope(region: region)

let histogram = frame.makeHistogram(channel: .luminance, scope: scope)
let statistics = frame.makeStatistics(scope: scope)
let probe = frame.makeColorProbe(scope: scope)
```

这一层的主要对象分成两类：

- 结果对象：`RenderedFrame`、`RenderedAttachmentSet`、`RenderedAnalysisBundle`、`RenderedAttachmentAnalysisBundle`
- 分析工具：`TextureHistogram`、`TextureStatistics`、`TextureColorProbe`、`TextureAnalysisScope`、`TextureAnalysisMask`

所以 `Analysis` 的正确理解是：

- 不是 pipeline
- 不是 render 入口
- 是 post-render inspection layer

## 4. Filter Authoring

这一层是滤镜开发者 API，不是普通集成路线：

- `C7FilterProtocol`
- `C7FilterPipelineProtocol`
- `ModifierEnum`
- `KernelParameterBinding`
- `RenderProtocol`
- `MPSKernelProtocol`
- `BlitProtocol`
- `C7AdvancedMetalKernelProtocol`
- `FilterMetadataProviding`
- `FilterParameterDescriptor`
- `FilterIntensityHint`

参数表达建议：

- 简单 `Float` 数组参数可以继续用 `factors`
- 具备命名、类型、矩阵、颜色、布尔值或资源绑定语义的参数，优先使用 `kernelParameterBindings`
- 同一个滤镜建议只选一种主参数表达方式，不要混用

## 5. Internal Runtime

这些对象服务内部编译、fingerprint、execution plan 和 diagnostics，不应被理解成新的 app integration path：

- `KernelDescriptor`
- `KernelInvocation`
- `KernelExecutionPlan`
- `KernelContract` family
- `RenderBoundary*`
- `RenderCommand*`
- `TextureAllocator`
- `TexturePool`
- `Shared`
- `Device`
- `HarbethContext`
- `Homography`
- `Transform3DLayout`

普通使用者何时不该直接碰它们：

- 只是要处理一张图或一帧：不要直接碰
- 只是要做编辑描述：不要直接碰
- 只是要拿 diagnostics / snapshot / analysis：优先从 `HarbethIO` 或 `ImageNode` 返回值读取

如果必须使用，先判断它属于哪一类：

- supporting read surface
- filter authoring surface
- internal runtime support

## 6. 收口规则

后续新增公开能力时，先按这个顺序判断：

1. 能不能自然归入 `HarbethIO`
2. 能不能自然归入 `ImageNode`
3. 如果不能，它是不是 supporting public、filter authoring 或 internal runtime
4. 如果都不是，就不应该再长出新的公开路线
