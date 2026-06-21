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
- Keep `RenderOptimizationPlan` conservative. It can report texture reuse and boundary decisions, but it must not silently change visual output or absorb product workflow policy.
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
