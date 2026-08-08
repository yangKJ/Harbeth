# Harbeth

![Harbeth](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3eaa018dedb9433bb51f408f5bb73faf~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=600&h=234&s=31350&e=jpg&b=f5f4f4)

[![CI](https://github.com/yangKJ/Harbeth/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/yangKJ/Harbeth/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/yangKJ/Harbeth)](https://github.com/yangKJ/Harbeth/releases)
[![CocoaPods](https://img.shields.io/cocoapods/v/Harbeth.svg)](https://cocoapods.org/pods/Harbeth)
[![License](https://img.shields.io/github/license/yangKJ/Harbeth)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20tvOS-6D28D9)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138)

面向 Apple 平台、以 texture-first 为核心的 Metal 图像与帧处理引擎。

Harbeth 支持 `UIImage` / `NSImage`、`CGImage`、`CIImage`、`MTLTexture`、`CVPixelBuffer` 与 `CMSampleBuffer`，提供滤镜、渲染图、蒙版、转场、几何与光学 primitive、输出 contract、诊断和预览宿主。

它是产品内部的渲染底座，而不是产品工作流：交互、媒体生命周期、持久化与产品策略由宿主决定；Harbeth 负责把单张图像或单帧描述转成具有明确输出语义的 GPU 渲染结果。

[English](README.md) | 简体中文

## 环境要求

| 平台 | 最低版本 |
| --- | --- |
| iOS / iPadOS | 15.0 |
| macOS | 12.0 |
| tvOS | 15.0 |
| 工具链 | Xcode 16+、Swift 6 |

## 安装

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yangKJ/Harbeth.git", from: "3.0.0")
]
```

把 `Harbeth` 添加到实际执行图片或帧渲染的 target。

### CocoaPods

```ruby
pod 'Harbeth', '~> 3.0'
```

## 只需选择两条路线之一

Harbeth 对普通使用者只表达两条路线。Runtime、Analysis、Recipe 与 Preview Host 都是两条路线的支撑层，不是额外入口。

| 路线 | 适用场景 | 标准结果入口 |
| --- | --- | --- |
| `HarbethIO` | 已经有输入源与滤镜链，需要直接处理 | `try output()` / `await transmitOutput()` |
| `ImageNode` | 需要 Harbeth 的高级统一图、编辑合同、检查与交付能力 | `makeTexture()` / `makeFrame()` / `makeFrameAsync()` |

### 输入与结果速查

| 输入 | `HarbethIO` 直接结果 | `ImageNode` 高级结果 |
| --- | --- | --- |
| `UIImage` / `NSImage`（`C7Image`） | 同类型图片 | texture、frame、图片读回 |
| `CGImage` / `CIImage` | 同输入类型 | texture、frame、图片读回 |
| `MTLTexture` | `MTLTexture` | texture 或携带元数据的 frame |
| `CVPixelBuffer` | `CVPixelBuffer` | texture、frame、attachments |
| `CMSampleBuffer` | `CMSampleBuffer` | texture、frame、preview-host metadata |
| `Data` / `ImageAsset` | 解码资产优先使用 `ImageNode` | texture、frame、diagnostics |

### 1. 使用 `HarbethIO` 直接处理

```swift
let outputImage = try HarbethIO(
    element: inputImage,
    filters: [
        C7Exposure(exposure: 0.25),
        C7Contrast(contrast: 1.08),
        C7Saturation(saturation: 0.94)
    ]
).output()
```

`output()` 是主要同步入口，因为渲染失败对调用方可见；`transmitOutput(...)` 是与它同等级的核心异步入口。

不希望当前调用方等待 GPU 完成时，使用对应的异步入口：

```swift
let outputImage = try await HarbethIO(
    element: inputImage,
    filters: filters
).transmitOutput()
```

回调式接入可使用 `transmitOutput(outputColorSpace:complete:)`。存在滤镜任务时，Harbeth 会在内部 render operation queue 编码，并在默认 profile 下等待 GPU 完成后回调。回调线程不固定，更新 UI 时需显式回到 `MainActor`；空滤镜快速路径因为没有异步渲染工作，可能在当前调用栈内直接完成。

低延迟异步纹理链路继续只使用历史公开开关 `transmitOutputRealTimeCommit`：

```swift
var io = HarbethIO(
    element: inputTexture,
    filters: filters
)
io.transmitOutputRealTimeCommit = true
let outputTexture = try await io.transmitOutput()
```

开关为 `true` 时，异步 texture-first 输出可在 command buffer 已 scheduled、尚未 completed 时交付纹理。它不改变同步 `output()` 的完成语义；图片、pixel buffer 与 sample buffer 输出即使打开该开关，也会在 CPU 物化前等待 GPU 完成。

### 2. 使用 `ImageNode` 组织结构化处理

`ImageNode` 是 Harbeth 的高级统一入口。当一次处理不只是简单滤镜链，还要承载可复用输入、结构化编辑、输出意图、元数据、缓存策略、诊断或多种交付形态时，应由它组织整条链路。

```swift
let node = ImageNode.image(inputImage)
    .applying(C7Exposure(exposure: 0.25))
    .applying(C7Contrast(contrast: 1.08))
    .transforming(ImageTransformRecipe(rotationDegrees: 90))
    .withCachePolicy(.transient)

let previewFrame = try node.makeFrame(profile: .stablePreview)
let backgroundFrame = try await node.makeFrameAsync(profile: .stablePreview)
let exportTexture = try node.makeTexture(profile: .exportQuality)
```

它承接的核心能力包括：

- 统一输入：image、`CGImage`、`CIImage`、texture、pixel buffer、sample buffer、编码数据与 `ImageAsset`。
- 可组合处理：普通滤镜、显式 kernel contract、plugin、缓存策略与 sampler 策略。
- 结构化编辑：`EditRecipe`、Geometry、Optics、局部效果、渐变/形状/路径/组合蒙版，以及可复用的 preview/final 模式。
- 多源合成：转场和有序图层合成，并保留蒙版、变换、混合与输出合同。
- 稳定交付语义：`RenderProfile`、`ImageDerivativeSpec`、颜色/Alpha/方向/source tier 元数据与纹理所有权共同进入 `RenderedFrame`。
- 检查与重放：image graph、diagnostics、debug snapshot、延迟执行的 `RenderRequest`，以及 histogram/statistics/color probe、mask 与 output attachment。

只需要纹理结果时用 `makeTexture()`；需要元数据与宿主交付时用 `makeFrame()`；不阻塞调用方时用真正进入 render operation queue 的 `makeFrameAsync()`；需要延迟执行或检查计划时用 `makeRenderRequest()`。已有 node 时优先使用 `node.editing(...)`、`node.transforming(...)`、`node.applying(optics: ...)` 这类实例链。各类 Recipe 是 `ImageNode` 内部的编辑描述 primitive，不单独形成第三条路线。

## Texture-first 预览

UIKit 与 AppKit 可直接承载 `RenderedFrame`：

```swift
renderView.display(previewFrame)
```

SwiftUI 使用同一套 Harbeth 预览底座，不需要先把纹理读回成图片：

```swift
HarbethRenderView(
    frame: previewFrame,
    resizingMode: .aspectFit
)
```

`RenderView` 与 `HarbethRenderView` 是渲染输出宿主。Harbeth 负责保留帧元数据、选择可用宿主策略、处理 visibility pause/resume，并暴露执行报告；宿主应用继续负责采集、播放、录制、时间线、导出和持久化。

只有明确需要读回为 SwiftUI `Image` 时使用 `HarbethView`；texture-first 预览使用 `HarbethRenderView`。

## 引擎能力

- image、texture、pixelBuffer、sampleBuffer 输入输出链路。
- compute、render、blit、MPS、filter pipeline，以及边界明确的 Metal command encoding 逃生口；当前 183 个公开执行类型与 30 种 `C7Blend` 模式见[滤镜目录](docs/FILTER_CATALOG.md)。
- 颜色、模糊、混合、边缘与细节、几何、光学、LUT/Cube、Utility、Generator 与质量滤镜。
- 通过 `C7FilterPipelineProtocol` 实现的公开 Combination 滤镜。
- 蒙版、局部效果、图层合成、转场和编辑 Recipe primitive。
- 纹理池、真实 `MTLHeap`、请求级资源预算、Binary Archive、派生资源治理、预热、render-plan cache 与稳定 fingerprint。
- Alpha、工作/输出色彩配置、YUV、HDR metadata、输出量化、输出尺寸、方向和读回 contract。
- GPU waveform/vectorscope、直方图、统计、探针、图快照、预览/导出 parity 和性能指标。
- 自定义 `.metal`、`.metallib` 与可选 Metal library provider 接入。

Harbeth 采用 capability-driven 语义：支持某个 contract 或平台，不代表所有设备都具备相同 Metal 特性。高级能力应结合 capability report 与对应 fallback 行为使用。

3.0 的 heap allocator 是 opt-in 的真实 `MTLHeap` 资源策略。公开使用方式仍然只有 `HarbethIO` / `ImageNode`，descriptor 兼容、预算、内存压力、lease 与直接分配 fallback 都由内部 runtime 承担。启用前请阅读 [3.0 迁移指南](docs/MIGRATION_3_CN.md)。

常用 pointwise 调整只有在 pixel contract 证明安全时才会合成一次 Metal dispatch；邻域采样、多纹理、全局依赖、CPU readback 与显式 barrier 继续保留独立 pass。`RenderRequest` 可在分配纹理前执行资源预算门禁、比较预览/导出 parity，并返回 allocator 实测报告。这些都属于两条主路线下的支撑合同，不形成新的处理入口。

## 错误、日志与 Issue

标准处理 API 通过 `HarbethError` 抛出失败，Harbeth 默认静默。需要时可把结构化事件接入宿主日志系统：

```swift
HarbethLogger.minimumLevel = .warning
HarbethLogger.handler = { event in
    appLogger.log("[\(event.category)] \(event.message)")
}
```

提交 GitHub Issue 时可生成不包含图片与用户数据的环境摘要：

```swift
let supportJSON = try HarbethSupportSnapshot.capture().json()
```

快照只包含 Harbeth 版本、平台、操作系统、Metal 设备名和性能监控状态。

## 性能口径

Harbeth 让高频路径保持 texture-first，并复用 render plan、pipeline state 与纹理分配。真实耗时由设备、输入尺寸、像素格式、滤镜链和输出 contract 共同决定，因此项目不再宣称一个适用于所有场景的倍数。

低延迟展示使用 `RenderProfile.interactiveLatency`，稳定预览使用 `stablePreview`，需要 GPU 完成或 CPU 读回时使用 `exportQuality` / `readbackQuality`。可复现的测量规则见[性能治理指南](docs/PERFORMANCE_GOVERNANCE_CN.md)。

## Demo

工作区包含三个接入工作台：

- [`Harbeth-iOS-Demo`](Demo/Harbeth-iOS-Demo)：UIKit Showcase、ImageNode Lab、相机帧参考接线、Mask 与完整滤镜目录。
- [`Harbeth-SwiftUI-Demo`](Demo/Harbeth-SwiftUI-Demo)：SwiftUI 路线选择与输出宿主示例。
- [`Harbeth-macOS-Demo`](Demo/Harbeth-macOS-Demo)：AppKit 滤镜和桌面端接入示例。

它们用于验证 Harbeth 渲染能力，不是封装好的相机或视频编辑 SDK。

## 文档

- [文档总导航](docs/README.md)
- [DocC 入口](Sources/Harbeth.docc/Harbeth.md)
- [完整滤镜目录](docs/FILTER_CATALOG.md)
- [自定义滤镜指南](docs/CUSTOM_FILTERS.md)
- [故障排查](docs/TROUBLESHOOTING.md)
- [公开 API 分层](docs/API_SURFACE_CN.md)
- [能力地图](docs/CAPABILITY_MAP_CN.md)
- [性能治理指南](docs/PERFORMANCE_GOVERNANCE_CN.md)
- [维护与发布检查](docs/MAINTAINING.md)
- [变更记录](CHANGELOG.md)

## 参与贡献

Bug 请使用仓库 Issue 表单，并附最小 `HarbethIO` / `ImageNode` 复现和 `HarbethSupportSnapshot`。接入问题与架构取舍请使用 [Discussions](https://github.com/yangKJ/Harbeth/discussions)。

## 支持 Harbeth 持续演进

Harbeth 不是一次性示例，而是我长期维护的 Apple GPU 图像处理底座。真正让一个底座值得依赖的，往往是那些不太显眼却持续发生的工作：跟进 Apple 平台变化、复现边界问题、分析真实负载、收紧 API 合同，以及让文档始终与代码一致。

如果 Harbeth 曾替你省下一段 Metal 基础建设、避开一个线上问题，或已经成为项目里可靠的一环，欢迎把这份实际价值转化为对维护工作的支持：

- 点亮 Star 或分享项目，让更多 Apple 平台开发者发现它。
- 通过 [GitHub Sponsors](https://github.com/sponsors/yangKJ) 提供持续支持。
- 通过 Buy Me a Coffee、支付宝或微信提供一次性支持。

支持不是使用门票，也不是任何人的义务。Harbeth 仍然按照 MIT License 开放；赞助的意义，只是让我能更从容地认真处理平台变化、回归问题和那些真正棘手的边界情况。

<a href="https://www.buymeacoffee.com/yangkj3102">
  <img width="180" alt="请作者喝杯咖啡" src="https://user-images.githubusercontent.com/1888355/146226808-eb2e9ee0-c6bd-44a2-a330-3bbc8a6244cf.png">
</a>

<a href="https://github.com/sponsors/yangKJ">
  <img alt="GitHub Sponsors" src="https://img.shields.io/badge/GitHub-Sponsors-blue?style=for-the-badge">
</a>

支付宝或微信一次性支持：

<p align="left">
  <img src="Screenshot/WechatIMG1.jpg" width="220" alt="支付宝赞赏二维码">
  <img src="Screenshot/WechatIMG2.jpg" width="220" hspace="15" alt="微信赞赏二维码">
</p>

维护者：[yangKJ](https://github.com/yangKJ) · [yangkj310@gmail.com](mailto:yangkj310@gmail.com)

## License

Harbeth 使用 [MIT License](LICENSE)。
