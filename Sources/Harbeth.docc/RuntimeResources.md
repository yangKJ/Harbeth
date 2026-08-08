# Runtime Resources

Use ``HarbethContext`` as the single supporting resource boundary for both public processing routes.

Harbeth has two normal processing routes: ``HarbethIO`` and ``ImageNode``. ``HarbethContext`` supports those routes with process-lifetime Metal resources, cache policy, diagnostics, and recovery. It is not a third processing route.

## Public resources

The host may use these `HarbethContext.shared` surfaces when it needs explicit runtime governance:

- `device` for same-device interoperability with host-owned Metal resources.
- `makeCommandBuffer()` for a new, single-use command buffer. The underlying command queue is intentionally internal so callers cannot retain a stale queue across recovery.
- `executionGeneration`, `isCurrentExecutionGeneration(_:)`, and `recoverExecution()` for cancellation and stale-result rejection.
- `cvMetalTextureCache` for advanced pixel-buffer interoperability.
- `maxConcurrentRenderTasks` for CPU-side render scheduling policy.
- ``RenderSubmissionPolicy`` and ``RenderSubmissionHandle`` for opt-in latest-only delivery, cancellation, and submission-state inspection without introducing another processing route.
- `textureAllocationStrategy`, texture-pool prewarming, and the read-only `TexturePoolStatistics` snapshot for measured resource-policy changes.
- The `enablePerformanceMonitor` switch for opt-in internal performance diagnostics, plus cache snapshots, pipeline binary archives, and derived-resource cache governance for diagnostics and host-controlled persistence. The monitor itself is not a host-facing runtime resource.
- Host-supplied Metal library registration, capability reports, and function lookup.

```swift
let context = HarbethContext.shared
let generation = context.executionGeneration

guard let commandBuffer = context.makeCommandBuffer() else {
    return
}

// Encode host work on resources created by context.device.
commandBuffer.commit()

guard context.isCurrentExecutionGeneration(generation) else {
    // Ignore a result produced before host-triggered recovery.
    return
}
```

## Internal resources

The following implementation types and concrete resource instances remain internal:

- `Device`, the process-lifetime owner of Metal libraries and function or pipeline caches.
- `ExecutionScheduler`, the current command queue, and the render operation queue.
- `TexturePool`, `TextureAllocator`, heap arenas, texture leases, and eviction machinery.
- Compute/render pipeline caches, sampler caches, image-resolution caches, render-plan caches, and their locks.
- Harbeth's working color spaces and synchronous prewarming or test-injection hooks.

Hosts observe and configure these resources through ``HarbethContext`` snapshots and policies instead of retaining the concrete owners.

Performance monitoring is an internal listener owned by ``HarbethContext``. HarbethIO, ImageNode, preview hosts, command buffers, caches, and allocators report into one diagnostics timeline, while hosts only control the opt-in switch. A separate public monitor object or per-module monitors would split those measurements and create another runtime entry point.

## Ownership and recovery

The Metal device has process-lifetime identity. `recoverExecution()` does not destroy or recreate it. Recovery cancels queued CPU operations, rotates the command queue, advances the execution generation, clears runtime caches, purges pooled textures, and flushes an already-created Core Video texture cache.

Already committed GPU command buffers remain owned by Metal and are not synchronously cancelled. Hosts that can overlap recovery with in-flight work should capture `executionGeneration` and reject stale completion results.

## Asynchronous submission

`HarbethIO` and `ImageNode` submit their asynchronous public work through the same runtime state machine. The default ``RenderSubmissionPolicy/independent`` policy preserves every submission. Hosts with replaceable preview work may opt into ``RenderSubmissionPolicy/latestOnly(scopeIdentifier:)`` for a stable scope:

```swift
var io = HarbethIO(element: texture, filters: filters)
io.submissionPolicy = .latestOnly(scopeIdentifier: "editor.preview")

let handle = io.transmitOutput { result in
    // A superseded request completes once with renderableTaskCancelled.
}
```

Queued work can be cancelled before execution. Work that has already committed a Metal command buffer remains GPU-owned; cancellation or replacement suppresses its stale host delivery and completes the public callback once with ``HarbethError/renderableTaskCancelled``. ``RenderSubmissionHandle/snapshot`` preserves the terminal distinction between caller cancellation, scope replacement, and execution recovery.

Changing `textureAllocationStrategy` invalidates compiled render plans so a plan cannot retain allocator assumptions from the previous strategy. Memory pressure removes derived and image-resolution resources; cache and texture-pool snapshots expose bounded counts and bytes without exposing mutable cache implementations.

## Why there is no public Cacheable protocol

Cache ownership is concrete runtime policy, not a capability that host types should adopt. The former internal `Cacheable` protocol only represented a Core Video texture cache and relied on Objective-C associated storage. ``HarbethContext`` now owns that cache directly, so the protocol is removed instead of becoming public API.

`Device` remains an internal reference type because it owns locks, lazy loaders, and mutable function or pipeline caches with stable object identity. Giving it value semantics would make copies ambiguous without reducing allocation or synchronization cost.

The former `Shared` facade is removed. It had become a stateless forwarding layer over ``HarbethContext`` and therefore created a duplicate resource entry point without owning a distinct lifetime or policy.
