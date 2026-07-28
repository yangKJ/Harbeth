# Harbeth

| Soul | Combination |
| :---: | :---: |
| <img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Soul.gif" /> | <img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix2.png" /> |

[![CI](https://github.com/yangKJ/Harbeth/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/yangKJ/Harbeth/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/yangKJ/Harbeth)](https://github.com/yangKJ/Harbeth/releases)
[![CocoaPods](https://img.shields.io/cocoapods/v/Harbeth.svg)](https://cocoapods.org/pods/Harbeth)
[![License](https://img.shields.io/github/license/yangKJ/Harbeth)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20tvOS-6D28D9)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138)

A texture-first Metal render engine for image and frame pipelines on Apple platforms.

Harbeth processes `UIImage` / `NSImage`, `CGImage`, `CIImage`, `MTLTexture`, `CVPixelBuffer`, and `CMSampleBuffer`. It provides filters, render graphs, masks, transitions, geometry and optics primitives, output contracts, diagnostics, and preview hosting without taking ownership of your product's camera, player, timeline, recording, or export workflow.

English | [简体中文](README_CN.md)

## Requirements

| Platform | Minimum |
| --- | --- |
| iOS / iPadOS | 15.0 |
| macOS | 12.0 |
| tvOS | 15.0 |
| Toolchain | Xcode 16+, Swift 6 |

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yangKJ/Harbeth.git", from: "3.0.0")
]
```

Add `Harbeth` to the target that renders images or frames.

### CocoaPods

```ruby
pod 'Harbeth', '~> 3.0'
```

## Choose One of Two Routes

Harbeth exposes two normal integration routes. Runtime, analysis, recipes, and preview hosts support these routes; they are not additional entry points.

| Route | Use it when | Canonical result |
| --- | --- | --- |
| `HarbethIO` | You already have a source and a filter chain | `try output()` / `await transmitOutput()` |
| `ImageNode` | You need Harbeth's advanced unified graph, editing, contract, inspection, and delivery surface | `makeTexture()` / `makeFrame()` / `makeFrameAsync()` |

### Source and result map

| Source | Direct `HarbethIO` result | Advanced `ImageNode` result |
| --- | --- | --- |
| `UIImage` / `NSImage` (`C7Image`) | Same image type | Texture, frame, image readback |
| `CGImage` / `CIImage` | Same source type | Texture, frame, image readback |
| `MTLTexture` | `MTLTexture` | Texture or metadata-carrying frame |
| `CVPixelBuffer` | `CVPixelBuffer` | Texture, frame, attachments |
| `CMSampleBuffer` | `CMSampleBuffer` | Texture, frame, preview-host metadata |
| `Data` / `ImageAsset` | Use `ImageNode` for decoded assets | Texture, frame, diagnostics |

### 1. Direct processing with `HarbethIO`

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

`output()` is the primary synchronous API because rendering failures remain observable. `transmitOutput(...)` is its core asynchronous counterpart.

For non-blocking submission, use the async counterpart:

```swift
let outputImage = try await HarbethIO(
    element: inputImage,
    filters: filters
).transmitOutput()
```

Callback-based integrations can use `transmitOutput(outputColorSpace:complete:)`. Filtered work is encoded on Harbeth's render operation queue and completes after GPU completion under the default profile. The callback queue is unspecified, so UI updates must return to `MainActor`. The no-filter fast path may complete inline.

For interactive texture pipelines, choose an explicit render profile:

```swift
let frame = try HarbethIO(
    element: inputTexture,
    filters: filters
)
.configured(for: .interactiveLatency)
.makeFrame()
```

`interactiveLatency` may deliver a texture after its command buffer is scheduled rather than completed. This low-latency contract is texture-first only; image and pixel-buffer outputs still wait for GPU completion before CPU readback.

### 2. Structured processing with `ImageNode`

`ImageNode` is Harbeth's advanced unified entry. Use it when a render description must carry more than a one-shot filter chain: reusable sources, structured edits, output intent, metadata, cache policy, diagnostics, or multiple delivery forms.

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

Its core capabilities are:

- Unified sources: image, `CGImage`, `CIImage`, texture, pixel buffer, sample buffer, encoded data, and `ImageAsset`.
- Composable processing: filters, explicit kernel contracts, plugins, cache policy, and sampler policy.
- Structured editing: `EditRecipe`, Geometry, Optics, local effects, gradient/shape/path/composite masks, and reusable preview/final modes.
- Multi-source composition: transitions and ordered layer composites with masks, transforms, blend contracts, and output contracts.
- Stable delivery semantics: `RenderProfile`, `ImageDerivativeSpec`, color/alpha/orientation/source-tier metadata, and texture ownership travel with `RenderedFrame`.
- Inspection and replay: image graph, diagnostics, debug snapshot, deferred `RenderRequest`, histogram/statistics/color probes, masks, and output attachments.

Use `makeTexture()` for a texture result, `makeFrame()` when metadata and host delivery matter, `makeFrameAsync()` when the caller must not block, and `makeRenderRequest()` when execution must be deferred or inspected. When a node already exists, prefer instance chains such as `node.editing(...)`, `node.transforming(...)`, and `node.applying(optics: ...)`. Recipe families are editing-description primitives inside the `ImageNode` route, not a third public route.

## Texture-First Preview

UIKit and AppKit can host a `RenderedFrame` directly:

```swift
renderView.display(previewFrame)
```

SwiftUI can use the same Harbeth preview substrate without image readback:

```swift
HarbethRenderView(
    frame: previewFrame,
    resizingMode: .aspectFit
)
```

`RenderView` and `HarbethRenderView` are render-output hosts. Harbeth retains frame metadata, chooses an available backing strategy, handles visibility pause/resume, and exposes execution reports. The host application still owns media capture, playback, recording, timeline, export, and persistence.

Use `HarbethView` only when a SwiftUI `Image` readback is the intended result; use `HarbethRenderView` for texture-first preview.

## Engine Capabilities

- Image, texture, pixel-buffer, and sample-buffer input/output paths.
- Compute, render, blit, MPS, and advanced Metal filter execution; see the source-aligned [Filter Catalog](docs/FILTER_CATALOG.md) for all 164 public execution types and 30 `C7Blend` modes.
- Color adjustment, blur, blend, edge/detail, geometry, optics, LUT/Cube, utility, generator, and quality filters.
- Public Combination filters implemented through `C7FilterPipelineProtocol`.
- Mask, local-effect, layer-composite, transition, and edit-recipe primitives.
- Texture pooling, real `MTLHeap` allocation, request budgets, binary archives, derived-resource governance, prewarming, render-plan caching, and stable fingerprints.
- Alpha, working/output color profiles, YUV, HDR metadata, output quantization, output-size, orientation, and readback contracts.
- GPU waveform/vectorscope, histogram, statistics, probes, graph snapshots, preview/export parity, and performance metrics.
- Custom `.metal`, `.metallib`, and external library-provider integration.

Harbeth is capability-driven: support for a contract or platform does not imply that every device has the same Metal feature set. Query capability reports and use the documented fallback behavior for advanced features.

Heap-backed allocation is opt-in and uses real `MTLHeap` resources in 3.0. It keeps the public workflow on `HarbethIO` / `ImageNode`, while the runtime owns descriptor compatibility, budgets, memory pressure, leases, and direct-allocation fallback. See the [3.0 Migration Guide](docs/MIGRATION_3_CN.md) before enabling it.

Common pointwise adjustments can execute as one Metal dispatch when their pixel contracts prove the chain safe to fuse. Neighbor sampling, multi-texture kernels, global dependencies, CPU readback, and explicit barriers remain separate passes. `RenderRequest` can reject work against an explicit resource budget before allocating textures, compare preview/export parity, and return allocator-observed resource reports. These are supporting contracts under the two canonical routes, not additional processing APIs.

## Errors, Logs, and Bug Reports

Harbeth throws `HarbethError` from its canonical processing APIs and is silent by default. Route structured events into your own logger when needed:

```swift
HarbethLogger.minimumLevel = .warning
HarbethLogger.handler = { event in
    appLogger.log("[\(event.category)] \(event.message)")
}
```

Generate a privacy-safe environment summary for a GitHub Issue:

```swift
let supportJSON = try HarbethSupportSnapshot.capture().json()
```

The snapshot contains the Harbeth version, platform, OS, Metal device name, and monitoring state. It does not include images or user data.

## Performance

Harbeth keeps high-frequency routes texture-first, caches render plans and pipeline states, and can reuse texture allocations. Performance depends on device, source dimensions, pixel format, filter chain, and output contract; the project does not claim one universal speed multiplier.

Use `RenderProfile.interactiveLatency` for low-latency presentation, `stablePreview` for reusable preview output, and `exportQuality` / `readbackQuality` when completion or CPU access is part of the contract. See [Performance Governance](docs/PERFORMANCE_GOVERNANCE_CN.md) for repeatable measurement rules.

## Demo

The workspace contains three integration workbenches:

- [`Harbeth-iOS-Demo`](Demo/Harbeth-iOS-Demo): UIKit showcase, ImageNode Lab, camera-frame reference wiring, masks, and the complete filter catalog.
- [`Harbeth-SwiftUI-Demo`](Demo/Harbeth-SwiftUI-Demo): SwiftUI route selection and output-host examples.
- [`Harbeth-macOS-Demo`](Demo/Harbeth-macOS-Demo): AppKit filter and desktop integration examples.

These are workbenches for Harbeth's render capabilities, not packaged camera or video-editing SDKs.

## Documentation

- [Documentation map](docs/README.md)
- [DocC catalog](Sources/Harbeth.docc/Harbeth.md)
- [Filter catalog](docs/FILTER_CATALOG.md)
- [Custom filter guide](docs/CUSTOM_FILTERS.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Public API surface](docs/API_SURFACE_CN.md)
- [Capability map](docs/CAPABILITY_MAP_CN.md)
- [Performance governance](docs/PERFORMANCE_GOVERNANCE_CN.md)
- [Maintenance and release checks](docs/MAINTAINING.md)
- [Changelog](CHANGELOG.md)

## Contributing

Bug reports should use the repository Issue form and include a minimal `HarbethIO` or `ImageNode` reproduction plus a `HarbethSupportSnapshot`. Use [Discussions](https://github.com/yangKJ/Harbeth/discussions) for integration questions and architecture tradeoffs.

## Support Long-Term Maintenance

Harbeth is maintained as long-term open-source infrastructure, not as a one-off sample project. The work that makes a GPU engine dependable is often the least visible: following Apple platform changes, reproducing edge cases, profiling real workloads, refining API contracts, and keeping the documentation honest.

If Harbeth has saved you an afternoon of Metal infrastructure work, helped you avoid a production issue, or become a dependable part of your rendering stack, consider returning a small part of that value in the way that fits you best:

- Star or share the project to help other Apple-platform developers discover it.
- Use [GitHub Sponsors](https://github.com/sponsors/yangKJ) for ongoing support.
- Use Buy Me a Coffee, Alipay, or WeChat for a one-time show of support.

Support is never a paywall or an obligation. Harbeth remains available under the MIT License; sponsorship simply makes it easier to give platform changes, regressions, and difficult edge cases the attention they deserve.

<a href="https://www.buymeacoffee.com/yangkj3102">
  <img width="180" alt="Buy me a coffee" src="https://user-images.githubusercontent.com/1888355/146226808-eb2e9ee0-c6bd-44a2-a330-3bbc8a6244cf.png">
</a>

<a href="https://github.com/sponsors/yangKJ">
  <img alt="GitHub Sponsors" src="https://img.shields.io/badge/GitHub-Sponsors-blue?style=for-the-badge">
</a>

For one-time support via Alipay or WeChat:

<p align="left">
  <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/WechatIMG1.jpg" width="220" alt="Alipay support QR code">
  <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/WechatIMG2.jpg" width="220" hspace="15" alt="WeChat support QR code">
</p>

Maintainer: [yangKJ](https://github.com/yangKJ) · [yangkj310@gmail.com](mailto:yangkj310@gmail.com)

## License

Harbeth is available under the [MIT License](LICENSE).
