# Changelog

Harbeth 的公开变更从本文件建立后开始记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性和重要修复，不复制内部提交历史。

## [Unreleased]

### Added

- Added `HarbethRenderView`, a SwiftUI texture-first host for `MTLTexture` and `RenderedFrame` that reuses Harbeth's `RenderView` preview substrate.
- Added opt-in structured logging through `HarbethLogger`, including stable diagnostic codes, outcomes, origins, metadata and correlation identifiers, plus a privacy-safe `HarbethSupportSnapshot` for Issue reports.
- Added an external-import public API smoke-test target and user-facing Issue templates.
- Added an `ImageNode` masked-effect composite entry point that reuses the same pixel-exact primitive as local edit recipes.
- Added angular, diamond, reflected, band, ring, and multi-stop mask gradient primitives with deterministic graph fingerprints.
- Added pressure-aware open brush masks, luminance/color range masks, generic texture-channel mask sources, and single-channel mask storage formats.
- Added compiled derived-mask graphs for threshold, grow/shrink, edge bands, distance fields, edge-aware feathering, cleanup, and decontamination, with cancellation, caching, GPU analysis, and dirty bounds.
- Added compiled composite-mask batches that preserve ordered add, subtract, intersect, XOR, inversion, opacity, and feather semantics while processing up to four mask layers per GPU pass.

### Fixed

- Fixed real-time command-buffer delivery so enabling performance monitoring no longer changes the callback boundary; output is delivered only after Metal schedules the work.
- Kept scheduled-only real-time delivery texture-first; image and pixel-buffer outputs now wait for GPU completion before CPU readback.
- Moved `ImageNode.transmitFrame(...)` and `makeFrameAsync(...)` onto the render operation queue so their asynchronous contract no longer performs synchronous rendering on the caller.
- Fixed missing Metal-function lookup crashing Debug builds instead of returning `HarbethError.readFunction`.
- Fixed mutable runtime registries and caches that were unsafe under Swift 6 concurrency checks.
- Fixed derived-mask cache collisions when identical graphs use different guide textures.

### Changed

- Raised the supported baseline to iOS/iPadOS 15, macOS 12 and tvOS 15, with Swift 6 as the package and project language mode.
- Made throwing `output()` the canonical `HarbethIO` integration surface.
- Exposed render-profile configuration publicly and documented `transmitOutput(...)` as the corresponding asynchronous `HarbethIO` surface.
- Kept Combination filters and the `RenderView` / preview-host substrate in public Harbeth as reusable render-engine capabilities.
- Isolated `C7View` image-capture helpers to `MainActor`, matching UIKit's actual threading contract.

### Removed

- Removed watchOS support from the published platform contract.
- Removed deprecated typo aliases, legacy runtime accessors, the unsafe `Outputable` generic extension, `C7CombinationBase` and the transitive `AVFoundation` re-export instead of carrying them into the new major baseline.
- Removed the global `R.width` / `R.height` main-screen shortcuts; layout code should derive size from its actual container.

[Unreleased]: https://github.com/yangKJ/Harbeth/compare/2.0.1...HEAD
