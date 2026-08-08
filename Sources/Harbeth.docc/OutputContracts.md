# Output Contracts

Choose a delivery contract before optimizing the render path.

Harbeth separates the scheduling profile from output semantics. ``RenderProfile`` selects latency and readback behavior; color, alpha, pixel format, tone mapping, orientation, and attachments remain explicit output facts. This keeps a preview result from being mistaken for a CPU-readable or export-ready result.

## Choose a Profile

| Need | Profile |
| --- | --- |
| High-frequency texture presentation | `.interactiveLatency` |
| Fast response to a discrete edit | `.responseLatency` |
| Reusable normal preview | `.stablePreview` |
| High-fidelity inspection | `.inspectionQuality` |
| Final GPU delivery | `.exportQuality` |
| Image, data, or analysis readback | `.readbackQuality` |

The profile is not a visual look or a tone-mapping preset. It describes the execution and delivery contract. When CPU materialization is required, use `.readbackQuality` or `.exportQuality` and wait for GPU completion.

## Deliver a Frame

Use ``ImageNode`` when the host needs a texture together with its rendering facts:

```swift
let frame = try ImageNode
    .image(inputImage)
    .applying(C7Exposure(exposure: 0.2))
    .makeFrame(profile: .stablePreview)

renderView.display(frame)
```

``RenderedFrame`` keeps the rendered texture, output color-space and dynamic-range contracts, alpha, orientation, source descriptor, derivative, profile, metadata, and a texture lifetime handle together. Keep the frame alive for as long as a host displays or otherwise consumes its texture.

Use `makeTexture()` only when the host deliberately needs a raw GPU result and owns the surrounding delivery semantics. Use `makeFrame()` for preview hosting, metadata-aware handoff, inspection, or any path where output meaning must travel with the texture.

## Declare Output Semantics

The effective output contract is derived from the source, filters, and structured recipes. A filter can declare `kernelOutputContract`; structured composition can declare ``RenderOutputContract`` directly:

```swift
let recipe = LayerCompositeRecipe(
    background: .texture(backgroundTexture),
    layers: layers,
    profile: .exportQuality,
    outputContract: .toneMappedDisplayP3Texture
)

let frame = try recipe.makeNode().makeFrame(
    profile: recipe.profile,
    derivative: recipe.derivative
)
```

Useful built-in contracts include `.preserveInput`, `.displayP3Texture`, `.highPrecisionLinearTexture`, `.hdrPQTexture`, `.hdrHLGTexture`, and `.toneMappedDisplayP3Texture`. Select one only when the intended conversion is known; a high-precision pixel format alone does not prove that content is HDR.

For SDR/EDR/HDR presentation, continue with <doc:HDRPreviewHosting>. Use <doc:ContractsAndDiagnostics> to inspect parity or resource evidence before treating two delivery paths as equivalent.
