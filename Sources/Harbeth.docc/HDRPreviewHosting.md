# HDR Preview Hosting

Use ``RenderedFrame`` with ``RenderView`` or ``HarbethRenderView`` when preview must preserve a rendered frame's SDR, EDR, or HDR output contract.

`PreviewDisplaying` and `RenderView` are main-actor APIs. When a frame arrives from a background render callback, cross to `MainActor` before calling `display(_:)`; drawable and `CAMetalLayer` mutation, plus `onPreviewDisplayStateUpdated`, are delivered on that same actor.

## Frame-driven configuration

`RenderedFrame` carries typed output metadata through `outputColorSpaceContract`, `outputDynamicRange`, and `outputToneMappingPolicy`. `RenderView` consumes that metadata when `display(_:)` is called:

```swift
let frame = try node.makeFrame(outputColorSpace: .extendedLinearDisplayP3)

let renderView = RenderView(frame: .zero, device: nil)
renderView.dynamicRangePolicy = .automatic
renderView.display(frame)
```

Under `.automatic`, SDR frames use an 8-bit drawable while EDR/HDR frames retain a 16-bit floating-point drawable. The underlying `CAMetalLayer` receives the frame color space and requests extended-range presentation only when the current platform and display can provide it.

## Dynamic-range policies

- ``PreviewDynamicRangePolicy/automatic`` follows the frame contract. A raw `MTLTexture` remains SDR because pixel format alone does not describe content dynamic range.
- ``PreviewDynamicRangePolicy/standard`` forces SDR presentation. HDR source precision is retained so system-supported tone mapping can occur before 8-bit quantization.
- ``PreviewDynamicRangePolicy/extended`` explicitly requests EDR, including for a raw texture whose semantic contract is managed by the caller.

An EDR request can fall back to SDR when the active display does not expose extended headroom. Observe ``RenderView/currentPreviewDisplayState`` or ``RenderView/onPreviewDisplayStateUpdated`` instead of assuming that a successful render implies HDR presentation:

```swift
renderView.onPreviewDisplayStateUpdated = { state in
    if state.fallbackReason == .extendedRangeUnavailable {
        // Update product UI or diagnostics without changing the render graph.
    }
}
```

SwiftUI exposes the same contract:

```swift
HarbethRenderView(
    frame: frame,
    dynamicRangePolicy: .automatic,
    onPreviewDisplayState: { state in
        print(state.effectiveDynamicRange)
    }
)
```

## Responsibility boundary

The preview host configures drawable precision, layer color space, platform EDR preference, and supported system tone mapping. It does not author creative tone curves or convert arbitrary HDR content to a product-specific SDR look. Perform explicit output conversion in the render contract before display when deterministic SDR appearance is required.
