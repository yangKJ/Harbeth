# Changelog

Harbeth 的公开变更从本文件建立后开始记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性和重要修复，不复制内部提交历史。

## [Unreleased]

### Added

- Added a depth-aware 2.5D scene-relighting primitive with up to three point, spot, directional or rim lights, explicit linear-RGB/HDR/alpha contracts, confidence-aware fallback, and contextual depth-plane binding for region renderers.
- Added generation-safe derived GPU resource governance for output-contract textures, derived masks, and 3D LUTs, with shared byte/count budgets, LRU eviction, namespaces, targeted invalidation, stale-write rejection, diagnostics, and memory-pressure cleanup.
- Added host-configured Metal binary archives for compute and render pipelines, including memory-only warmup, explicit persistence, reload diagnostics, and clean disabled fallback.
- Added true single-dispatch pointwise fusion for ordered brightness, contrast, saturation, exposure, gamma, and opacity chains, with conservative barriers around unsupported kernels.
- Added request-level GPU resource budgets with compile-time admission, typed violations, fail-fast execution, allocator-observed allocation/reuse reports, and frame metadata traceability.
- Added request-level preview/export parity signatures and structured visual-versus-delivery mismatch reports, with the evaluated parity fingerprint propagated to rendered-frame metadata.
- Added a unified kernel pixel contract covering color, alpha, precision, dynamic-range behavior, sampling footprint, global dependencies, CPU readback and pass-fusion eligibility, with graph-level coverage diagnostics.
- Added source color-profile identity propagation and deterministic final-output quantization with ordered or interleaved-gradient dithering before integer pixel-format conversion.
- Added GPU-only luminance waveform, RGB waveform and vectorscope analysis attachments with deterministic density visualization and no source-pixel CPU readback.
- Rebuilt 3D `.cube` LUT handling with strict domain-aware parsing, cached native 3D textures, stable resource identity, and trilinear or tetrahedral interpolation.
- Added real `MTLHeap` texture allocation with capability fallback, bounded heap arenas, descriptor-safe reuse, lease ownership, memory-pressure cleanup, and observable reserved/used/fallback statistics.
- Added explicit mipmap, CPU-cache, hazard-tracking, and honored storage-mode options for runtime-created textures.
- Added a Harbeth 3.0 migration guide and post-3.0 public API breakage gate.
- Added `HarbethRenderView`, a SwiftUI texture-first host for `MTLTexture` and `RenderedFrame` that reuses Harbeth's `RenderView` preview substrate.
- Added opt-in structured logging through `HarbethLogger`, including stable diagnostic codes, outcomes, origins, metadata and correlation identifiers, plus a privacy-safe `HarbethSupportSnapshot` for Issue reports.
- Added an external-import public API smoke-test target and user-facing Issue templates.
- Added an `ImageNode` masked-effect composite entry point that reuses the same pixel-exact primitive as local edit recipes.
- Added angular, diamond, reflected, band, ring, and multi-stop mask gradient primitives with deterministic graph fingerprints.
- Added pressure-aware open brush masks, luminance/color range masks, generic texture-channel mask sources, and single-channel mask storage formats.
- Added `MaskPlane` as the explicit coverage contract for coordinate space, source transforms, sampling, storage, resource identity, generations, revisions, and modified bounds.
- Added a persistent incremental GPU mask canvas with dirty-rectangle encoding, pressure, flow, density, paint/erase modes, generation safety, cancellation, and unbounded chunked centerlines.
- Added area-preserving coverage resampling, signed-distance edge shift and asymmetric feathering, MPS guided matte refinement, true foreground-color decontamination, topology inspection/cleanup, auxiliary scalar masks, and single-frame flow warping.
- Added compiled derived-mask graphs for threshold, grow/shrink, edge bands, distance fields, guided feathering, edge contraction, and cleanup, with cancellation, resource-aware caching, GPU analysis, halo planning, and dirty-region diagnostics.
- Added a public persistent/transient execution policy for derived masks without exposing cache implementation objects.
- Added composable mask expression DAGs with common-subexpression reuse, intermediate-memory diagnostics, and allocator/heap strategy reporting.
- Added compiled composite-mask batches that preserve ordered add, subtract, intersect, XOR, inversion, opacity, and feather semantics while processing up to four mask layers per GPU pass.

### Fixed

- Fixed long, narrow brush centerlines dropping their tail after the 512-point GPU budget, and preserved off-canvas context for tile-based rendering.
- Fixed subpixel brush widths disappearing between pixel centers by applying pixel-footprint-aware edge coverage.
- Fixed texture-pool aliasing across incompatible usage, storage, sample-count, texture-type, mipmap, array/depth, CPU-cache, and hazard-tracking contracts.
- Fixed ordinary runtime textures creating mipmap chains by default and consuming avoidable GPU memory.
- Fixed persistent image-resolution cache eviction being count-only by adding a byte-budgeted LRU and system memory-pressure cleanup.
- Fixed performance monitoring reporting command submission wall time as GPU time; metrics now use Metal's completed command-buffer GPU timestamps and track in-flight operations.
- Fixed realtime benchmark first-frame and dropped-frame metrics, and removed hundreds of simultaneously resident benchmark input buffers.
- Replaced deprecated Core Video attachment access with the retained copy API required by the 3.0 platform baseline.
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
