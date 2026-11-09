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

## Explicit frame delivery

A media host can set `usesExplicitDrawing = true`, call `display(frame)`, and then call `draw()` when a new frame is ready. `onDrawableSizeChanged` reports physical pixel dimensions for the upstream render budget. Explicit mode keeps the timed draw loop paused.

`onFrameDrawCompleted` receives the submitted texture and a result on the main actor. A successful `true` reports completed GPU commands, `false` reports a skipped draw, and failures report command or draw-resource errors. The callback is captured at submission, so replacing the handler cannot redirect an earlier GPU completion to a later consumer. The host associates each result with its own frame identity and completes cancelled or superseded media requests exactly once.

For a texture-only render target, the host may set `framebufferOnly = true`. Pass the actual color-space contract with `RenderedFrame`. When creating a borrowed texture through `TextureLoader.resolveTextureSource(with:)`, keep the returned source and its `retainedOwners` alive until GPU processing completes.
