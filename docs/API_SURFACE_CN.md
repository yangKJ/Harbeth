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

texture 输入仍然只走同一个 direct processing 出口：

```swift
let io = HarbethIO(element: inputTexture, filters: filters)

let texture = try io.output()
```

异步 direct processing：

```swift
io.transmitOutput { result in
    // handle result
}
```

HDR / EDR 输出建议：

- `HarbethIO.output(outputColorSpace:)` 和 `HarbethIO.transmitOutput(outputColorSpace:)` 允许显式指定输出色彩空间
- `ImageNode.makeFrame(outputColorSpace:)` 允许把同一份输出 contract 继续带到 frame / diagnostics / metadata
- `RenderOutputContract.hdrPQTexture`、`RenderOutputContract.hdrHLGTexture`、`RenderOutputContract.toneMappedDisplayP3Texture` 是当前推荐的 HDR / EDR / SDR 输出预设
- `RenderOutputContract.toneMappingPolicy` 用来声明当前输出是保留 HDR / EDR，还是显式 tone map 到 SDR

一致性说明：

- `HarbethIO` 对外只表达 `source + filters -> output/transmitOutput`
- `RenderProfile`、`RenderRequest`、`RenderedFrame`、diagnostics、analysis、task 等高级概念不作为 `HarbethIO` 普通用户入口表达
- 内部可以继续复用 render plan、texture pool、frame runtime，但这些属于 implementation detail

输入类型上的实际判断：

- `C7Image / CGImage / MTLTexture / CVPixelBuffer / CMSampleBuffer` 支持 `output()` typed round-trip
- `Data / URL / ImageAsset` 更适合作为 `ImageNode` source 进入高级路线

`OpticsRecipe` / `LensProfile` 推荐直接通过 `ImageNode.applying(optics:)` 进入结构化编辑路线；如果只想做低层直通处理，也可以直接显式构造 `filters` 再交给 `HarbethIO(filters:)`：

```swift
let filters: [C7FilterProtocol] = [
    C7LensDistortionCorrection(distortion: -0.2, cubicDistortion: 0.04, scale: 1.01),
    C7DefringeCorrection(purpleAmount: 0.5)
]

let output = try HarbethIO(
    element: inputImage,
    filters: filters
).output()
```

边界：

- `HarbethIO` 不负责结构化编辑描述
- 不负责 graph / optimizer / snapshot 的主心智
- 不负责 mask facade、analysis facade、frame facade、task facade
- 不新增 optics runtime、kernel runtime 或 recipe runtime facade

### 路线二：ImageNode

定位：

- 高级统一入口
- 承接 graph、cache、diagnostics、analysis
- 承接 recipe-driven editing
- 承接 kernel-aware execution、transition、layer composite

推荐理解顺序：

1. 先用 `ImageNode` 直接表达 source、filters、recipe 和 editing
2. 需要延迟执行、异步调度或高级读取时，再从 `ImageNode` 下沉到 `RenderRequest`
3. 只有明确需要 frame metadata、preview host 信息、replay contract 或稳定 attachment 输出时，再显式拿 `RenderedFrame` / `RenderedAttachmentSet`

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

同一条 node route 现在也保留了 callback / task / async 三种等价执行面：

```swift
let task = try node.startRenderFrameTask(profile: .stablePreview)
let callbackToken = node.transmitFrame(profile: .stablePreview) { result in
    // handle result
}

let asyncFrame = try await ImageNode
    .texture(inputTexture)
    .editing(recipe)
    .makeFrameAsync(profile: .stablePreview)
```

这些入口的目标不是引入第三套执行语义，而是让 `ImageNode` 在同步、callback、task、async 四种宿主接法下仍共享同一条 request / diagnostics / frame contract。

### RenderRequest：延迟执行与高级读取

`RenderRequest` 不是第三条公开路线。

它的定位是：

- 从 `ImageNode` 派生出来的 deferred single-frame render contract
- 适合先编译、后执行，或把 diagnostics / source contract 和真正 render 拆开
- 适合把 analysis、attachment 读取和 frame render 收口在同一个 request 上

典型用法：

```swift
let request = try ImageNode
    .texture(inputTexture)
    .applying(filters: filters)
    .makeRenderRequest(profile: .readbackQuality)

let diagnostics = request.diagnostics
let texture = try request.renderTexture()
let frame = try request.renderFrame()
```

请求级资源与预览/导出一致性也继续挂在同一个 `RenderRequest` 上：

```swift
let guarded = request.withResourceBudget(
    RenderResourceBudget(
        maximumTotalBytes: 128 * 1024 * 1024,
        maximumTextureCount: 16,
        maximumStageCount: 12
    )
)

guard guarded.resourceAdmission.isAccepted else {
    // 在任何纹理分配前处理 violations
    return
}

let measured = try guarded.renderFrameWithResourceReport()
let parity = previewRequest.parityReport(comparedTo: exportRequest)
```

`resourceEstimate` 来自编译后的 optimization plan；真正执行时由 allocator 记录 allocation/reuse/heap bytes。`parityReport` 把视觉差异与仅交付差异分开，不能用“两个请求都能成功渲染”代替一致性检查。

如果调用方已经明确要走延迟读取面，优先在 `RenderRequest` 上完成 analysis / attachment inspection，而不是先拿 `RenderedFrame` 再绕回去：

```swift
let request = try node.makeRenderRequest(profile: .readbackQuality)

let histogram = try request.renderHistogram(channel: .luminance)
let statistics = try request.renderStatistics()
let probe = try request.renderColorProbe(x: 240, y: 180)

let attachment = try request.renderAttachment(semantic: .luminance)
let attachmentAnalysis = try request.renderAttachmentAnalysis(semantic: .luminance)
```

所以这里的推荐层级固定为：

- `ImageNode`：高级主入口
- `RenderRequest`：deferred / async / analysis / attachment read surface
- `RenderedFrame` / `RenderedAttachmentSet`：结果对象层

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
            sizePolicy: .maxPixelSize(1024),
            flipsVertically: false
        )
    )
)

let assetDiagnostics = try assetNode.makeDiagnostics(profile: .stablePreview)
```

kernel-aware 路径：

```swift
let node = ImageNode
    .texture(inputTexture)
    .applyingWithContract(C7Brightness(brightness: 0.1))
    .applyingWithContract(C7PremultiplyAlpha())

let texture = try node.makeTexture(profile: .stablePreview)
```

recipe-driven editing：

```swift
let previewNode = try ImageNode
    .texture(inputTexture)
    .applying(
        mask: MaskGradientRecipe(
            size: C7Size(width: inputTexture.width, height: inputTexture.height),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            )
        ),
        filters: [C7Exposure(exposure: 0.12)],
        opacity: 0.8,
        mode: .preview
    )
    .applying(C7Brightness(brightness: 0.08))

let previewFrame = try previewNode.makeFrame(profile: .stablePreview)
```

对外默认优先把局部能力表达成 `.applying(mask: ...)`。`LocalEffectRecipe` 的定位是这层 facade 背后的高级结构化 primitive，不是普通调用方的默认学习入口。只有在调用方明确需要组合 geometry、多段 local effects、或复用结构化编辑配方时，再下沉到 `LocalEffectRecipe + EditRecipe`：

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
```

如果调用方手里已经有 `background texture + foreground texture + MaskDescriptor`，并且需要保留完整的 component / invert / feather / opacity 语义，推荐继续走 `ImageNode.layerComposite(...)` 或 `ImageNode.applying(mask: ...)`。`HarbethIO` 不再提供独立的 texture mask compositing facade。

私有插件包如果要接进 `ImageNode`，也仍然走这条路线，不新增独立 `PluginNode`：

```swift
let pluginNode = try ImageNode
    .texture(inputTexture)
    .applying(pluginOutput: .localEffect(
        LocalEffectRecipe(
            filters: [C7Exposure(exposure: 0.12)],
            mask: MaskDescriptor(texture: maskTexture)
        )
    ))

let previewFrame = try pluginNode.makeFrame(profile: .stablePreview)
renderView.display(previewFrame)
```

规则：

- source-like 插件输出，例如 `texture`、`image`、`cgImage`、`pixelBuffer`、`sampleBuffer`，先回到 `ImageSource`
- editing-like 插件输出，例如 `filters`、`EditRecipe`、`LocalEffectRecipe`、`LayerCompositeRecipe`，继续进入现有 `ImageNode` 路径
- 插件层不再返回裸 `MaskDescriptor`；局部能力必须直接包装成 `LocalEffectRecipe` 或 `EditRecipe`
- `applying(mask:, filters:)` 是 `ImageNode` 面向普通调用方的首选局部入口；底层仍统一 lowering 到 `LocalEffectRecipe + editing(...)`
- 如果局部效果只有一个 filter，优先使用 `applying(mask:filter:)`，避免为了轻量用法再包一层数组
- `applying(localEffect:)` 只作为高级 primitive 入口保留，适合插件桥接、结构化编辑状态和多段 local effect 复用

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
let snapshot = try ImageNode
    .transition(
        from: .texture(fromTexture),
        to: .texture(toTexture),
        kernel: .directionalWipe(angleDegrees: 45, softness: 0.08),
        progress: 0.35
    )
    .makeDebugSnapshot(profile: .stablePreview)
```

如果调用方需要显式持有 preview/final contract 或重复复用 transition 配置，再保留 `TransitionRecipe`：

```swift
let recipe = TransitionRecipe(
    from: .texture(fromTexture),
    to: .texture(toTexture),
    kernel: .directionalWipe(angleDegrees: 45, softness: 0.08),
    progress: 0.35
)
```

Geometry 在 `ImageNode` 里的结构化入口：

- `ImageTransformRecipe`
- `PerspectiveTransform`
- `GuidedUpright`

当调用方已经拥有外部求解的 Homography，并需要投影到显式像素画布时，使用底层 `RenderProjectiveCanvas`。它只负责几何投影、透明边界和独立 `.coverage` attachment，不负责配准、接缝、曝光或裁边策略：

```swift
let filter = RenderProjectiveCanvas(
    canvasToSource: inverseHomography,
    outputSize: C7Size(width: 2048, height: 1024),
    edgeFeatherFraction: 0.04
)
let outputs = try filter.renderAttachmentSet(from: sourceTexture)
let color = outputs.primary?.texture
let coverage = outputs.texture(for: .coverage)
```

最自然的接法现在是直接挂在已有 node 上，而不是先切回单独执行入口：

```swift
let node = ImageNode
    .texture(inputTexture)
    .transforming(
        ImageTransformRecipe(
            guidedUpright: uprightGuides,
            projectiveViewportMode: .aspectFill
        )
    )
    .applying(C7Brightness(brightness: 0.06))
```

示例：

```swift
let recipe = EditRecipe(
    geometry: ImageTransformRecipe(
        perspectiveTransform: perspective,
        projectiveViewportMode: .aspectFit
    )
)

let frame = try ImageNode
    .texture(inputTexture)
    .editing(recipe)
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
- `LayerCompositeRecipe` 的 layer-local transform / filters 现在也会进入同一份 route-level `samplerExecutionCoverage` 诊断，而不是只在真实执行里生效、在 diagnostics 里丢失

当前已经进入真实执行覆盖的 family：

- 普通 `RenderProtocol`
- `C7Crop`
- `C7Rotate`
- `C7Transform`
- `C7LensDistortionCorrection`
- `C7ChromaticAberrationCorrection`
- `RenderQuadTransform` / `RenderQuadRectifyTransform`

但这里有一个边界要明确：

- render path 可以直接绑定 `MTLSamplerState`
- 上述历史 compute geometry / optics family，以及 `RenderQuadTransform` / `RenderQuadRectifyTransform`，都只能桥接到 `SpatialSamplingMode` / `SpatialEdgeMode`
- 因此只有当 `ImageSamplerDescriptor` 能被映射成 nearest/linear 和 clamp/repeat 这类空间采样语义时，它们才算真实覆盖
- 如果调用方传入的是当前 compute family 不能完整表达的 sampler 组合，diagnostics 仍会把它记成 `metadataOnly` 或 `partial`

调用方应通过 diagnostics 判断当前链路到底属于哪一类：

```swift
let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

diagnostics.samplerDescriptor
diagnostics.samplerExecutionCoverage.mode
diagnostics.samplerExecutionCoverage.coveredFilterTypes
diagnostics.samplerExecutionCoverage.metadataOnlyFilterTypes
```

执行层上的低风险优化也已经真闭环：

- `HarbethIO` 在真正开始编码前，会按 `RenderOptimizationPlan.prewarmReservations` 同步预热 texture pool
- 双 buffer filter chain 也会同步预热两块目标纹理
- 因此 `prewarmReservations` 不再只是 diagnostics 建议，texture pool reuse hit 已经能在测试里观测到

普通用户可以把它理解成高级 node contract，而不是全局采样策略总开关。

source contract 一致性说明：

- `ImageNode` 在 `editing(...)`、`transforming(...)`、`transition(...)`、`layerComposite(...)` 这些高级路径里，即使执行期已经把 source 物化成上游 texture，`RenderRequest`、`RenderRecipe`、`RenderGraphDebugSnapshot` 仍以最终 node contract 为准
- `sampleBuffer`、`pixelBuffer`、YCbCr、HDR、attachment-derived color contract 不会因为内部先解成 texture 就在调试面退化成裸 `texture` source
- 这条规则同样覆盖 HDR-friendly bi-planar sampleBuffer：YCbCr decode contract、attachment color contract、HDR friendliness 会在 request / recipe / snapshot / diagnostics / frame source descriptor 上保持同一套语义
- 目标是让执行、request、recipe、diagnostics 四个 surface 讲的是同一件事

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
- `MaskRecipe`
- `MaskGradientRecipe`
- `MaskShapeRecipe`
- `MaskPathRecipe`
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
- `MaskPathDescriptor`

定位：

- 这些 descriptor 主要服务 diagnostics、render recipe、debug snapshot 和 host-side inspection
- 它们不是新的 mask 执行入口
- `MaskRecipe` 是参数化 mask recipe 的统一合同；普通调用仍优先走 `ImageNode` / `EditRecipe`
- `MaskShapeRecipe` 是基础参数化形状主入口：`rectangle`、`ellipse`、`roundedRect`、`triangle`、`regularPolygon`、`star`
- `MaskPathRecipe` 负责自定义 subpaths、freehand、镂空路径和 decorative vector path；它不是普通调用方选择基础形状的首选入口
- 当前 `regularPolygon` / `star` 虽然内部仍可 lower 到 path 执行，但对外语义和 diagnostics 仍保持 `MaskShapeRecipe`

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

插件支撑层相关类型：

- `PluginOutput`
- `PluginCapability`
- `PluginContext`
- `TexturePlugin`
- `FilterPlugin`
- `MaskPlugin`
- `PreviewDisplaying`

定位：

- 它们是私有插件包、GPU preview host 和 `ImageNode` 之间的桥接支撑层
- 外部能力统一通过 `Plugin` 接入；Runtime boundary 只是内部调度和诊断实现
- 最终执行入口仍然是 `HarbethIO` 或 `ImageNode`
- `RenderRequest`、`RenderTask` 属于 deferred/supporting read surface，不是第三条 app integration route
- `RenderView` 只是 `PreviewDisplaying` 的默认实现，显示对象统一回到 `RenderedFrame`
- `RenderView` 现在会消费 `RenderedFrame` 暴露的 frame host metadata / runtime hint，用来区分 low-latency、stable preview 和 readback-style host 行为
- `ReplayBaseContract`
- `RenderCacheIdentity`

定位：

- 它们是两条主路线的结果对象层或延迟执行面
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
- `OpticsRecipe`

定位：

- 它们是带语义的 optics builders
- 主入口是进入 `ImageNode.applying(optics:)`；低层直接处理时再用 `HarbethIO(filters:)`

示例：

```swift
let optics = OpticsRecipe.profile(lensProfile)
    .adding(.defringe(.init(purpleAmount: 0.5)))

let node = ImageNode
    .texture(inputTexture)
    .applying(optics: optics)
```

## 3. Analysis 如何使用

`Analysis` 不是第三条路线。

它的定位固定为：

- `HarbethIO` / `ImageNode` 负责算出结果
- `Analysis` 负责读取和检查结果

也就是固定模式：

1. 先 render
2. 再 inspect

从 `ImageNode` 直接分析：

```swift
let node = ImageNode
    .image(inputImage)
    .applying(filters: filters)

let histogram = try node.makeHistogram(
    profile: .readbackQuality,
    channel: .luminance
)
let statistics = try node.makeStatistics(profile: .readbackQuality)
let probe = try node.makeColorProbe(profile: .readbackQuality)
```

如果需要拿完整 frame、preview host 信息或 replay contract，再下沉到 `RenderedFrame`：

```swift
let node = ImageNode
    .texture(inputTexture)
    .applying(C7Brightness(brightness: 0.1))

let frame = try node.makeFrame(profile: .stablePreview)
let replayContract = frame.replayBaseContract
let frameHostSource = frame.frameHostSourceDescriptor
let frameHostHint = frame.frameHostRuntimeHint

let attachment = try node.makeAttachment(
    profile: .readbackQuality,
    semantic: .luminance
)
let analysis = try node.makeAttachmentAnalysis(
    profile: .readbackQuality,
    semantic: .luminance
)
```

局部分析：

```swift
let scope = TextureAnalysisScope(region: region)

let histogram = try node.makeHistogram(
    profile: .readbackQuality,
    channel: .luminance,
    scope: scope
)
let statistics = try node.makeStatistics(
    profile: .readbackQuality,
    scope: scope
)
let probe = try node.makeColorProbe(
    profile: .readbackQuality,
    scope: scope
)
let mask = try node.makeMaskDescriptor(
    profile: .readbackQuality,
    scope: scope
)
```

这一层的主要对象分成三类：

- 入口层：`ImageNode`、`RenderRequest`
- 结果对象：`RenderedFrame`、`RenderedAttachmentSet`、`RenderedAnalysisBundle`、`RenderedAttachmentAnalysisBundle`
- 分析工具：`TextureHistogram`、`TextureStatistics`、`TextureColorProbe`、`TextureAnalysisScope`
- scope mask bridge：`makeMaskTexture(scope:)`、`makeMaskDescriptor(scope:)`

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
- `RenderCommand*`
- `TextureAllocator`
- `TexturePool`
- `Shared`
- `Device`
- `HarbethContext`
- `Homography`
- `Transform3DLayout`

其中 `HarbethContext` 当前还承载 image-resolution cache；这层缓存已经补齐 namespace + LRU discipline，用来避免跨 source 世代复用旧 resolution 指纹，同时限制长期常驻条目数量。

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
