# Shared Image Primitives

These primitives support the existing `HarbethIO` and `ImageNode` routes. They do not introduce another rendering entry point, asset catalog, editing session, or task scheduler.

## Texture reductions

```swift
let frame = try ImageNode.texture(input).makeFrame(profile: .exportQuality)
let bounds = try frame.texture.c7.alphaCoverageBounds()
let histogram = try frame.texture.c7.makeWeightedColorHistogram()
let rgbBins = histogram.channels
let meanAndRGB = histogram.meanAndRGB
```

Weighted histograms accept non-sRGB RGBA8/BGRA8, RGBA16Float, and RGBA32Float textures on the active context device. Values remain in the texture storage domain. RGB is unpremultiplied, clamped to 0...1, and rounded to 256 bins. Each sample is weighted by clamped source alpha multiplied by optional clamped red-channel coverage. Coverage must match the source device and dimensions and use a supported RGBA format. `meanAndRGB[0]` is the average of RGB bins, not a luminance histogram.

The GPU produces partial histograms for 32×32 blocks; the CPU reads and sums those summaries. On devices supporting Apple7 or Mac2, uniform active SIMD lanes combine weights before the atomic update to avoid flat-color contention. Other devices and Simulator retain the baseline atomic kernel; see Apple's [Metal feature tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf). Parallel Float accumulation can differ from a serial Double reference in its last digits. Compare normalized distributions with an appropriate tolerance. Non-finite contributing values are rejected; RGB beneath zero or negative alpha is ignored. `maximumReadbackBytes` bounds the summary allocation before encoding. The synchronous API waits only at the reduction boundary and checks task cancellation before work and before returning.

Alpha bounds accept the same formats plus sRGB RGBA8/BGRA8. They ignore RGB values, reject non-finite alpha, and include every finite positive alpha, including the smallest binary16 subnormal. Negative alpha and signed zero are transparent. Shared inputs up to 256×256 pixels and other inputs up to 64×64 pixels use CPU inspection when their packed source bytes fit `maximumReadbackBytes`. Shared inputs avoid a GPU submission; private or managed readback may still require staging. Larger inputs, or small inputs whose pixels exceed the budget, use a fixed 24-byte GPU summary. The minimum summary budget remains 24 bytes. Producers must complete their texture writes before synchronous inspection. These bounded routing thresholds were measured on an M2 Pro and do not certify latency on every device. Bounds use top-left pixel coordinates; a completely transparent texture returns `nil`.

## Mesh pipeline caching

`MetalCommandEnvironment.makeMeshRenderPipelineState` is available on iOS/tvOS 16 and macOS 13 or later. Call it only after checking the mesh-shader capability report. It uses the shared render-pipeline cache, including concurrent creation coalescing and invalidation generations. The key includes both function identities, the destination pixel format, and the mesh thread limit. A cache miss can block while Metal creates the pipeline; subsequent matching calls reuse the pipeline.

The caller still owns its mesh uniforms, command encoding, output contract, and fallback filter. Cache support does not imply that every device supports mesh shaders.

## Versioned lookup resources

```swift
let texture = try LookupTextureResource.load(url: lookupURL, version: "lookup-v1")
let filter = C7LookupTable(
    name: "lookup-v1",
    forResource: "MyResources",
    lookupTexture: texture,
    intensity: 0.8
)
```

The loader accepts file URLs and explicit immutable resource versions. It preserves the existing CGImage-to-texture color conversion. Cache identity includes the file path, version, pixel format, color space, and context namespace. Supported output formats are RGBA8 and BGRA8. Change the version when changing file contents; the loader does not stat or hash the file on every hit.

Preloaded lookup initializers preserve resource names and bundle identity for callers that serialize filters. The loader owns no LUT assets or style defaults. `HarbethContext.makeDerivedTexture` also provides bounded, generation-aware caching for caller-created textures. Concurrent matching creation is coalesced, failures can be retried, recursive same-thread creation is rejected, and invalidation prevents an old creation from repopulating the cache. A returned cached texture must be treated as immutable while shared.

## Color and inverse-grid math

`RGBColorMath.oklab(_:space:)` and `rgb(fromOKLab:space:)` support encoded and linear sRGB/Display-P3. They apply no gamut clipping or tone-mapping policy, preserving negative and extended-range values where the transforms allow them.

`InverseCoordinateGrid` validates a rectangular field of finite normalized inverse coordinates. `makeTexture()` uploads numeric RG32Float data through the bounded coordinate-field cache. An immutable grid memoizes its content fingerprint under a lock, so repeated uploads do not repeat hashing. Producers with an existing immutable revision can instead call `InverseCoordinateGrid.makeTexture(width:height:identifier:points:)`; the point provider runs only on a cache miss. The identifier must change with the point data, and dimensions participate in the cache key. `sourceRegion(for:extent:padding:)` conservatively includes every intersecting bilinear cell's corners. Pixel rectangles use bottom-left coordinates; grid points use top-left coordinates. Querying a region does not upload a texture or compute its cache fingerprint. The static `sourceRegion(for:extent:width:height:padding:pointAt:)` variant reads only intersecting cell corners from producer-owned, validated points, avoiding a full-array copy or revalidation. Reuse the existing `InverseGridTextureSampler` to render the field.

Brush behavior, mesh editing, inversion policy, document transactions, and persistence remain caller responsibilities.

## Depth-dependent blur

`C7DepthLensBlur` consumes a premultiplied color texture and an aligned relative-depth texture. `DepthLensBlurDescriptor` expresses a normalized full-canvas focus point, intensity, focus range, transition, and blur radius. It does not represent physical focal length or aperture.

The existing kernel retains its sample weights, relative-offset rounding, extended-range contract, and neighborhood radius of `ceil(2 * blurRadius)`. The kernel is explicitly resolved from the Harbeth framework. Deferred callers must bind depth at auxiliary index 0; missing depth must not silently become an ordinary blur. Depth inference, source selection, and focus interaction belong to the host.

These contracts have offscreen numerical and integration coverage. They do not establish natural-photo quality, complete HDR/device acceptance, full-resolution export performance, or product-level latency improvements.

## Measuring benefits

`PrimitiveBenefitBenchmarkTests` is opt-in and skips normal test runs. Run it in Release with `HARBETH_RUN_PRIMITIVE_BENCHMARKS=1` and an optional `HARBETH_BENCHMARK_OUTPUT_DIR`. It compares frozen pre-migration caller algorithms against current implementations in the same runtime, warms both routes, alternates their order, checks equivalent results, and writes p50/p95 wall-clock samples.

The matrix includes shared/private RGBA16Float inputs, varied/flat distributions, source-alpha/coverage weighting, small-to-large dimensions, producer-revision field reuse, and ROI queries. Byte figures describe logical CPU-visible results, not physical driver traffic or process peak memory. Alpha readback is adaptive and is reported as a policy rather than a fictitious constant byte count.

Moving unchanged color/depth code does not establish a performance improvement. `GPUPrimitivePublicAPITests` separately verifies that those APIs can be consumed with only the public Harbeth module. Product-level timing, natural-photo quality, device HDR, energy, and full-resolution export remain separate acceptance work.
