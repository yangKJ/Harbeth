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

## 外部命令缓冲区编码

`ImageNode.encodeFrame(into:inputColorSpace:workingColorSpace:context:)` 将纹理、采集缓冲区及已准备的分层图编码到宿主提供的命令缓冲区。它不提交、不等待、不读回位图；宿主必须提交已编码的命令，即使后续阶段失败，也要等待 GPU 完成后归还输入资源。图层要求纹理输入、标准混合及已物化遮罩；不支持的图结构明确报错。

`ImageNodeEncodingContext` 由一个执行器持有，最多缓存 8 个执行身份。缓存只复用编译准备，输入纹理每帧重新绑定；含外部辅助纹理的链不缓存，以免延长瞬态帧驻留。硬件 sRGB 纹理采样已自动解码，后续色彩转换以线性值解释；未知 ICC 或 HDR 不可伪装成硬件 sRGB。

外部编码在常规非线性色彩转换之前解除预乘 alpha，转换后恢复；硬件 sRGB 的预乘输入先还原其存储编码域。ICC 路径通过 `MPSColorConversion` 的 `alphaType` 显式声明源和目标的 alpha 形式，缓存身份包含该形式，避免半透明彩色边缘偏色。
