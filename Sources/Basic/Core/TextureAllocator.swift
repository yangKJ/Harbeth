//
//  TextureAllocator.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum TextureAllocationStrategy: String, Sendable, Codable, Equatable, Hashable {
    case exact
    case tolerant
    case heapBacked
}

public struct TextureAllocatorSnapshot: Sendable, Codable, Equatable, Hashable {
    public let allocationStrategy: TextureAllocationStrategy
    public let textureRequestCount: Int
    public let textureReuseHitCount: Int
    public let heapBackedAllocationCount: Int
    public let allocatorDecisions: [String]

    public init(allocationStrategy: TextureAllocationStrategy,
                textureRequestCount: Int,
                textureReuseHitCount: Int,
                heapBackedAllocationCount: Int,
                allocatorDecisions: [String]) {
        self.allocationStrategy = allocationStrategy
        self.textureRequestCount = textureRequestCount
        self.textureReuseHitCount = textureReuseHitCount
        self.heapBackedAllocationCount = heapBackedAllocationCount
        self.allocatorDecisions = allocatorDecisions
    }
}

public protocol TextureAllocating: AnyObject {
    func dequeueTexture(width: Int,
                        height: Int,
                        pixelFormat: MTLPixelFormat,
                        allowsSizeTolerance: Bool) -> MTLTexture?
    func dequeueTextureLease(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             allowsSizeTolerance: Bool,
                             logicalExtent: C7Size?) -> TextureLease?
    func makeLease(for texture: MTLTexture, logicalExtent: C7Size?) -> TextureLease
    func enqueueTextureSync(_ texture: MTLTexture)
}

public protocol TextureAllocator: TextureAllocating {
    var strategy: TextureAllocationStrategy { get }
    func makeSnapshot() -> TextureAllocatorSnapshot
}

open class TexturePoolAllocator: TextureAllocator {
    public let texturePool: TexturePool
    public let strategy: TextureAllocationStrategy
    private var textureRequestCount: Int = 0
    private var textureReuseHitCount: Int = 0
    private var heapBackedAllocationCount: Int = 0
    private var allocatorDecisions: [String] = []

    public init(texturePool: TexturePool,
                strategy: TextureAllocationStrategy = .exact) {
        self.texturePool = texturePool
        self.strategy = strategy
    }

    open func dequeueTexture(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             allowsSizeTolerance: Bool = false) -> MTLTexture? {
        textureRequestCount += 1
        let texture: MTLTexture?
        if allowsSizeTolerance {
            allocatorDecisions.append("dequeueToleranceMatch")
            texture = texturePool.dequeueTexture(width: width, height: height, pixelFormat: pixelFormat)
        } else {
            allocatorDecisions.append("dequeueExactMatch")
            texture = texturePool.dequeueExactTexture(width: width, height: height, pixelFormat: pixelFormat)
        }
        if texture != nil {
            textureReuseHitCount += 1
        }
        return texture
    }

    open func dequeueTextureLease(width: Int,
                                  height: Int,
                                  pixelFormat: MTLPixelFormat,
                                  allowsSizeTolerance: Bool = false,
                                  logicalExtent: C7Size? = nil) -> TextureLease? {
        textureRequestCount += 1
        let lease = texturePool.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance,
            logicalExtent: logicalExtent
        )
        allocatorDecisions.append(allowsSizeTolerance ? "leaseToleranceMatch" : "leaseExactMatch")
        if lease != nil {
            textureReuseHitCount += 1
        }
        return lease
    }

    open func makeLease(for texture: MTLTexture, logicalExtent: C7Size? = nil) -> TextureLease {
        texturePool.makeLease(for: texture, logicalExtent: logicalExtent)
    }

    open func enqueueTextureSync(_ texture: MTLTexture) {
        texturePool.enqueueTextureSync(texture)
    }

    open func makeSnapshot() -> TextureAllocatorSnapshot {
        TextureAllocatorSnapshot(
            allocationStrategy: strategy,
            textureRequestCount: textureRequestCount,
            textureReuseHitCount: textureReuseHitCount,
            heapBackedAllocationCount: heapBackedAllocationCount,
            allocatorDecisions: Array(allocatorDecisions.suffix(32))
        )
    }

    public func recordHeapBackedAllocation() {
        heapBackedAllocationCount += 1
        allocatorDecisions.append("heapBackedAllocation")
    }
}

public final class ExactTextureAllocator: TexturePoolAllocator {
    public init(texturePool: TexturePool) {
        super.init(texturePool: texturePool, strategy: .exact)
    }

    public override func dequeueTexture(width: Int,
                                        height: Int,
                                        pixelFormat: MTLPixelFormat,
                                        allowsSizeTolerance: Bool = false) -> MTLTexture? {
        super.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: false
        )
    }

    public override func dequeueTextureLease(width: Int,
                                             height: Int,
                                             pixelFormat: MTLPixelFormat,
                                             allowsSizeTolerance: Bool = false,
                                             logicalExtent: C7Size? = nil) -> TextureLease? {
        super.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: false,
            logicalExtent: logicalExtent
        )
    }
}

public final class TolerantTextureAllocator: TexturePoolAllocator {
    public init(texturePool: TexturePool) {
        super.init(texturePool: texturePool, strategy: .tolerant)
    }

    public override func dequeueTexture(width: Int,
                                        height: Int,
                                        pixelFormat: MTLPixelFormat,
                                        allowsSizeTolerance: Bool = true) -> MTLTexture? {
        super.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: true
        )
    }

    public override func dequeueTextureLease(width: Int,
                                             height: Int,
                                             pixelFormat: MTLPixelFormat,
                                             allowsSizeTolerance: Bool = true,
                                             logicalExtent: C7Size? = nil) -> TextureLease? {
        super.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: true,
            logicalExtent: logicalExtent
        )
    }
}

public final class HeapBackedTextureAllocator: TexturePoolAllocator {
    public init(texturePool: TexturePool) {
        super.init(texturePool: texturePool, strategy: .heapBacked)
    }

    public override func dequeueTexture(width: Int,
                                        height: Int,
                                        pixelFormat: MTLPixelFormat,
                                        allowsSizeTolerance: Bool = false) -> MTLTexture? {
        let texture = super.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance
        )
        if texture == nil {
            recordHeapBackedAllocation()
        }
        return texture
    }

    public override func dequeueTextureLease(width: Int,
                                             height: Int,
                                             pixelFormat: MTLPixelFormat,
                                             allowsSizeTolerance: Bool = false,
                                             logicalExtent: C7Size? = nil) -> TextureLease? {
        let lease = super.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance,
            logicalExtent: logicalExtent
        )
        if lease == nil {
            recordHeapBackedAllocation()
        }
        return lease
    }
}
