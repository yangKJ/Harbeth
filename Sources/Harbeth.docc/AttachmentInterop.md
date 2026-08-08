# Same-Command-Buffer Attachment Interop

Keep Harbeth rendering and caller-owned GPU work in one Metal submission.

## Overview

`encodeAttachmentSet(from:commandBuffer:identifier:)` is an advanced supporting surface for hosts that already own a Metal batch. It encodes one `RenderProtocol` attachment pass, ends Harbeth's encoder, and returns the output textures without enqueueing, committing, or waiting for the command buffer.

The command buffer must use Harbeth's Metal device, retain encoded references, still accept encoding, and have no open encoder. The caller can then create its own compute, render, or blit encoder and submit the batch once:

```swift
let commandBuffer = hostQueue.makeCommandBuffer()!
let attachments = try RenderAuxiliaryLuminance().encodeAttachmentSet(
    from: sourceTexture,
    commandBuffer: commandBuffer
)

let color = attachments.texture(for: .primaryColor)!
let luminance = attachments.texture(for: .luminance)!
let hudTexture = try hostHUDEncoder.encode(
    color: color,
    luminance: luminance,
    commandBuffer: commandBuffer
)

precondition(commandBuffer.status == .notEnqueued || commandBuffer.status == .enqueued)
commandBuffer.commit()
```

`hostHUDEncoder` above represents application-owned Metal code. Harbeth only bridges one GPU submission: it does not provide UI components or take ownership of the host's interaction and persistence workflow.

Do not read attachment or HUD pixels on the CPU until the caller has observed command-buffer completion. The command buffer may be `.notEnqueued` or `.enqueued` when handed to Harbeth, but must still accept encoding and have no open encoder. The iOS Demo's **Command Buffer HUD** page shows the full minimal flow with a caller-owned compute shader and one host commit.
