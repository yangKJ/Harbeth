# Harbeth 能力地图

这份文档不再重复讲第二套“如何使用”。

它只回答三件事：

1. 各目录主要负责什么
2. 它属于 `HarbethIO`、`ImageNode`，还是它们的支撑层
3. 为什么这个目录需要存在

对外使用方式请看 [API_SURFACE_CN.md](API_SURFACE_CN.md)。

## 1. 两条公开路线

Harbeth 对外只保留两条路线：

- `HarbethIO`
- `ImageNode`

源码目录并不是第三条、第四条路线，而是为了支撑这两条路线存在。

## 2. 目录与路线映射

| 目录 | 主要职责 | 对外归属 |
| --- | --- | --- |
| `Sources/Basic/IO/` | 直接 source + filters -> output，以及 frame / attachment 结果对象与 preview host | `HarbethIO` 主路线与结果对象层 |
| `Sources/Basic/Image/` | node、recipe、graph 入口、编辑 primitive | `ImageNode` 主路线 |
| `Sources/Basic/Analysis/` | render 后读取、统计、探针、analysis bundle | 两条路线的 post-render inspection |
| `Sources/Basic/Mask/` | mask 模型、recipe 与 scope 派生 mask 桥接 | editing / local effect / scoped mask |
| `Sources/Basic/Filters/` | mask、transition、layer composite、YCbCr decode 等底座滤镜 | `HarbethIO` / `ImageNode` 共享执行能力 |
| `Sources/Basic/Geometry/` | projective、upright、homography、采样等几何语义 | `ImageNode` 结构化入口的支撑层 |
| `Sources/Basic/Optics/` | lens profile、optics settings | 通过 filters 接入两条路线 |
| `Sources/Basic/Kernel/` | kernel descriptor、invocation、execution contracts | `ImageNode` 高级执行解释层的支撑 |
| `Sources/Basic/Runtime/` | graph compiler、request/task、allocator、loader、context、cache | 两条路线共享执行骨架 |
| `Sources/Basic/Core/` | filter protocol、组合协议、基础执行协议、元数据 | 底座共用核心，不是独立路线 |
| `Sources/Basic/Matrix/` | matrix / vector 数学支撑 | supporting math layer |
| `Sources/Basic/Setup/` | shared enums、errors、wrappers、typealias、resource lookup | 通用基础设施 |
| `Sources/Basic/Extensions/` | image / buffer / texture / CoreGraphics 辅助能力 | 实现支撑层 |

## 3. 各层为什么存在

### `IO/`

负责：

- `HarbethIO`
- `ImageSource`
- `RenderedFrame`
- `RenderedAttachmentSet`
- `RenderView`
- operators

存在意义：

- 保住最轻量的主路径
- 把同步、异步和容错输出统一收口在 `HarbethIO`
- 承接结果对象层，避免再扩出第三条公开路线
- 让调用方不需要先理解 node、graph、runtime
- `RenderView` 继续只是默认 preview host；它会消费 frame metadata / runtime hint，但不扩张成媒体生命周期或任务调度器

### `Image/`

负责：

- `ImageNode`
- `ImageGraph`
- `EditRecipe`
- `ImageTransformRecipe`
- `LayerCompositeRecipe`
- `TransitionRecipe`
- mask / local effect / layer primitive

存在意义：

- 把高级能力统一收口到一个入口
- 把结构化编辑描述放在 node 语义层，而不是散落在外部手动拼 filter

### `Analysis/`

负责：

- `RenderedAnalysisBundle`
- `RenderedAttachmentAnalysisBundle`
- `TextureHistogram`
- `TextureStatistics`
- `TextureColorProbe`
- `TextureAnalysisScope`
- `ReplayBaseContract`
- `RenderCacheIdentity`

存在意义：

- 把“算出来”和“看结果”分层
- 避免把分析能力误写成执行入口

结论：

- `Analysis` 不是路线三
- 它是 render 之后的 inspection layer
- replay/cache identity 也只是结果读取与缓存协商面，不是新入口
- 普通高级调用优先从 `ImageNode` 的 analysis convenience 进入，再按需下沉到 `RenderRequest`、`RenderedFrame` / attachment output

### `Mask/`

补充一类 bridge：

- `TextureScopedMask`

存在意义：

- 把 `TextureAnalysisScope` 派生成可复用 mask texture / descriptor
- 供 `RenderedFrame`、`RenderedAttachmentSet`、`RenderRequest` 和 `ImageNode` 高级工作流消费

### `Geometry/`

负责：

- `PerspectiveTransform`
- `GuidedUpright`
- `Homography`
- `Transform3DLayout`
- `RenderProjectiveCanvas`：显式逆 Homography + 像素画布，并通过 attachment 独立输出 coverage
- 采样和几何辅助结构

存在意义：

- 承载 editor-grade 的几何语义
- 为 `ImageTransformRecipe` 提供结构化表达

结论：

- `Geometry` 已经嵌入 `ImageNode` 路线
- 普通调用方不需要先理解底层几何滤镜再自己手拼

### `Optics/`

负责：

- `LensProfile`
- `OpticsRecipe`

存在意义：

- 承载镜头校正和光学矫正组合能力

结论：

- `Optics` 本质上是结构化镜头校正入口
- 当前合理接法是通过 `ImageNode.applying(optics:)` 进入
- 底层仍然可以显式转成 filters，但不再作为普通用户主路线
- 它不单独扩成第三条路线

### `Kernel/`

负责：

- `KernelDescriptor`
- `KernelInvocation`
- `KernelExecutionPlan`
- `KernelParameterBinding`
- `KernelContract`

存在意义：

- 把高级 shader contract、function identity、参数指纹、资源约束做成可解释数据面

结论：

- `Kernel` 通过 `ImageNode.applyingWithContract(...)` 对外间接可见
- `KernelDescriptor` 等对象不是普通使用入口
- `KernelExecutionPlan`、`KernelContract` family 更适合被理解成 supporting contract read surface，而不是 app 集成层入口

### `Runtime/`

负责：

- `RenderGraph`
- `RenderGraphDebugSnapshot`
- `RenderRequest`
- `RenderTask`
- `RenderSubmissionPolicy` / `RenderSubmissionHandle`
- `Device`
- `HarbethContext`
- `ExecutionScheduler`
- `TextureLoader`
- `TextureAllocator`
- `TexturePool`
- `PixelBufferPool`
- `PipelineBinaryArchiveConfiguration`
- `DerivedResourceCacheConfiguration`
- `RenderResourceBudget`
- `RenderParitySignature`

存在意义：

- 统一承接两条路线背后的执行、缓存、桥接和调试骨架

结论：

- `Runtime` 已嵌入 `HarbethIO` 和 `ImageNode`
- 它不是对外第三路线
- `HarbethContext` 是公开的 supporting resource boundary；`Device`、command/operation queue 与具体 pool/cache owner 保持内部，重复的 `Shared` facade 已删除
- `RenderRequest`、`RenderTask` 是 deferred execution / observation form，不是新的集成模型
- `RenderSubmissionPolicy` / `RenderSubmissionHandle` 为两条主路线提供可选 latest-only、取消和 stale delivery 治理；默认 independent，不替代上层产品调度策略
- `HarbethContext` 的 image-resolution cache 现在带 namespace + LRU discipline，属于 runtime 内部缓存治理，不改变外部路线划分
- compute/render pipeline 可选择 memory-only 或宿主指定 URL 的 Binary Archive；Harbeth 不猜测业务缓存目录
- output-contract texture、派生 mask 与 3D LUT 共享 generation-safe 派生资源治理，可按 domain/namespace 定向失效并在 memory pressure 下回收
- `RenderRequest` 的资源 admission、allocator 实测报告与 preview/export parity 都是高级检查合同，不形成第三条执行路线

### `Core/`

负责：

- `C7FilterProtocol`
- `C7FilterPipelineProtocol`
- `RenderProtocol`
- `MPSKernelProtocol`
- `BlitProtocol`
- `C7AdvancedMetalKernelProtocol`
- filter metadata / authoring support

还包括：

- `FilterMetadataProviding`
- `FilterParameterDescriptor`
- `FilterIntensityHint`

存在意义：

- 提供底座最核心的滤镜开发契约

结论：

- `Core` 主要服务滤镜开发者和内部执行
- 普通使用者通过 `HarbethIO` 和 `ImageNode` 消费结果，不通过 `Core` 选路线

## 4. 哪些能力已经串进两条路线

已经明确串联：

- image / cgImage / texture / pixelBuffer / sampleBuffer 输入
- `Data` / `ImageAsset` source contract
- filters
- optics filter builders
- recipe-driven edit / local effect / layer composite / transition
- render diagnostics / debug snapshot / graph
- deferred request / task
- histogram / statistics / color probe / attachment analysis
- projective geometry：`PerspectiveTransform`
- guided upright：`GuidedUpright`

## 5. 哪些能力不单独串成入口

这些能力继续公开或保留，但不作为独立路线营销：

- kernel descriptor / invocation / execution plan
- render boundary / render command / render pass contract
- shared/device/context/allocator/pool
- homography / transform layout 等底层数学结构

原因：

- 它们解决的是执行解释、调试、缓存、资源、数学支撑问题
- 不是普通调用方的 first touch API

## 6. 路线和目录的最终心智

对外：

- `HarbethIO`：轻量直接处理
- `ImageNode`：高级统一入口

对内：

- `Analysis`：post-render inspection
- `Geometry` / `Optics`：高级图像语义 primitive
- `Kernel` / `Runtime` / `Core`：执行与编译支撑层

后续如果新增公开能力，先问：

1. 它该归 `HarbethIO` 还是 `ImageNode`
2. 如果都不是，它是不是 supporting / authoring / runtime support
3. 如果还不是，就不该变成新的公开路线
关于 mask 相关源码分布，当前要区分两层：

- `Sources/Compute/Blend Modes/`：旧滤镜目录里的 blend catalog，例如 `C7MaskedForegroundBlend`、`C7Blend(mask)`，表达的是“几张 texture 直接做一次混合”
- `Sources/Basic/Filters/`：新 editing / `ImageNode` / local-effect / layer-composite 的内部执行 primitive，例如 `GradientMask`、`ShapeMask`、`MaskCoverageExtract`、`MaskCoverageBlend`、`MaskRegionBlend`、`LayerComposite`
- `Sources/Basic/Mask/TextureScopedMask.swift`：scope 派生 mask 能力，供 `RenderedFrame`、`RenderedAttachmentSet`、`RenderRequest` 和 `ImageNode` 高级工作流消费
- `ImageNode` editing / recipe 路线：承接高级 mask compositing 语义，`HarbethIO` 不再提供独立 mask facade

不要只因为名字里都带 `Mask` 就机械搬到同一个目录；它们的输入 contract 和宿主语义并不相同。
