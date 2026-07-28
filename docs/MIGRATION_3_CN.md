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

## 4. 真实 MTLHeap

Heap allocator 是 3.0 的高级资源策略，继续位于两条公开路线下面。开启后，Harbeth 在设备 capability 允许时从真实 `MTLHeap` 分配，并维持 descriptor-safe reuse、统一预算、内存压力清理、空 heap 回收和直接分配 fallback：

```swift
let report = Device.metalCapabilityReport(.heapTexturePool)

if report.isSupported {
    Shared.shared.defaultTextureAllocationStrategy = .heapBacked
}
```

策略必须在创建本轮纹理任务前设置。默认仍为 `.exact`，避免仅处理少量纹理的应用无条件承担 heap reservation；实时预览、重复尺寸的长滤镜链和稳定帧处理可通过 benchmark 决定是否启用。

可通过 allocator diagnostics 与 `Shared.shared.texturePoolStatistics` 检查：

- heap 数量、reserved/used bytes
- 真实 heap texture allocation 次数
- heap 分配 fallback 次数
- descriptor-safe reuse hit rate

当设备不支持 Heap，`.heapBacked` 会稳定降级为 `.exact`；单次 Heap 创建因预算、storage 或碎片失败时，会降级为 `device.makeTexture`，不会返回半初始化资源。

## 5. 性能验证

升级前后至少固定同一份输入、尺寸、profile 与滤镜链，对比：

```bash
xcrun swift test --filter PerformanceBaselineTests
xcrun swift test --filter RealtimeRouteBenchmarkTests
```

重点记录 cold/hot cache、真实首帧、平均值、p95/p99、stable/dropped frames、Heap reserved/used、fallback、readback 和输出 fingerprint。不要用单次 wall time 或排序后的最小值替代真实首帧。

## 6. 发布前检查

```bash
xcrun swift test
xcrun swift test -c release
xcodebuild build -workspace Harbeth.xcworkspace -scheme Harbeth -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
pod lib lint Harbeth.podspec --platforms=ios,macos,tvos --skip-tests
```

3.0 发布后，CI 会以 `3.0.0` tag 作为 Swift public API breakage 基线。后续 3.x 不应引入未说明的 breaking change。
