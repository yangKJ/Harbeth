# HarbethIO

Use the direct route when the caller already has a source and a filter chain.

```swift
let result = try HarbethIO(
    element: inputImage,
    filters: [
        C7Exposure(exposure: 0.25),
        C7Contrast(contrast: 1.08)
    ]
).output()
```

`output()` is the canonical synchronous surface because failures remain observable. `transmitOutput(...)` is the core asynchronous counterpart.

Use the structured-concurrency overload when the caller must not block for GPU completion:

```swift
let result = try await HarbethIO(element: inputImage, filters: filters).transmitOutput()
```

`transmitOutput(outputColorSpace:complete:)` is the callback source of truth used by the async overload. Filtered work is encoded on Harbeth's render operation queue. Under the default profile, completion follows GPU completion. Completion has no main-thread guarantee, and the no-filter fast path may complete inline.

For texture-first preview, ``HarbethIO/configured(for:)`` with ``RenderProfile/interactiveLatency`` can deliver after the command buffer is scheduled. CPU-readable image and pixel-buffer outputs continue to wait for GPU completion before readback.

For high-frequency texture paths, configure a ``RenderProfile`` and produce a ``RenderedFrame`` rather than reading back an image.
