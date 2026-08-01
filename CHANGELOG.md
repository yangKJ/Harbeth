# Changelog

Harbeth 的公开变更按时间倒序记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性、性能特征和重要修复，不复制内部提交、测试或维护流水。

`Unreleased` 跨越了一次 major-version 重构，因此按实际完成日期拆成可审阅的交付批次；每个批次内部仍按 Added、Changed、Fixed、Removed 分类。正式发版时，这些批次会整体归入对应版本章节。

## [Unreleased]

> Target: Harbeth 3.0.0. This is a breaking upgrade from 2.x; read the [3.0 migration guide](docs/MIGRATION_3_CN.md) before adopting it.

### Upgrade at a glance

- Established two public integration routes: `HarbethIO` for direct source-to-output processing and `ImageNode` for structured editing, geometry, optics, masks, transitions, composition, inspection and delivery.
- Raised the supported baseline to iOS/iPadOS 15, macOS 12 and tvOS 15 with Swift 6, and removed watchOS plus obsolete 2.x compatibility surfaces.
- Added explicit color, alpha, YUV, HDR, output, resource-budget and diagnostics contracts so preview, export and frame delivery can be reasoned about before rendering.
- Added a production mask runtime, lazy render graph, frame/attachment delivery, analysis, preview hosting, advanced geometry and opt-in heap-backed resource management without expanding the public workflow beyond `HarbethIO` and `ImageNode`.

### Change scope

The unreleased 3.0 work below was reconstructed from all 126 commits after baseline `88270fca` (`origin/master` at the time of review), covering 2026-06-20 through 2026-07-31. The final tree delta is 520 files, 82,730 insertions and 9,284 deletions.

The [Unreleased] compare link starts at `2.0.1`, so it also contains `88270fca`, an earlier GitHub Linguist attribution-only commit with no compiled runtime impact. The 126-commit and 520-file figures intentionally describe the actual unpushed range `origin/master..HEAD`.

| Area | Files changed | Insertions | Deletions | Scope represented below |
| --- | ---: | ---: | ---: | --- |
| Library source | 358 | 44,260 | 6,542 | IO, outputs, ImageNode, graph, kernel, masks, runtime, filters, geometry, analysis and preview hosts |
| Tests | 70 | 27,785 | 0 | Public API, IO/frame, graph, cache, mask, color/HDR, geometry, performance and resource-governance contracts |
| Demos | 71 | 7,836 | 1,254 | UIKit, SwiftUI and AppKit showcases, camera-frame reference wiring and validation workbenches |
| Documentation | 12 | 2,552 | 1,401 | README, DocC, migration, API surface, capability map, troubleshooting and maintenance guidance |
| Build and release | 6 | 252 | 46 | SwiftPM/CocoaPods/Xcode baselines, CI, Issue intake and public API compatibility gates |
| Other repository files | 3 | 45 | 41 | Repository metadata and non-runtime support files |

Within the 358 source files, the largest areas are 154 filter/GPU-primitive files, 50 runtime/setup files, 30 ImageNode/graph/kernel files, 26 mask files, 17 geometry/render files, 10 IO/output files, 7 analysis files, 4 SwiftUI-host files and 60 supporting protocol/extension/matrix/resource files. Pure tests, CI-only work, documentation-only commits and file moves were audited but are not presented as standalone product features.

Commit coverage is 126/126: 118 implementation or developer-experience commits are represented in the dated sections, while 8 supporting commits were reviewed but intentionally folded into adjacent entries instead of being misrepresented as product features:

- Documentation-only: `c686aaa4`, `bcf67a30`, `fcffdd65`.
- Test-only: `b738e49c`, `88b5a472`, `19fa980d`.
- Directory-only reorganization: `52618303`.
- CI and maintenance governance: `9d670c5d`.

### Capability index

| Capability area | What changed | Main milestones |
| --- | --- | --- |
| Public integration | Two-route model, canonical sync/async IO, structured ImageNode editing and 3.0 migration surface | 2026-06-21, 2026-06-23, 2026-07-08, 2026-07-21 |
| Sources, frames and outputs | Image/texture/pixelBuffer/sampleBuffer/data/asset inputs, YUV planes, HDR metadata, output attachments and encode-only interop | 2026-06-21–24, 2026-07-08–09, 2026-07-31 |
| Graph, kernel and execution | Lazy graph, deferred requests, diagnostics, kernel identity/constants, plan caching, fusion, binary archives and resource admission | 2026-06-21, 2026-06-27–29, 2026-07-28 |
| Masks and local effects | Gradient/shape/path/range/brush masks, composite batching, tiled graphs, persistent canvas, expressions and derived-mask runtime | 2026-06-20–23, 2026-07-08, 2026-07-19–21, 2026-07-28 |
| Color, HDR and LUT | Color/alpha contracts, transfer and gamut conversion, tone mapping, quantization, scopes, 3D LUTs and HDR image precision | 2026-06-21–22, 2026-07-09, 2026-07-23, 2026-07-28–31 |
| Geometry and optics | Structured transforms, perspective/upright, quad/projective/cylindrical canvases, ROI and lens/image corrections | 2026-06-21, 2026-07-09–10, 2026-07-15 |
| Runtime and resources | Shared context, texture pools, cache identity, ownership, real MTLHeap allocation, budgets, eviction and memory pressure | 2026-06-21–29, 2026-07-15, 2026-07-28 |
| Inspection and support | Histogram/statistics/probes, attachment analysis, preview parity, structured logging and privacy-safe support snapshots | 2026-06-22–24, 2026-07-23, 2026-07-28 |
| Developer experience | Showcase-oriented Demos, DocC/API/migration/troubleshooting docs, Issue templates and release compatibility checks | 2026-06-21–27, 2026-07-16–21, 2026-07-28 |

### 2026-08-01 — Runtime resource ownership and context migration

#### Added

- Added explicit execution generations and queue recovery through `HarbethContext`, plus resource-policy, texture-pool and cache diagnostics on the same supporting boundary.
- Added DocC guidance that separates host-facing runtime resources from Harbeth's concrete schedulers, pools, allocators and caches.

#### Changed

- Made `HarbethContext.shared` the single owner and public access point for process-lifetime Metal resources, Core Video texture caching, external Metal libraries and runtime recovery.
- Kept one stable `PerformanceMonitor` diagnostics service on `HarbethContext`; enable/disable now changes thread-safe state without replacing the monitor or taking the Context resource lock on every lookup.
- Migrated Harbeth sources, demos, tests and public examples away from retaining `Shared` or calling `Device` directly.
- Kept `Device` as an internal reference type with stable identity and moved command-queue ownership into a recoverable execution scheduler.

#### Fixed

- Invalidated compiled render plans when the texture allocation strategy changes, preventing plans from retaining allocator assumptions from the previous policy.

#### Removed

- Removed the internal `Cacheable` protocol and its Objective-C associated storage; `HarbethContext` now owns the Core Video texture cache directly.
- Removed the duplicate `Shared` facade completely, and removed `Device`, the raw command queue and concrete texture-pool ownership from the public API surface.

### 2026-07-31 — Frame interop, HDR image fidelity, scene relighting and mask correctness (4 commits)

#### Added

- Added RGB/RGBA SIMD conversion helpers for `C7Color` and SIMD2 bridges for normalized and unclamped point types.
- Added `encodeAttachmentSet(...)` for encoding multi-attachment output into a caller-owned, same-device, retained-reference Metal command buffer without implicit submission or waiting, allowing subsequent GPU work to stay in the same batch.
- Added `C7SceneRelight`, a depth-aware 2.5D relighting primitive with up to three point, spot, directional or rim lights, explicit linear-RGB/HDR/alpha contracts, confidence-aware fallback and region-rendering depth-plane binding.

#### Fixed

- Preserved 16-bit and 32-bit floating-point precision when loading or reading back HDR `CGImage` content instead of silently narrowing it to 8-bit image IO.
- Propagated inferred high-precision image formats through source descriptors so render planning and diagnostics reflect the actual HDR input contract.
- Kept `MaskPlane` storage diagnostics aligned with the actual texture format and honored explicit sampling-contract changes even when the requested extent is unchanged.
- Made incremental mask painting and erasing coverage-monotonic, skipped zero-flow or zero-density false revisions, and removed low-flow seams across multi-kernel brush batches.

### 2026-07-28 — Production runtime, professional masks and GPU governance (14 commits)

#### Added

- Added generation-safe derived GPU resource governance for output-contract textures, derived masks and 3D LUTs, with shared byte/count budgets, LRU eviction, namespaces, targeted invalidation, stale-write rejection, diagnostics and memory-pressure cleanup.
- Added host-configured Metal binary archives for compute and render pipelines, including memory-only warmup, explicit persistence, reload diagnostics and a clean disabled fallback.
- Added true single-dispatch pointwise fusion for ordered brightness, contrast, saturation, exposure, gamma and opacity chains, with conservative barriers around unsupported kernels.
- Added request-level GPU resource budgets with compile-time admission, typed violations, fail-fast execution, allocator-observed allocation/reuse reports and frame-metadata traceability.
- Added `RenderResourceBudget`, `RenderResourceEstimate`, admission results and `RenderResourceReport` so texture count/bytes, allocator reuse and heap-backed allocation decisions are observable per request.
- Added request-level preview/export parity signatures and structured visual-versus-delivery mismatch reports, with the evaluated parity fingerprint propagated to rendered-frame metadata.
- Added a unified kernel pixel contract covering color, alpha, precision, dynamic-range behavior, sampling footprint, global dependencies, CPU readback and pass-fusion eligibility, with graph-level coverage diagnostics.
- Added `KernelPixelContract` coverage reporting so custom filters can declare tile, HDR, alpha, precision and fusion safety instead of relying on name-based inference.
- Added source color-profile identity propagation and deterministic final-output quantization with ordered or interleaved-gradient dithering before integer pixel-format conversion.
- Added GPU-only luminance waveform, RGB waveform and vectorscope analysis attachments with deterministic density visualization and no source-pixel CPU readback.
- Rebuilt 3D `.cube` LUT handling with strict domain-aware parsing, cached native 3D textures, stable resource identity and trilinear or tetrahedral interpolation.
- Added opt-in, real `MTLHeap` texture allocation with capability fallback, bounded heap arenas, descriptor-safe reuse, lease ownership, memory-pressure cleanup and observable reserved/used/fallback statistics.
- Added heap allocation diagnostics for reserved bytes, used bytes, active arenas, fallback allocations, reuse hits and memory-pressure cleanup without exposing heap ownership as a new public workflow.
- Added explicit mipmap, CPU-cache, hazard-tracking and honored storage-mode options for runtime-created textures.
- Added `MaskPlane` as the explicit mask-coverage contract for coordinate space, source transforms, sampling, storage, resource identity, generations, revisions and modified bounds.
- Added a persistent incremental GPU mask canvas with dirty-rectangle encoding, pressure, flow, density, paint/erase modes, generation safety, cancellation and unbounded chunked centerlines.
- Added composable mask-expression DAGs with common-subexpression reuse, intermediate-memory diagnostics and allocator/heap strategy reporting.
- Added expression planning for ordered add, intersection, subtraction, exclusion, inversion and opacity while reusing common subexpressions and rejecting stale generation writes.
- Added compiled derived-mask graphs for threshold, grow/shrink, edge bands, distance fields, guided feathering, edge contraction and cleanup, with cancellation, resource-aware caching, GPU analysis, halo planning and dirty-region diagnostics.
- Added a public persistent/transient execution policy for derived masks without exposing cache implementation objects.

#### Fixed

- Preserved complete long brush paths beyond the 512-point GPU segment budget and retained off-canvas context for tiled rendering.
- Prevented subpixel brush widths from disappearing between pixel centers by using pixel-footprint-aware edge coverage.
- Prevented texture-pool aliasing across incompatible usage, storage, sample-count, texture-type, mipmap, array/depth, CPU-cache and hazard-tracking contracts.
- Stopped ordinary runtime textures from creating mipmap chains by default and consuming avoidable GPU memory.
- Replaced count-only persistent image-cache eviction with a byte-budgeted LRU and system memory-pressure cleanup.
- Corrected performance monitoring to use completed Metal command-buffer GPU timestamps instead of reporting command-submission wall time as GPU time.
- Corrected realtime benchmark first-frame and dropped-frame metrics and removed hundreds of simultaneously resident benchmark input buffers.

### 2026-07-23 — Professional color processing and support diagnostics (2 commits)

#### Added

- Added professional color-grading, selective-HSL and whites/blacks primitives with explicit parameter ranges and kernel contracts.
- Added structured diagnostic errors, stable diagnostic codes, outcomes, origins, metadata and correlation identifiers through opt-in `HarbethLogger` logging.
- Added a privacy-safe `HarbethSupportSnapshot` and user-facing Issue templates to make integration failures reproducible.

#### Fixed

- Changed missing Metal-function lookup from a Debug-build crash into a typed `HarbethError.readFunction` failure.
- Hardened mutable runtime registries and caches for Swift 6 concurrency checks.

### 2026-07-21 — Public 3.0 baseline and masked-effect entry point (3 commits)

#### Added

- Added a Harbeth 3.0 migration guide, DocC contract documentation and a post-3.0 public API breakage gate.
- Added public API-surface, capability-map, custom-filter, filter-catalog and troubleshooting documentation aligned to the two-route model.
- Added `HarbethRenderView`, a SwiftUI texture-first host for `MTLTexture` and `RenderedFrame` that reuses Harbeth's `RenderView` preview substrate.
- Added an `ImageNode` masked-effect composite entry point that reuses the same pixel-exact primitive as local edit recipes.

#### Changed

- Raised the supported baseline to iOS/iPadOS 15, macOS 12 and tvOS 15, with Swift 6 as the package and project language mode.
- Made throwing `output()` the canonical synchronous `HarbethIO` integration surface and documented `transmitOutput(...)` as its same-level asynchronous counterpart.
- Exposed render-profile configuration publicly while keeping Runtime, Graph, Kernel, Analysis and Recipe families as supporting layers rather than additional user routes.
- Kept Combination filters and the `RenderView` / preview-host substrate in public Harbeth as reusable render-engine capabilities.
- Isolated `C7View` image-capture helpers to `MainActor`, matching UIKit's actual threading contract.

#### Removed

- Removed watchOS from the published platform contract.
- Removed deprecated typo aliases, legacy runtime accessors, the unsafe `Outputable` generic extension, `C7CombinationBase` and the transitive `AVFoundation` re-export instead of carrying them into the new major baseline.
- Removed the global `R.width` / `R.height` main-screen shortcuts; layout code must derive size from its actual container.

#### Fixed

- Replaced deprecated Core Video attachment access with retained copy APIs required by the 3.0 platform baseline.
- Isolated derived-mask cache entries by guide-texture identity so identical graphs cannot reuse results produced from a different guide.

### 2026-07-20 — Compiled mask graphs and tiled execution (3 commits)

#### Added

- Added pressure-aware open brush masks, luminance/color range masks, generic texture-channel mask sources and single-channel mask storage formats.
- Added `MaskBrushRecipe`, `MaskRangeRecipe`, `MaskTextureRecipe`, `MaskMorphologyRecipe`, `MaskDistanceFieldRecipe` and reusable mask-analysis results as composable public primitives.
- Added area-preserving coverage resampling, signed-distance edge shift and asymmetric feathering, MPS guided matte refinement, foreground-color decontamination, topology inspection/cleanup, auxiliary scalar masks and single-frame flow warping.
- Added foreground-color decontamination controls and matte refinement policies that keep coverage correction separate from product-level subject-selection strategy.
- Added compiled composite-mask batches that preserve ordered add, subtract, intersect, XOR, inversion, opacity and feather semantics while processing up to four mask layers per GPU pass.
- Added tile-aware mask-graph execution with halo planning, regional diagnostics and semantics consistent with full-frame rendering.
- Added full-frame fallback reporting for mask operations whose global dependency or sampling footprint cannot be evaluated safely inside a tile.

### 2026-07-19 — Path-mask coordinate and feathering contracts (1 commit)

#### Added

- Added explicit path-mask coordinate-space handling and scale-aware feathering so normalized, pixel and transformed paths remain stable across output sizes.

### 2026-07-15 — Region-aware rendering and source fidelity (10 commits)

#### Added

- Added shared region-coordinate and texture-mapping contexts for compute and distortion filters, including mapped source/output rectangles and tile-aware sampling.
- Added `TextureMappingContext` propagation through crop, rotate, transform, morphology and distortion families so normalized coordinates can be resolved against the logical full canvas rather than an isolated tile.
- Restored `CIImage` as a supported source while keeping Core Image filters outside the Harbeth execution model.
- Added Metal-backed `CIImage` source loading with finite-extent validation and preservation of source color/orientation metadata.

#### Fixed

- Fixed transformed mask paths being clipped at their pre-transform bounds and corrected rotations on non-square canvases.
- Fixed region-aware coordinates for legacy filters so tiled execution matches the full-frame result.
- Hardened command-buffer, texture-owner and cache lifetimes across deferred, asynchronous and preview delivery.
- Fixed borrowed plane textures, pooled outputs and deferred command buffers outliving or releasing their true owners at the wrong execution boundary.

### 2026-07-10 — ROI execution and advanced canvas geometry (4 commits)

#### Added

- Added a complete region-of-interest foundation with propagation, halo expansion, full-frame fallback and diagnostics for graph and multi-pass execution.
- Added `TextureRegionRect`, `TextureRegionContext`, `SamplingFootprint`, texture pyramids and multi-pass execution helpers for filters whose output region depends on neighboring pixels.
- Added mask morphology, grow/shrink, edge-band and distance-field recipes on top of the same ROI/halo contract.
- Added composition anchors, quad transforms and quad rectification for structured placement and perspective workflows.
- Added explicit projective and cylindrical canvas renderers with transparent out-of-bounds behavior and independent coverage attachments.
- Added `.coverage` attachments for projective/cylindrical geometry so callers can inspect valid canvas area independently from the rendered color output.

### 2026-07-09 — HDR delivery, optics and preview telemetry (4 commits)

#### Added

- Added HDR/EDR output contracts, PQ and HLG transfer handling, explicit tone-mapping policies and display-oriented SDR/P3 output presets.
- Added `hdrPQTexture`, `hdrHLGTexture` and `toneMappedDisplayP3Texture` output presets while preserving explicit working/output gamut, transfer, alpha and pixel-format decisions in frame metadata.
- Added structured optics recipes and lens profiles routed through `ImageNode.applying(optics:)`.
- Added lens-profile builders for distortion, chromatic-aberration, vignette, defringe, diffraction and sharpness-falloff correction without turning optics into a separate runtime route.
- Added preview-host telemetry and runtime hints for frame visibility, fallback behavior and host diagnostics.

#### Fixed

- Hardened realtime Demo delivery, cancellation and frame ordering without moving camera, player or recording ownership into Harbeth.

### 2026-07-08 — Unified IO, frame bridges, masks and plugin boundary (8 commits)

#### Added

- Added structured gradient, shape, path, brush, range, texture-channel and composite mask primitives with deterministic graph fingerprints and reusable descriptors.
- Added mask component selection, invert, opacity, feather, blend and ordered add/intersect/subtract/exclude composition contracts.
- Added plugin-boundary types that let external capabilities return filters, recipes, local effects, layer composites or textures while execution remains on the `ImageNode` route.
- Added sampler-adaptation contracts shared by filtering, editing, transitions and composition.
- Added source/loading contracts for encoded data and `ImageAsset`, including source tier, intended role/purpose, loading options and stable cache behavior.

#### Changed

- Routed structured editing through `ImageNode` and refined runtime IO so direct work stays on `HarbethIO` while frame, metadata, request and recipe workflows stay on `ImageNode`.
- Unified `ImageNode` instance-chain entry points for editing, geometry, optics, transition and layer composition, retaining static factories only for callers that begin with an `ImageSource`.
- Made sampler execution coverage observable when legacy compute geometry or optics can only honor part of a requested sampling contract.

#### Fixed

- Preserved sample timing, attachments, source identity, alpha and YUV decode contracts across `CVPixelBuffer` / `CMSampleBuffer` frame bridges.
- Normalized `UIImage` orientation during texture loading and readback instead of allowing orientation metadata to diverge from rendered pixels.
- Fixed frame recipes and diagnostics degrading pixel-buffer/sample-buffer sources into anonymous intermediate textures after decoding.

### 2026-06-29 — Render-plan cache correctness (1 commit)

#### Fixed

- Fixed cached render plans retaining stale mutable filter state by separating stable plan identity from per-execution filter values.

### 2026-06-28 — First-frame startup reliability (1 commit)

#### Fixed

- Removed the eager Metal source-fallback scan that could stall the first rendered frame; fallback resolution is now lazy and observable.

### 2026-06-27 — Advanced routes, transitions and pixel-buffer output (7 commits)

#### Added

- Added complete `ImageNode` advanced-route coverage for structured recipes, transitions, layer composition, masks, diagnostics and delivery contracts.
- Added reusable custom transition primitives and a Showcase-oriented Demo presentation while preserving the complete sample catalog.
- Added advanced-route result bundles that expose frame, diagnostics, graph, request and analysis from the same effective node contract.
- Added UIKit validation workbenches and a unified Bento/Glass/Dark Demo navigation system for discovering ImageNode, masks, transitions and the full filter catalog.

#### Changed

- Tightened `ImageNode` planning so the public node remains the source of truth while render plans, cached execution and diagnostics use immutable derived descriptions.

#### Fixed

- Fixed `HarbethIO` pixel-buffer rematerialization so requested output buffers receive rendered pixels instead of stale source storage.
- Fixed transition endpoint continuity so progress 0 and 1 reproduce their respective input frames exactly.
- Fixed advanced routes losing observability or output metadata when execution crossed recipe, layer, mask or deferred-request boundaries.

### 2026-06-24 — Preview-host substrate and cache identity (6 commits)

#### Added

- Added reusable frame-host metadata, preview runtime hints and an internal sample-buffer fallback substrate for texture/frame hosts.
- Added preview decisions for texture-host, sample-buffer passthrough and sample-buffer rematerialization paths, with visible fallback/recovery telemetry rather than silent host switching.
- Added source and replay metadata that let preview hosts preserve orientation, timing, cache identity and original frame semantics while displaying an already-rendered texture.

#### Changed

- Improved `RenderView` sizing, invalidation and host metadata handling while keeping preview hosting inside Harbeth's frame-output boundary.
- Kept `RenderView` and `SampleBufferPreviewHost` texture/frame-first: Harbeth provides display substrate and frame metadata but does not take ownership of capture sessions, players or timelines.

#### Fixed

- Fixed image-source cache fingerprints so distinct source content cannot collide when render plans or frames are replayed.
- Fixed replayed frame requests losing the final node's source, derivative and output contract after intermediate texture materialization.

### 2026-06-23 — ImageNode orchestration, local effects and plugins (11 commits)

#### Added

- Added the `ImageNode` plugin bridge foundation and unified frame-first local-effect rendering with mask-aware composition.
- Added plugin outputs for direct textures, filter chains, edit recipes, local effects and layer-composite recipes, all lowered back into existing `ImageNode` execution instead of creating a separate plugin renderer.
- Added `ImageNode` convenience routes for applying one or many filters inside gradient, shape, path, composite or texture masks.

#### Changed

- Unified editing, mask, transition, layer and filter-pipeline orchestration under `ImageNode`, with instance-chain entry points for existing nodes.
- Consolidated filter and Combination pipeline application so direct, recipe and node routes share the same intensity and ordered-execution semantics.
- Internalized editing implementation filters and kept recipes as public description primitives rather than parallel execution APIs.
- Renamed the masked foreground blend primitive and removed duplicate XOR-specific implementation paths while preserving public mask-composite behavior.

#### Fixed

- Closed synchronous, callback, task and async execution-contract gaps across `ImageNode` and `HarbethIO`.

### 2026-06-22 — Analysis, attachments and color/YUV contracts (11 commits)

#### Added

- Added scoped texture analysis, deferred color probes, histograms, statistics and mask-aware analysis without creating a third public route.
- Added `TextureAnalysisScope` selectors for regions, masks, luminance ranges, RGB component ranges and named tone bands, reusable from textures, frames, attachments and deferred requests.
- Added `RenderedAnalysisBundle` and `RenderedAttachmentAnalysisBundle` with typed lookup, summaries, previews and JSON export for reproducible inspection.
- Added render attachment sets for luminance, mask coverage, clipping and other auxiliary outputs, plus attachment-level analysis.
- Added typed primary/auxiliary color, coverage, mask, luminance, histogram, analysis and debug attachment semantics, plus highlight/shadow clipping and false-color auxiliary render primitives.
- Added explicit color-space conversion, working/output color contracts, alpha contracts and attachment export semantics.
- Added native RGB color-space conversion and debanding primitives for controlled output preparation.
- Added direct bi-planar YCbCr plane bridges and fallback decoding with observable bridge diagnostics.
- Added linear, radial, angular, diamond, reflected, band, ring and multi-stop mask gradients plus rectangle, ellipse, rounded-rectangle, polygon, path and parametric composite-mask recipes.
- Added mask-aware histogram/statistics/probe operations that can derive the same selection as a reusable `MaskDescriptor` for subsequent local effects.

#### Fixed

- Preserved render color and source contracts through attachment, analysis and image readback paths.
- Preserved YCbCr matrix, primaries, transfer function, timing and source attachments through plane-based texture bridges and pixel-buffer rematerialization.

### 2026-06-21 — Harbeth 3.0 render-engine foundation (34 commits)

#### Added

- Added `ImageNode` as the advanced unified source, graph, editing, geometry, optics, mask, transition, composition, request, diagnostics and frame-delivery route.
- Added unified `ImageSource` cases for `C7Image`, `CGImage`, `CIImage`, `MTLTexture`, `CVPixelBuffer`, `CMSampleBuffer`, encoded `Data` and `ImageAsset`, preserving source tier, orientation, alpha, color and cache identity in descriptors.
- Added texture, image, frame, pixel-buffer and encoded PNG/JPEG/TIFF/HEIC delivery surfaces, with `RenderedFrame` retaining source, output, timing, host, replay and attachment metadata.
- Added render profiles for interactive latency, response latency, stable preview, inspection, export and CPU-readback workloads, plus generation tokens for rejecting stale frame results.
- Added lazy `ImageGraph` planning, conservative optimization, stable kernel identity, function constants, render-plan caching and debug snapshots.
- Added deferred `RenderRequest`, cancellable/observable `RenderTask`, graph DOT/JSON diagnostics, replay-base contracts and stable render-cache identities.
- Added reusable pixel-buffer output, output-quality profiles and explicit pixel-format/output-size contracts.
- Added structured `EditRecipe` and `ImageTransformRecipe` support for crop regions, fit/fill sizing, anchored output, rotate, mirror, flip, perspective, guided upright and explicit canvas policies.
- Added single-frame layer composition with ordered layers, transforms, opacity, blend modes, programmable blend functions, masks, corner curves, tint and layer-local filter chains.
- Added transition recipes with explicit from/to sources, progress, kernel identity, auxiliary textures, preview/final profiles and deterministic endpoint behavior.
- Added geometry and optics primitives for 3D transforms, lens distortion, chromatic aberration, vignette, defringe, diffraction and sharpness falloff.
- Added identity-aware image resolution caching and reusable runtime/context ownership through `Shared.shared`.
- Added native RGB transfer conversion, noise reduction, Lanczos resizing, chromatic-aberration, lens-distortion, diffraction, sharpness-falloff, defringe and lens-vignette correction primitives.
- Added native Metal replacements for the previously exposed Core Image filter wrappers and hardened Metal-library fallback resolution.
- Added reusable direct and fallback YCbCr pixel-buffer loading, plane bridge contracts and diagnostics for formats that cannot use a single packed Metal texture.

#### Changed

- Refocused the public model on `HarbethIO` for lightweight direct processing and `ImageNode` for advanced structured processing.
- Moved `ImageNode.transmitFrame(...)` and `makeFrameAsync()` onto the render operation queue so their asynchronous contract no longer renders synchronously on the caller.
- Reworked Combination filters as explicit reusable pipelines instead of product-level look or preset assets.

#### Removed

- Removed the public Core Image filter-wrapper family; `CIImage` remains an accepted source, but processing is performed by Harbeth's Metal runtime.

#### Fixed

- Fixed realtime command-buffer delivery so performance monitoring no longer changes callback timing; texture-first output is delivered only after Metal schedules the work.
- Ensured image and pixel-buffer outputs wait for GPU completion before CPU readback, while scheduled-only realtime delivery remains texture-first.
- Fixed reusable output textures, graph execution, kernel lookup, cache identity, allocator ownership and frame-source contract gaps found while making the new runtime executable.

### 2026-06-20 — Mask alpha correctness (1 commit)

#### Fixed

- Fixed synthetic mask inputs leaking unintended alpha into source-over composition.

## [2.0.1] - 2026-06-12

### Added

- Added `C7AdvancedMetalKernelProtocol` as a reusable abstraction for custom Metal execution with explicit capability checks, advanced encoding and compute fallback behavior.
- Added Metal capability reports for custom encoders, mesh shaders, MetalFX, Metal IO, dynamic libraries, function pointers, ray tracing and sparse textures, with explicit advanced-path availability and compute fallback behavior.

### Changed

- Optimized realtime processing and compute threadgroup sizing across the filter catalog.
- Expanded English and Chinese integration documentation and refreshed Demo examples.

### Fixed

- Fixed input/output texture misalignment during rendering.

## [2.0.0] - 2026-03-26

### Added

- Added render concurrency control, double-buffered processing, command-buffer pooling and expanded texture reuse for realtime workloads.
- Added `C7LocalBlur`, `C7TiltShift`, enhanced sharpen, sticker-outline, enhanced color-burn blend and masked XOR primitives.
- Added Apple Log decoding, channel control, clarity, enhanced color balance, color correction, curves, HSL, temperature, warmth and highlight/shadow tone controls.
- Added 1D and multi-zone LUT processing plus reusable color-grading, creative-atmosphere, cyberpunk, dreamy, film-simulation, HDR-boost and vintage-film Combination filters.
- Added basic render-pipeline filters and MPS Canny support alongside the compute-filter catalog.
- Added Codable support for reusable filter and parameter descriptions.
- Expanded iOS, macOS and SwiftUI Demos with camera, player, curves, HSL, channel, chroma-key and realtime examples.

### Changed

- Reworked the render/filter architecture, texture management and performance monitoring for lower allocation pressure and clearer execution ownership.
- Expanded texture-pool compatibility checks and command-buffer reuse to reduce allocation churn during repeated camera/video frame processing.
- Made shader math safe for HDR extended-range values and removed redundant `[0, 1]` output clamps where they destroyed valid HDR content.

### Fixed

- Fixed crashes and memory-lifetime issues in realtime processing.
- Fixed a priority inversion in the render pipeline.
- Fixed missing Metal resources, Apple Log decoding and Swift type-checker timeouts in `C7LuminanceThreshold`.

[Unreleased]: https://github.com/yangKJ/Harbeth/compare/2.0.1...HEAD
[2.0.1]: https://github.com/yangKJ/Harbeth/compare/2.0.0...2.0.1
[2.0.0]: https://github.com/yangKJ/Harbeth/compare/1.3.1...2.0.0
