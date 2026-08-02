# ImageNode

Use Harbeth's advanced unified entry when rendering must preserve a structured description, stable output contracts, diagnostics, or more than one delivery form.

## Build a Node

Start from image, `CGImage`, `CIImage`, texture, pixel buffer, sample buffer, encoded data, or ``ImageAsset``. Continue from the existing node instead of rebuilding a parallel route:

```swift
let node = ImageNode.image(inputImage)
    .applying(C7Exposure(exposure: 0.25))
    .transforming(ImageTransformRecipe(rotationDegrees: 90))
    .withCachePolicy(.transient)
```

The same graph can carry:

- filters, explicit kernel contracts, plugins, sampler policy, and cache policy;
- ``EditRecipe``, Geometry, Optics, and local effects;
- gradient, shape, path, descriptor, and composite masks;
- transitions and ordered layer composites;
- preview/final recipe modes and derivative-specific output intent.

Prefer instance chains such as `node.editing(...)`, `node.transforming(...)`, and `node.applying(optics: ...)` when a node already exists. Static factories establish the graph's source or an inherently multi-source root such as a transition or layer composite. Recipes remain editing-description primitives inside the `ImageNode` route; they are not a third public route.

## Choose an Output

```swift
let texture = try node.makeTexture(profile: .exportQuality)
let frame = try node.makeFrame(profile: .stablePreview)
let asyncFrame = try await node.makeFrameAsync(profile: .stablePreview)
let request = try node.makeRenderRequest(profile: .inspectionQuality)
```

- `makeTexture()` returns the GPU result directly.
- `makeFrame()` keeps texture ownership, source/color/alpha/orientation metadata, ``RenderProfile``, ``ImageDerivativeSpec``, semantic intent, and preview-host payload together.
- `makeFrameAsync()` submits the synchronous frame build to Harbeth's render operation queue and resumes after the frame is ready. It does not guarantee main-actor delivery.
- `transmitFrame(...)` and `makeFrameAsync(...)` accept an optional ``RenderSubmissionPolicy``. The default preserves independent delivery; latest-only scopes reject stale host delivery without changing synchronous `makeFrame(...)` semantics.
- `makeRenderRequest()` captures a deferred, inspectable execution contract for later rendering.

From the request, hosts can inspect `resourceEstimate`, apply a ``RenderResourceBudget``, render with an allocator-observed resource report, or compare preview/export parity before delivery. These checks reuse the same compiled node contract; they do not create another processing route.

Profiles select latency, stable preview, inspection, export, or readback behavior. Derivatives describe the intended output size, source tier, render intent, and semantic role without turning those concerns into a separate processing route.

## Inspect the Graph and Result

Before execution, use `makeImageGraph()`, `makeDiagnostics()`, or `makeDebugSnapshot()` to inspect graph structure, contracts, and optimization decisions. After rendering, `ImageNode` can expose histograms, statistics, color probes, masks, and named output attachments or analysis bundles.

Analysis is a post-render inspection layer shared with `HarbethIO`; it is not another top-level entry. A ``RenderedFrame`` can be passed directly to ``RenderView`` or ``HarbethRenderView`` for texture-first preview without an image readback.
