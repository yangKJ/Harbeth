# Filter Authoring

Extend Harbeth with the smallest execution contract that expresses the work.

Filter authoring supports the two public processing routes; it does not create a separate integration route. Applications still consume a custom filter through ``HarbethIO`` or ``ImageNode``.

## Choose a Contract

| Need | Contract |
| --- | --- |
| One standard compute kernel | ``C7FilterProtocol`` with `.compute(kernel:)` |
| Ordered or source-parallel multi-pass processing | ``C7FilterPipelineProtocol`` |
| A render pass, MPS kernel, or blit operation | The corresponding standard filter contract |
| A command/resource graph that standard contracts cannot express | ``C7MetalCommandEncodingProtocol`` |

Multiple passes alone are not a reason to use the command-encoding escape hatch. A texture-in/texture-out pipeline remains a ``C7FilterPipelineProtocol``.

## Start with a Leaf Filter

```swift
public struct LiftFilter: C7FilterProtocol {
    public let amount: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "liftKernel")
    }

    public var factors: [Float] {
        [amount]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(amount: Float) {
        self.amount = amount
    }
}
```

For a normal compute kernel, texture `0` is the destination and texture `1` is the source. Lightweight `factors` are bound from buffer `0`; use `kernelParameterBindings` when named, typed, or explicitly indexed values are required.

Declare `destinationTextureContract` when usage, storage mode, or aliasing matters. Declare `kernelOutputContract` when a filter changes alpha, color, pixel format, dynamic range, or output size semantics. Use `.point`, `.neighborhood`, `.dualTexture`, or `.multiTexture` accurately so the runtime can select a safe execution strategy.

## Validate the Contract

Verify a custom filter with at least these cases:

- The Metal function resolves from its intended library; missing functions fail visibly.
- 1-by-1, non-aligned, and extreme aspect-ratio textures remain in bounds.
- Default values and parameter boundaries produce deterministic results.
- Output size, alpha, color, and pixel-format semantics match the declared contract.
- The same filter behaves consistently through ``HarbethIO`` and ``ImageNode`` for the same source and output contract.

Use ``C7MetalCommandEncodingProtocol`` only when the filter must own a non-standard command/resource graph. It must write and return the supplied destination texture on the command buffer's device; capability fallback must be explicit and observable.
