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

Asynchronous output uses ``RenderSubmissionPolicy/independent`` by default, so ordinary callers do not lose work. For replaceable preview requests, set `submissionPolicy` to ``RenderSubmissionPolicy/latestOnly(scopeIdentifier:)`` and retain the returned ``RenderSubmissionHandle`` when explicit cancellation or state inspection is needed. Superseded and cancelled requests terminate exactly once with ``HarbethError/renderableTaskCancelled``.

For texture-first preview, `transmitOutputRealTimeCommit` remains the single public switch for scheduled delivery. When enabled, asynchronous texture output can be delivered after the command buffer is scheduled. The switch does not change synchronous `output()` behavior, and CPU-readable image, pixel-buffer and sample-buffer outputs continue to wait for GPU completion before materialization.

`bufferPixelFormat` is the single output-format override. Keep it `nil` to preserve the source texture format, or assign a concrete ``Metal/MTLPixelFormat`` when the output contract requires conversion.

For high-frequency texture paths, configure a ``RenderProfile`` and produce a ``RenderedFrame`` rather than reading back an image.
