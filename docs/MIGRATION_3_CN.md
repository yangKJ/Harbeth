# Harbeth 3.0 迁移指南

Harbeth 3.0 是新的公开基线，不继续叠加已经退出的 typo alias、旧 runtime facade、watchOS target 或不再成立的隐式行为。升级时先把调用面归入 `HarbethIO` 或 `ImageNode`，再处理资源与输出合同。

## 1. 选择公开路线

直接处理一张图或一帧：

```swift
let output = try HarbethIO(element: input, filters: filters).output()

HarbethIO(element: input, filters: filters).transmitOutput { result in
    // handle result
}
```

需要 recipe、geometry、mask、transition、layer composite、frame metadata、diagnostics 或 analysis：

```swift
let frame = try ImageNode
    .texture(inputTexture)
    .applying(filters: filters)
    .makeFrame(profile: .stablePreview)
```

`Runtime`、`Analysis`、`Recipe` 与 `RenderRequest` 都是这两条路线的 supporting layer，不是新的普通用户入口。

## 2. 必须处理的公开变更

- 最低平台调整为 iOS/iPadOS 15、macOS 12、tvOS 15；watchOS 不再发布。
- SwiftPM 与工程语言模式调整为 Swift 6。
- `HarbethIO.output()` 是同步标准入口；异步使用 `transmitOutput(...)`。
- 删除 typo alias、旧 runtime accessors、`Outputable` 泛型扩展、`C7CombinationBase` 与全局 `R.width` / `R.height`。
- Harbeth 不再传递式 re-export `AVFoundation`；宿主直接 `import AVFoundation`。
- UIKit/AppKit/SwiftUI 预览优先消费 `MTLTexture` 或 `RenderedFrame`，避免为了显示而提前 CPU readback。

## 3. 纹理与资源合同

3.0 的纹理复用会同时检查尺寸、pixel format、texture type、mipmap、array/depth、sample count、usage、storage mode、CPU cache mode 与 hazard tracking mode。不要依赖“宽高和像素格式相同就一定复用”的历史偶然行为。

普通中间纹理默认不再创建 mipmap。只有真实采样链需要时才显式开启：

```swift
let texture = try TextureLoader.makeTexture(
    width: width,
    height: height,
    options: [.textureMipmapped: true]
)
```

GPU-only 中间资源可以显式选择 private storage；需要 CPU `replace` 或读回的资源继续使用 shared/managed 合同：

```swift
let texture = try TextureLoader.makeTexture(
    width: width,
    height: height,
    options: [
        .textureStorageMode: MTLStorageMode.private,
        .textureUsage: MTLTextureUsage.shaderRead.union(.shaderWrite)
    ]
)
```

资源入口统一迁移到 `HarbethContext.shared`。`Device` 与 `Shared` 已退为内部实现，不再承担公开合同：

| 旧入口 | 3.0 入口 |
| --- | --- |
| `Shared.shared.metalDevice` | `HarbethContext.shared.device` |
| `Shared.shared.commandQueue.makeCommandBuffer()` | `HarbethContext.shared.makeCommandBuffer()` |
| `Shared.shared.deinitDevice()` | `HarbethContext.shared.recoverExecution()` |
| `Shared.shared.defaultTextureAllocationStrategy` | `HarbethContext.shared.textureAllocationStrategy` |
| `Shared.shared.texturePoolStatistics` | `HarbethContext.shared.texturePoolStatistics` |
| `Device.registerExternalLibraryProvider(...)` | `HarbethContext.shared.registerExternalLibraryProvider(...)` |
| `Device.readMTLFunction(...)` | `HarbethContext.shared.makeMetalFunction(named:)` |

`recoverExecution()` 不销毁进程级 `MTLDevice`；它会轮换 command queue、推进 execution generation 并清理运行时缓存。已经提交给 Metal 的 command buffer 不会被同步取消，需要并发恢复的宿主应使用 generation 拒绝陈旧结果。

## 4. 真实 MTLHeap

Heap allocator 是 3.0 的高级资源策略，继续位于两条公开路线下面。开启后，Harbeth 在设备 capability 允许时从真实 `MTLHeap` 分配，并维持 descriptor-safe reuse、统一预算、内存压力清理、空 heap 回收和直接分配 fallback：

```swift
let context = HarbethContext.shared
let report = context.capabilityReport(.heapTexturePool)

if report.isSupported {
    context.textureAllocationStrategy = .heapBacked
}
```

策略必须在创建本轮纹理任务前设置。默认仍为 `.exact`，避免仅处理少量纹理的应用无条件承担 heap reservation；实时预览、重复尺寸的长滤镜链和稳定帧处理可通过 benchmark 决定是否启用。

可通过 allocator diagnostics 与 `HarbethContext.shared.texturePoolStatistics` 检查：

- heap 数量、reserved/used bytes
- 真实 heap texture allocation 次数
- heap 分配 fallback 次数
- descriptor-safe reuse hit rate

当设备不支持 Heap，`.heapBacked` 会稳定降级为 `.exact`；单次 Heap 创建因预算、storage 或碎片失败时，会降级为 `device.makeTexture`，不会返回半初始化资源。

## 5. Kernel pixel contract 与真实 pass fusion

3.0 不再仅凭“滤镜名字看起来像点操作”推断 tile、HDR、Alpha 或 fusion 安全性。滤镜开发层通过 `KernelPixelContract` 声明工作色彩、Alpha、精度、dynamic range、采样 footprint、坐标/全局依赖、readback 与 fusion policy。

Brightness、Contrast、Saturation、Exposure、Gamma、Opacity 的连续安全链会自动 lower 为一次真实 Metal dispatch。以下边界会强制终止 fusion：

- 邻域或跨坐标采样
- dual/multi texture
- 全局统计或不确定依赖
- CPU readback
- 不兼容的 color/Alpha/precision contract
- 显式禁止 fusion

调用方不需要改用新的执行 API；`HarbethIO` 与 `ImageNode` 仍是入口。迁移自定义滤镜时应补齐真实 pixel contract，而不是依赖默认值获得激进优化。

## 6. 专业色彩、LUT 与 GPU scopes

- 输出合同现在可显式保留 working/output color profile、HDR transfer、Alpha 和 quantization/dither 语义。
- `C7ColorCube` 使用原生 3D texture，严格校验 `.cube` dimension/domain/sample count，并默认使用 tetrahedral interpolation。
- `TextureImageScopeConfiguration` 可在 GPU 上生成 luminance waveform、RGB waveform 或 vectorscope；只有显式调用 `makeCGImage()` 时才发生读回。

最终导出不要隐式假设“预览看起来一致”。应从各自 node 生成 request 后比较：

```swift
let report = previewRequest.parityReport(comparedTo: exportRequest)
guard report.isVisuallyEquivalent else {
    // inspect report.visualDifferences
    return
}
```

## 7. 请求级资源门禁

需要对大图、复杂 recipe 或受限宿主做确定性 admission 时，在执行前给 `RenderRequest` 设置预算：

```swift
let request = try node
    .makeRenderRequest(profile: .exportQuality)
    .withResourceBudget(
        RenderResourceBudget(
            maximumTotalBytes: 256 * 1024 * 1024,
            maximumTextureCount: 24,
            maximumStageCount: 20
        )
    )

let admission = request.resourceAdmission
let result = try request.renderFrameWithResourceReport()
```

预算拒绝发生在纹理分配前，并抛出带稳定诊断码的 `RenderResourceBudgetError`。`resourceEstimate` 是编译期估算；`result.report.observation` 是 allocator 对 allocation、reuse、heap allocation 与 bytes 的执行期观察，两者不能混为一谈。

## 8. Pipeline Binary Archive 与派生资源生命周期

需要预热或跨启动复用 Metal pipeline 时，宿主必须显式决定是否持久化以及文件位置：

```swift
let context = HarbethContext.shared
try context.configurePipelineBinaryArchive(.persistent(at: archiveURL))

// 先跑宿主选定的预热请求，再显式落盘。
try context.serializePipelineBinaryArchive()
```

`.memoryOnly` 适合仅在当前进程预热；`.disabled` 为干净关闭状态。无效配置不会污染已有 archive 状态，损坏的持久化 archive 会重建为可用的内存 archive 并在 snapshot 中留下诊断。Harbeth 不创建或猜测宿主的业务缓存目录。

output-contract texture、派生 mask 与 3D LUT 现在统一受字节/数量预算、LRU、namespace、domain 定向失效和 memory pressure 回收控制。generation 会拒绝失效前已启动任务的陈旧回写：

```swift
context.setDerivedResourceNamespace(documentID)
context.configureDerivedResourceCache(
    DerivedResourceCacheConfiguration(byteLimit: 128 * 1024 * 1024)
)

context.invalidateDerivedResources(domain: .mask, namespace: documentID)
let snapshot = context.derivedResourceCacheSnapshot
```

这些都是两条公开路线的 runtime 支撑，不要求普通滤镜调用方直接管理。

## 9. 性能验证

升级前后至少固定同一份输入、尺寸、profile 与滤镜链，对比：

```bash
xcrun swift test --filter PerformanceBaselineTests
xcrun swift test --filter RealtimeRouteBenchmarkTests
```

重点记录 cold/hot cache、真实首帧、平均值、p95/p99、stable/dropped frames、Heap reserved/used、fallback、readback 和输出 fingerprint。不要用单次 wall time 或排序后的最小值替代真实首帧。

## 10. 发布前检查

```bash
xcrun swift test
xcrun swift test -c release
xcodebuild build -workspace Harbeth.xcworkspace -scheme Harbeth -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
pod lib lint Harbeth.podspec --platforms=ios,macos,tvos --skip-tests
```

3.0 发布后，CI 会以 `3.0.0` tag 作为 Swift public API breakage 基线。后续 3.x 不应引入未说明的 breaking change。
