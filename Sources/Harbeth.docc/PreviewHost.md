# Preview Hosting

For SDR/EDR/HDR frame-driven display, including dynamic-range policy, capability fallback and SwiftUI integration, see <doc:HDRPreviewHosting>.

Display texture-first output without CPU image readback.

UIKit and AppKit callers can use ``RenderView`` directly:

```swift
renderView.display(frame)
```

SwiftUI callers can use ``HarbethRenderView``:

```swift
HarbethRenderView(frame: frame, resizingMode: .aspectFit)
```

The host preserves frame metadata, configures SDR/EDR presentation from the typed frame contract, chooses the available preview substrate, observes visibility, and can report display, execution, and fleet diagnostics. Harbeth owns this render-output host support; media capture, playback, recording, timeline, and export orchestration remain outside the render engine.
