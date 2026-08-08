# Preview Hosting

Display texture-first output without CPU image readback.

For SDR/EDR/HDR frame-driven display, including dynamic-range policy, capability fallback and SwiftUI integration, see <doc:HDRPreviewHosting>.

UIKit and AppKit callers can use ``RenderView`` directly:

```swift
renderView.display(frame)
```

SwiftUI callers can use ``HarbethRenderView``:

```swift
HarbethRenderView(frame: frame, resizingMode: .aspectFit)
```

The host preserves frame metadata, configures SDR/EDR presentation from the typed frame contract, chooses the available preview substrate, observes visibility, and can report display and execution diagnostics. Harbeth owns this render-output host support; interaction, persistence, and product workflow remain with the host.
