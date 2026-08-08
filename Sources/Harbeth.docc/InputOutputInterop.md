# Input and Output Interop

Choose the route that preserves the source and result contract you need.

Harbeth accepts images, textures, pixel buffers, sample buffers, encoded data, and assets. The two public routes remain stable:

| Situation | Route | Result |
| --- | --- | --- |
| A typed source and a direct filter chain already exist | ``HarbethIO`` | The same typed result through `output()` or `transmitOutput()` |
| Source decoding, metadata, derivatives, inspection, or texture-first delivery matter | ``ImageNode`` | Texture, ``RenderedFrame``, diagnostics, or a deferred request |

## Normalize Through ImageNode

``ImageSource`` is the unified source model behind ``ImageNode``. It accepts `C7Image`, `CGImage`, `CIImage`, `MTLTexture`, `CVPixelBuffer`, `CMSampleBuffer`, `Data`, and `ImageAsset`.

```swift
let frame = try ImageNode
    .pixelBuffer(pixelBuffer)
    .applying(C7Contrast(contrast: 1.05))
    .makeFrame(profile: .stablePreview)
```

Image sources become a Metal texture for rendering, but the resulting frame keeps source descriptors, orientation, color information, and derivative intent. This is why encoded data and assets should normally start with ``ImageNode`` rather than being forced through a direct typed-output path.

## Pixel Buffers and Sample Buffers

For a pixel buffer, Harbeth uses a direct Metal texture bridge when the buffer contract permits it and otherwise performs the required materialization. A sample buffer follows its pixel-buffer payload while preserving the information needed for frame-aware delivery.

Keep the following facts explicit at the host boundary:

- Pixel format, alpha convention, color attachments, YCbCr range and matrix must describe the actual input.
- Orientation belongs to the source contract; do not infer display orientation from texture width and height.
- A raw `MTLTexture` has no inherent HDR meaning. Supply an explicit output color contract when presentation or conversion requires one.
- A CPU-readable result must wait for GPU completion. Texture-first presentation can remain on the GPU path.

## Select the Result

| Required result | Preferred API |
| --- | --- |
| Typed direct output | `HarbethIO.output()` |
| Non-blocking typed direct output | `HarbethIO.transmitOutput()` |
| Raw GPU texture | `ImageNode.makeTexture()` |
| Texture plus metadata and ownership | `ImageNode.makeFrame()` |
| Deferred rendering and inspection | `ImageNode.makeRenderRequest()` |

Harbeth performs image and frame rendering only. The host retains interaction, persistence, and product workflow ownership.
