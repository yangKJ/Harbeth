# HarbethIO

Use the direct route when the caller already has a source and a filter chain. It keeps Harbeth focused on a single rendering operation rather than host workflow or product state.

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

当滤镜链非空，或指定了需要物化的输出色彩空间时，不支持原类型输出的输入会返回 `HarbethError.renderableUnsupportedInputType`，同步、回调与 async 路径保持一致。空滤镜且无需物化时仍直接返回原值。

`Data`、`URL` 和 `ImageAsset` 可以继续通过 texture/frame/request 路线加载并处理；它们不承诺 `output()` / `transmitOutput()` 返回处理后的同类型编码数据或文件。需要这类来源时可使用 `ImageNode.data(...)` 或 `ImageNode.asset(...)`。

Use the structured-concurrency overload when the caller must not block for GPU completion:

```swift
let result = try await HarbethIO(element: inputImage, filters: filters).transmitOutput()
```

`transmitOutput(outputColorSpace:complete:)` is the callback source of truth used by the async overload. Filtered work is encoded on Harbeth's render operation queue. Under the default profile, completion follows GPU completion. Completion has no main-thread guarantee, and the no-filter fast path may complete inline.

异步提交保留 source 与滤镜引用，不会深拷贝自定义引用类型滤镜。执行期间必须保持共享参数不变；并发请求应使用独立实例或不可变滤镜。`ImageNode` 在执行队列中解析计划，同样遵守此约束。取消或 scheduled 回调均不是 GPU 完成屏障，仍被 GPU 使用的输入纹理不可提前改写。

Asynchronous output uses ``RenderSubmissionPolicy/independent`` by default, so ordinary callers do not lose work. For replaceable preview requests, set `submissionPolicy` to ``RenderSubmissionPolicy/latestOnly(scopeIdentifier:)`` and retain the returned ``RenderSubmissionHandle`` when explicit cancellation or state inspection is needed. Superseded and cancelled requests terminate exactly once with ``HarbethError/renderableTaskCancelled``.

For texture-first preview, `transmitOutputRealTimeCommit` remains the single public switch for scheduled delivery. When enabled, asynchronous texture output can be delivered after the command buffer is scheduled. The switch does not change synchronous `output()` behavior, and CPU-readable image, pixel-buffer and sample-buffer outputs continue to wait for GPU completion before materialization.

`bufferPixelFormat` is the single output-format override. Keep it `nil` to preserve the source texture format, or assign a concrete `MTLPixelFormat` when the output contract requires conversion.

`mirrored` remains the legacy explicit correction for a CIImage created from a texture-backed source. It is an output-orientation compatibility flag, not a generic image-transform control.

For structured profiles, frame metadata, diagnostics, or host delivery, use the ``ImageNode`` route.
