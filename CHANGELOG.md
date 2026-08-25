# Changelog

Harbeth 的公开变更按时间倒序记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性、性能特征和重要修复，不复制内部提交、测试或维护流水。

`Unreleased` 跨越了一次 major-version 重构，因此按实际完成日期拆成可审阅的交付批次；每个批次内部仍按 Added、Changed、Fixed、Removed 分类。正式发版时，这些批次会整体归入对应版本章节。

## [Unreleased]

> Target: Harbeth 3.0.0. This is a breaking upgrade from 2.x; read the [3.0 migration guide](docs/MIGRATION_3_CN.md) before adopting it.

### 2026-08-25

#### Changed

- Consolidated realtime pixel-buffer reuse, temporary CLAHE buffers, Metal fallback libraries and external-library provider state under the process-lifetime `HarbethContext` / internal `Device` owner boundary. Runtime cache reset, recovery and memory pressure now purge the applicable reusable resources without removing registered providers.
- `HarbethContext.coreImageContext` now initializes on first access and retains stable identity across execution recovery, avoiding Core Image setup for Metal-only runtime use.

#### Fixed

- Routed Harbeth-owned Mask GPU work through the recoverable context command-buffer path while keeping an explicit local queue fallback for textures owned by another Metal device.

### 2026-08-06

#### Added

- Added `TextureAnalysisValueRange` so histogram and image-scope callers can explicitly map HDR/EDR storage values without implicit tone mapping or transfer-function decoding.
- Added `encodeImageScope(_:into:)` for composing scope generation into a caller-owned Metal command buffer without submission or waiting.

#### Changed

- Kept `C7` for established platform adapters, geometry primitives and filter-development contracts, while removing it from unrelated public Metal capability and filter-configuration types. Use `MetalCapability`, `MetalCapabilityStatus`, `MetalCapabilityReport`, `DisplacementEncoding`, `DisplacementUnit`, `SceneLightKind`, `SceneLightDescriptor`, `SceneRelightDescriptor` and `SceneRelightDescriptorError`.
- Removed `RenderProfile.usesRealTimeCommit` from the public surface and stopped `HarbethIO.configured(for:)` from implicitly changing real-time delivery; `transmitOutputRealTimeCommit` is now the only public HarbethIO control for that behavior.
- Simplified `bufferPixelFormat` into the single source of truth: it is now optional, where `nil` preserves the source texture format and a value explicitly overrides it. The redundant setter-tracking state was removed.
- Removed mutable destination-allocation and double-buffer switches from `HarbethIO`; allocation now derives from `RenderProfile`, `bufferPixelFormat` and each filter's destination contract. `HarbethIO` remains the direct source-plus-filters-to-output entry point.
- Kept `HarbethIO.mirrored` public as the legacy explicit CIImage orientation correction; it is not an execution policy and has no replacement source-orientation contract yet.
- Replaced the broad advanced-Metal abstraction with `C7MetalCommandEncodingProtocol`, an opaque command-encoding escape hatch used only when standard filters and `C7FilterPipelineProtocol` cannot express the resource graph. External libraries and function constants now remain on ordinary Compute filters, including `C7ProgrammableBlend` and `LayerProgrammableBlend` without a capability parameter.
- Added `FilterDestinationTextureContract` and `DestinationTextureAliasingPolicy` to the common filter contract so Compute, Render, MPS, Blit and Metal-command filters can declare destination usage, storage mode and aliasing without changing execution category.
- Expanded CPU analysis readback to normalized 8-bit and `r` / `rg` / `rgba` 16-bit and 32-bit floating-point textures while preserving texture-storage component semantics.
- Reused Analysis readback work inside frame and attachment bundles, kept single-metric `RenderRequest` calls selective, reused the shared execution queue where possible, and normalized GPU scope density against a 1080p reference.

#### Fixed

- Fixed `ImageNode.makeAnalysisBundle` dropping mask, luminance, color-range and coverage inputs, and fixed `makeAttachmentAnalysis` ignoring an explicitly selected histogram channel.
- Fixed attachment-analysis summary fingerprints omitting histogram contents and statistic values.

- Preserved `transmitOutputRealTimeCommit` as the single public real-time submission switch while restoring its original texture-first meaning: enabled asynchronous texture output is delivered after command-buffer scheduling, while the default waits for GPU completion.
- Kept synchronous output and CPU-materialized image, pixel-buffer and sample-buffer results completion-safe even when real-time texture delivery is enabled.
- Kept managed output textures leased for the lifetime of synchronous direct-filter `ImageNode` frames, allowing texture-backed CIImage results to return their storage to the pool only after the frame and escaped image views are released.
- Enforced destination aliasing and output contracts across low-latency allocation, render-plan cache identity and multi-filter graph compilation, while preserving explicit in-place support for primitives that stage their own source safely.

#### Removed

- Removed the legacy `HarbethView` and `HarbethViewInput` SwiftUI image-readback bridge. Render work now belongs to `HarbethIO` or `ImageNode`, while `HarbethRenderView` remains the texture- and `RenderedFrame`-first output host. Keep any intentional static image readback local to the host UI.
- Removed direct public access to `HarbethIO.createDestTexture`, `HarbethIO.enableDoubleBuffer`, `HarbethIO.configured(for:)`, frame-capability construction, convenience fallback output, filter operators, and texture-backed CIImage frame delivery. Use `ImageNode` with a `RenderProfile` when structured execution is required; call `RenderedFrame.makeTextureBackedCIImage(for:)` for CIImage source-preserving delivery.
- Removed `PerformanceMonitor` and its configuration/metrics types from the public API. Hosts now use only `HarbethContext.enablePerformanceMonitor` to opt into internal diagnostics; benchmark and test consumers use the package's internal test surface.
- Removed `C7AdvancedMetalKernelProtocol`, `MetalCapability.customAdvancedEncoder` and the redundant custom-encoder-kind classification. Ordinary kernels remain on `C7FilterProtocol`, texture-only multi-pass work remains on `C7FilterPipelineProtocol`, and only non-standard command/resource graphs use `C7MetalCommandEncodingProtocol`.

### 2026-08-05 — macOS texture readback correctness, deterministic tone mapping and GPU filter primitives

#### Added

- Added `C7ToneMapping` for deterministic linear-RGB luminance mapping from explicit source nits into SDR or EDR output headroom, with preserved alpha and declared dynamic-range behavior.
- Added `C7DisplacementMap` for single-frame deformation from signed or normalized displacement textures, with pixel/normalized units, sampler and edge policies, optional confidence weighting and full-canvas coordinate semantics.
- Added `KernelDynamicRangeBehavior.toneMapsToEDR` so render planning can distinguish EDR-safe tone mapping from SDR clamping and HDR-preserving execution.
- Added `C7HighPassSkinSmoothing` as a full-frame high-pass detail-preserving smoothing pipeline, without claiming face or skin-region detection.
- Added `C7DocumentBinarization` for locally adaptive document black-and-white output under uneven paper illumination.
- Added `C7CLAHE` with tile luminance histograms, clip redistribution, CDF lookup tables and neighboring-tile interpolation for local SDR contrast enhancement.
- Added `C7HexagonalBokehBlur` with two-stage three-axis aperture sampling, rotation, highlight control and optional per-pixel circle-of-confusion input.
- Added `C7Palettize` for premultiplied-alpha-safe nearest-color quantization against a caller-provided palette of up to 32 colors.
- Added `C7CMYKHalftone` with four independent print-screen angles, full-canvas coordinates and an explicit conservative region-of-interest contract for tiled renderers.
- Added an `ImageNode` Page Curl transition primitive with normalized curl geometry, optional backside imagery, analytic shading, soft contact shadows and explicit non-tileable full-canvas execution semantics.
- Added `MPSConvolution`, `MPSLanczosResize` and `MPSMorphology` as validated out-of-place MPS execution atoms.
- Added `RenderMeshWarp`, `RenderLayerComposite` and `RenderVectorMask`, together with render topology, fixed-function premultiplied source-over blending and multisample resolve contracts.

#### Changed

- Routed `RenderOutputContract` SDR and EDR tone-mapping policies through the deterministic luminance primitive instead of approximating output with independent highlight/shadow and exposure adjustments.
- Aligned the public filter catalog with the source tree, including the previously omitted color grading, selective HSL, whites/blacks, output quantization and scene relighting primitives.
- Kept pipeline stage outputs independent from the final destination so combination shaders never bind the same texture for auxiliary reads and output writes.
- Upgraded `C7HighlightShadowTone` to a complete local pipeline backed by an MPS Gaussian reference texture, while preserving its existing adjustment API and premultiplied alpha.
- Extended `C7HighPassSkinSmoothing` with configurable tone-curve midpoints and optional final detail sharpening while preserving the previous default visual path.

#### Fixed

- Routed managed and private Metal texture readback through shared staging memory, preventing blank macOS image and pixel-buffer outputs when GPU-written data is not directly CPU-visible.
- Made `C7SurfaceBlur` return the original pixel for zero radius, zero threshold or zero intensity, and corrected signed edge-coordinate checks.
- Made `MPSGaussianBlur` preserve its configured public radius and expose the conservative sampling halo required by region-based executors.
- Made `C7ToneMapping` operate in straight-alpha color space before restoring premultiplied output, preventing translucent HDR pixels from violating the alpha contract.
- Made `C7HexagonalBokehBlur` sample optional CoC inputs through normalized canvas coordinates so lower-resolution control textures cannot be read out of bounds.
- Made `C7ColorCube` accept standard full-line and trailing `#` comments in CUBE resources instead of treating comment text as malformed sample data.

### 2026-08-04 — Production frame access and self-owned CIImage output

#### Added

- Add fail-closed `FrameProcessingCapability` based on `RenderPlanDiagnostics`, `RenderRequest`, `HarbethIO` and `ImageNode`, covering kernel declaration evidence, CPU readback, global dependence, certainty, sampler execution and extended dynamic range output requirements.
- Add `TextureBackedCIImageFrame` and `HarbethIO<CIImage>.outputTextureBackedFrame(...) `, let the Core Image frame-by-frame caller hold a rendering texture lease with color, dynamic range, tone mapping and source contract.

#### Changed

- Distinguish between explicitly declared kernel pixel contracts and conservative inferences that have not been declared contracts; production frame access does not allow evidence, sampler or external boundary access control.
- Reuse the source size prompt when parsing the frame color contract, and no longer duplicate the CIImage source just to check the descriptor.

#### Fixed

- Bind the reuse timing of managed texture to the typed Core Image frame output life cycle to avoid the texture lease returning the pool in advance when the packaging is still in use.
- Normalize the Core Image coordinates of direct PixelBuffer backing sources to avoid vertical flipping of dynamic media after texture filtering.
- Let escaped and cropped Core Image recipes retain their texture resources, avoiding premature lease reuse during deferred evaluation by AVFoundation and other hosts.

### 2026-08-02 — Asynchronous render submission, white balance and HDR preview hosting

#### Added

- Added `RenderSubmissionPolicy`, `RenderSubmissionHandle` and terminal snapshots for explicit cancellation and opt-in latest-only delivery across `HarbethIO` and `ImageNode` asynchronous work.
- Added `C7WhiteBalance.recipeFactors(temperature:tint:)` for constructing white-balance filters from recipe-oriented temperature and tint factors.
- Added typed output color-space, dynamic-range and tone-mapping metadata to `RenderedFrame`, so preview hosts no longer infer HDR semantics from texture pixel format.
- Added `PreviewDynamicRangePolicy` and observable `PreviewDisplayState` to `RenderView`; frame-driven previews now select SDR/16-bit float drawables, configure `CAMetalLayer` color space, request EDR when supported and report deterministic SDR fallback.
- Extended `HarbethRenderView` with the same dynamic-range policy and display-state callback while preserving the existing raw-texture SDR default.

#### Changed

- Routed the two public asynchronous processing routes through one generation-aware submission state machine while preserving independent, non-dropping delivery as the default.
- Made direct `ImageNode` filter-frame submissions encode and commit through that same state machine instead of wrapping synchronous frame rendering on the operation queue, while preserving completed-frame delivery semantics.
- Encoded contiguous layer-local filtering and compositing passes into one recipe-owned command buffer instead of synchronously committing each GPU stage.
- Kept finite `CIImage` inputs on the GPU by reusing pixel-buffer or Metal backing when available and otherwise rendering through the process-lifetime Core Image context directly into a Metal texture.
- Propagated Swift task cancellation into queued render submissions and made superseded or recovery-invalidated work terminate exactly once instead of leaving continuations suspended.
- Unified HarbethIO and ImageNode filter lowering around one internal execution program that freezes sampler adaptation, pointwise fusion, render planning, executable steps and diagnostics from the same input chain.
- Connected optimized stage lifecycle decisions to executable step liveness so intermediate textures are recycled only after their final GPU consumer completes.
- Added `SamplerAdaptation.partial` and the required `RenderProtocol.renderSamplerConsumption` contract, so every render filter explicitly declares whether its shader consumes runtime-bound or shader-defined sampler state.
- Harbeth 3.0 no longer preserves the former implicit sampler behavior for arbitrary `RenderProtocol` filters; custom render filters must declare `.runtimeBound` or `.shaderDefined` directly on the primary render protocol.

#### Fixed

- Suppressed stale host callbacks from already committed GPU work after cancellation, scope replacement or execution recovery without claiming that Metal command buffers can be synchronously cancelled.
- Bound each submission to its captured command queue and commit gate so work from an invalidated execution generation cannot migrate onto the replacement queue.
- Kept managed output and intermediate texture leases fenced until GPU completion, preventing early caller release from returning in-flight textures to the shared pool.
- Recycled committed outputs that lost delivery rights only after GPU completion, and isolated asynchronous performance metrics per submission without changing stable frame identifiers.
- Made synchronous command-buffer submission throw on GPU failure and release uncommitted raw/managed outputs instead of returning undefined textures or leases as successful results.
- Prepared `RenderRequest` and `ImageNode.makeFrame(...)` from one execution snapshot, so ordinary filter execution and diagnostics share the same compiled program while recipe, transition and layer routes retain explicit orchestration boundaries.
- Isolated `PreviewDisplaying` and `RenderView` to the main actor so drawable/layer mutation and preview display-state callbacks cannot run on a background render completion queue.
- Rejected structurally stale cached render plans even when a custom filter exposes an incomplete recipe fingerprint.
- Stopped reporting arbitrary render filters as sampler-covered when their shaders use fixed inline samplers, and now report mixed min/mag, address-mode or mip mappings as partial coverage instead of silently claiming full execution.
- Applied ImageNode sampler descriptors consistently across FrameRenderer's synchronous and asynchronous filter paths.
- Prevented nested ImageNode cache and sampler wrappers from retaining recursive render-plan compiler stack frames on small worker queues during cold transition rendering.

### 2026-08-01 — Runtime resource ownership and context migration

#### Added

- Added explicit execution generations and queue recovery through `HarbethContext`, plus resource-policy, texture-pool and cache diagnostics on the same supporting boundary.
- Added DocC guidance that separates host-facing runtime resources from Harbeth's concrete schedulers, pools, allocators and caches.

#### Changed

- Made `HarbethContext.shared` the single owner and public access point for process-lifetime Metal resources, Core Video texture caching, external Metal libraries and runtime recovery.
- Kept performance diagnostics as an internal listener owned by `HarbethContext`; hosts only use the opt-in `enablePerformanceMonitor` switch and no longer retain a monitor object.
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
