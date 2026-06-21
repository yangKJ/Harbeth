# Harbeth Maintaining Guide

Harbeth is maintained as a multi-platform Apple GPU image and frame processing core across iOS, iPadOS, macOS, tvOS, and watchOS where the underlying APIs are available. Camera and video examples are supported integration demos, but the library should not absorb source acquisition policy, media orchestration, persistence, or other product workflow responsibilities.

## Maintenance Baseline

- Protect local work before editing: run `git status --short --branch` and inspect existing diffs.
- Keep changes scoped: core fixes, README/Demo packaging, release configuration, and tests should be committed as separate slices when they are independently verifiable.
- Never commit local agent folders, caches, build products, logs, credentials, or generated context bundles.
- Do not push from automation; maintainers push manually.

## Verification Commands

Use the Xcode toolchain explicitly when another Swift toolchain shadows it:

```bash
env CLANG_MODULE_CACHE_PATH=.build/ModuleCache xcrun swift build
env CLANG_MODULE_CACHE_PATH=.build/ModuleCache xcrun swift test
```

CocoaPods release checks:

```bash
pod lib lint Harbeth.podspec
```

If CocoaPods is unavailable, run a static podspec review and verify that Swift sources and Metal resources are still included.

Platform checks:

- Validate SwiftPM on macOS because it is the fastest host-side build and test loop.
- Validate the Demo through `Harbeth.xcworkspace` for iOS Simulator before release.
- Treat macOS-only texture synchronization tests as regression coverage, not as the full platform boundary.
- Keep iOS/iPadOS behavior first-class when changing camera frame, `CVPixelBuffer`, `CMSampleBuffer`, UIKit, SwiftUI, or video playback/export paths.

Execution contract checks:

- When touching `EditRecipe`, `LocalEffectRecipe`, or `TransitionRecipe`, run the focused recipe, mask, transition, and rendered-frame tests before broader verification.
- When touching `HarbethImageNode`, `HarbethKernelDescriptor`, `LayerCompositeRecipe`, or `RenderOutputContract`, run the node graph tests and verify that diagnostics still explain compilation source, optimizer decisions, and output contract fields.
- Treat `RenderPlanDiagnostics`, `RenderStage`, and `RenderedFrame` metadata as stable contracts; if a field changes, update tests in the same slice.
- Treat `HarbethRenderTask` as a texture-first GPU execution contract. Changes to command-buffer status, completion observation, or task diagnostics should update `RenderTaskTests` and must not introduce camera, timeline, export, or media lifecycle policy.
- Treat `HarbethPixelBufferPool` and `renderPixelBuffer(...)` as single-frame output contracts. They may allocate reusable `CVPixelBuffer` render targets, but must not absorb recorder, exporter, timing, or sample scheduling responsibilities.
- Keep `RenderOptimizationPlan` conservative. It can report texture reuse, lifecycle decisions, persistent outputs, readback boundaries, and conversion decisions, but it must not silently change visual output or absorb product workflow policy.
- Treat `HarbethKernelDescriptor.fingerprint`, `HarbethKernelResourceDescriptor`, and `RenderOutputContract.fingerprint` as public technical contracts. New kernel metadata should be deterministic and testable.
- Treat `ImageColorSpaceContract`, `PixelFormatContract`, and `RenderOutputContract` as output-quality metadata, not product color strategy. Wide-gamut, transfer-function, and high-precision flags should remain deterministic diagnostics/planning inputs unless a real conversion filter is explicitly added and tested. `C7RGBTransferConversion` is intentionally limited to compatible sRGB/linear transfer pairs and requires an explicit source color contract.
- Pixel-format output contracts may materialize a target `MTLPixelFormat` through the texture-first execution path. Do not imply full color-space conversion unless an explicit color conversion filter is added and tested.
- Treat `HarbethKernelArgumentDescriptor` ordering, role, data type, and value fingerprint as shader-authoring contracts. Do not derive them from unstable dictionary iteration order.
- Treat `HarbethKernelLibrarySource` and `Device.readMTLFunction(_ identity:)` as shader lookup/cache identity. External provider identifiers and metallib URLs must remain technical source descriptors, not product asset or preset names.
- Treat identity-aware Metal function, compute pipeline, and render pipeline cache keys as kernel execution contracts. Function constants and library source must remain part of the cache identity, and `HarbethContext.resetCaches()` must reset these caches together.
- Treat `HarbethKernelFunctionConstantDescriptor` as shader specialization metadata. Function constants must participate in the function identity fingerprint and remain separate from product presets or style decisions.
- Treat `HarbethImageNode.withCachePolicy(_:)` as lazy graph execution metadata. It can influence diagnostics and conservative reuse planning, but must not become product-level cache orchestration.
- Treat `ImageSamplerDescriptor` as an image sampling contract and sampler-cache key. It should stay deterministic, inspectable, and independent from UI preview policy.
- Treat the `HarbethContext` image resolution cache as an in-memory lazy graph resolution cache only. Do not turn it into disk cache, asset library, export cache, or media lifecycle management.
- Keep image resolution cache hit/miss metrics technical. They explain lazy graph reuse and must not become product retention, asset, or media-session policy.
- Execution may use `RenderOptimizationPlan` to prewarm or reuse render targets, but optimizer decisions must remain explainable through diagnostics and covered by contract tests.
- Alpha output contracts may insert native premultiply or unpremultiply filters. Pixel format and color-space contract changes must be explicit and tested before becoming automatic conversions.
- Layer compositing belongs to single-frame texture composition only. Layer-local transforms and filter chains must participate in `ImageLayer` fingerprints because they affect cache identity and replay correctness. Do not add text engines, sticker libraries, timeline layers, or media orchestration to `LayerCompositeRecipe`.
- Be cautious with `CVPixelBuffer` and `CMSampleBuffer` paths when size, pixel format, or readback behavior changes; those bridges are more constrained than pure texture/image flows.

## Issue Triage

- Reproduce with the smallest input type first: `CGImage`, `MTLTexture`, `CVPixelBuffer`, then `CMSampleBuffer`.
- For camera/video issues, record pixel format, dimensions, bytes per row, platform, device/simulator, and whether the output texture is `.managed`, `.shared`, or private.
- For transparent or blank output, inspect alpha bytes after `MTLTexture.c7.toCGImage()`, verify pixel format and row stride on iOS/macOS frame sources, and check macOS managed texture synchronization before CPU readback when the storage mode requires it.

## Demo Policy

- Keep the SwiftUI Demo first screen scenario-oriented with Showcase entries.
- Keep the full filter list available as examples; do not hide low-level filter controls.
- Camera and video demos should remain reference integrations that show how to wire frame sources into Harbeth.

## Release Checklist

- `Package.swift` builds with SwiftPM and exposes the `Harbeth` library target.
- `Harbeth.podspec` includes Swift sources and `.metal` resources.
- The iOS Simulator Demo builds from `Harbeth.xcworkspace`; macOS host tests still pass.
- `Device.makeFrameworkLibrary` can load or compile the Harbeth Metal library in SwiftPM.
- README.md and README_CN.md describe the same positioning and integration boundary.
- Open issues are either fixed, reproduced with notes, or explicitly marked as needing more reporter detail.
