# Harbeth Maintaining Guide

Harbeth is maintained as an Apple-platform GPU image and frame processing core. Camera and video examples are supported integration demos, but the library should not absorb full camera session, recording, timeline editing, or export product responsibilities.

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

## Issue Triage

- Reproduce with the smallest input type first: `CGImage`, `MTLTexture`, `CVPixelBuffer`, then `CMSampleBuffer`.
- For camera/video issues, record pixel format, dimensions, bytes per row, platform, device/simulator, and whether the output texture is `.managed`, `.shared`, or private.
- For transparent or blank output, inspect alpha bytes after `MTLTexture.c7.toCGImage()` and verify macOS managed texture synchronization before CPU readback.

## Demo Policy

- Keep the SwiftUI Demo first screen scenario-oriented with Showcase entries.
- Keep the full filter list available as examples; do not hide low-level filter controls.
- Camera and video demos should remain reference integrations that show how to wire frame sources into Harbeth.

## Release Checklist

- `Package.swift` builds with SwiftPM and exposes the `Harbeth` library target.
- `Harbeth.podspec` includes Swift sources and `.metal` resources.
- `Device.makeFrameworkLibrary` can load or compile the Harbeth Metal library in SwiftPM.
- README.md and README_CN.md describe the same positioning and integration boundary.
- Open issues are either fixed, reproduced with notes, or explicitly marked as needing more reporter detail.
