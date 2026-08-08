# Real-Time Delivery

Make freshness and completion semantics explicit for asynchronous rendering.

Asynchronous rendering is independent by default: each submission is eligible for delivery. Use ``RenderSubmissionPolicy`` only when a newer result may replace stale pending work in the same host scope.

## Replace Stale Preview Work

```swift
let handle = node.transmitFrame(
    profile: .interactiveLatency,
    submissionPolicy: .latestOnly(scopeIdentifier: "editor.preview")
) { result in
    Task { @MainActor in
        if case .success(let frame) = result {
            renderView.display(frame)
        }
    }
}
```

`.latestOnly(scopeIdentifier:)` replaces pending work only within the same non-empty scope. Retain the returned ``RenderSubmissionHandle`` when the host must cancel work or inspect the terminal state. Cancellation, replacement, and execution recovery complete the request once with ``HarbethError/renderableTaskCancelled``.

The completion queue is not guaranteed. Move UI work to `MainActor`. A no-filter ``HarbethIO`` fast path may complete inline because it does not need an asynchronous render operation.

## Scheduled Texture Delivery

For a low-latency texture-only direct path, opt in explicitly:

```swift
var io = HarbethIO(element: inputTexture, filters: filters)
io.transmitOutputRealTimeCommit = true
let outputTexture = try await io.transmitOutput()
```

With `transmitOutputRealTimeCommit` enabled, texture output can arrive after its command buffer is scheduled and before GPU completion. Continue that texture through a compatible GPU dependency chain or a preview host; do not immediately read it on the CPU.

The switch does not change synchronous `output()` behavior. Image, pixel-buffer, and sample-buffer results still wait for GPU completion before CPU materialization.

## Select the Right Promise

- Use ``HarbethIO`` for a direct source-plus-filters asynchronous result.
- Use ``ImageNode`` `transmitFrame(...)` or `makeFrameAsync(...)` when the host needs a ``RenderedFrame`` and its output metadata.
- Use `.interactiveLatency` for interactive texture presentation, not as a universal performance mode.
- Use `.stablePreview`, `.exportQuality`, or `.readbackQuality` when stable reuse, final delivery, or CPU access is part of the contract.

This document describes Harbeth's rendering delivery contract. It does not measure camera, display, or product-workflow performance.
