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

    public func resolvedStrategy(heapTexturePoolSupported: Bool) -> TextureAllocationStrategy {
        switch self {
        case .heapBacked:
            return heapTexturePoolSupported ? .heapBacked : .exact
        case .exact, .tolerant:
            return self
        }
    }

    public func fallbackReason(heapTexturePoolSupported: Bool) -> String? {
        guard self == .heapBacked, heapTexturePoolSupported == false else { return nil }
        return "unsupportedHeapTexturePoolCapabilityFallbackToExact"
    }

    func makeAllocator(texturePool: TexturePool, heapTexturePoolSupported: Bool) -> TextureAllocator {
        let resolved = resolvedStrategy(heapTexturePoolSupported: heapTexturePoolSupported)
        let fallbackReason = fallbackReason(heapTexturePoolSupported: heapTexturePoolSupported)
        switch resolved {
        case .exact:
            return ExactTextureAllocator(
                texturePool: texturePool,
                requestedStrategy: self,
                allocationFallbackReason: fallbackReason
            )
        case .tolerant:
            return TolerantTextureAllocator(
                texturePool: texturePool,
                requestedStrategy: self,
                allocationFallbackReason: fallbackReason
            )
        case .heapBacked:
            return HeapBackedTextureAllocator(
                texturePool: texturePool,
                requestedStrategy: self,
                allocationFallbackReason: fallbackReason
            )
        }
    }

    func makeAllocator(texturePool: TexturePool, on device: MTLDevice? = nil) -> TextureAllocator {
        let report = Device.metalCapabilityReport(.heapTexturePool, on: device)
        return makeAllocator(texturePool: texturePool, heapTexturePoolSupported: report.isSupported)
    }
}

public struct TextureAllocationResolution: Sendable, Codable, Equatable, Hashable {
    public let requested: TextureAllocationStrategy
    public let resolved: TextureAllocationStrategy
    public let fallbackReason: String?

    public init(requested: TextureAllocationStrategy, resolved: TextureAllocationStrategy, fallbackReason: String? = nil) {
        self.requested = requested
        self.resolved = resolved
        self.fallbackReason = fallbackReason
    }

    public var isFallback: Bool {
        requested != resolved
    }

    public var fingerprint: String {
        [
            "requested=\(requested.rawValue)",
            "resolved=\(resolved.rawValue)",
            "fallback=\(fallbackReason ?? "none")"
        ].joined(separator: "|")
    }
}

public struct TextureAllocatorSnapshot: Sendable, Codable, Equatable, Hashable {
    public let allocationStrategy: TextureAllocationStrategy
    public let requestedAllocationStrategy: TextureAllocationStrategy?
    public let allocationFallbackReason: String?
    public let textureRequestCount: Int
    public let textureReuseHitCount: Int
    public let heapBackedAllocationCount: Int
    public let allocatorDecisions: [String]

    public init(allocationStrategy: TextureAllocationStrategy,
                requestedAllocationStrategy: TextureAllocationStrategy? = nil,
                allocationFallbackReason: String? = nil,
                textureRequestCount: Int,
                textureReuseHitCount: Int,
                heapBackedAllocationCount: Int,
                allocatorDecisions: [String]) {
        self.allocationStrategy = allocationStrategy
        self.requestedAllocationStrategy = requestedAllocationStrategy
        self.allocationFallbackReason = allocationFallbackReason
        self.textureRequestCount = textureRequestCount
        self.textureReuseHitCount = textureReuseHitCount
        self.heapBackedAllocationCount = heapBackedAllocationCount
        self.allocatorDecisions = allocatorDecisions
    }

    public var textureReuseHitRatio: Double {
        guard textureRequestCount > 0 else { return 0 }
        return min(max(Double(textureReuseHitCount) / Double(textureRequestCount), 0), 1)
    }

    public var allocationResolution: TextureAllocationResolution {
        TextureAllocationResolution(
            requested: requestedAllocationStrategy ?? allocationStrategy,
            resolved: allocationStrategy,
            fallbackReason: allocationFallbackReason
        )
    }
}

protocol TextureAllocating: AnyObject {
    func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool) -> MTLTexture?
    func dequeueTextureLease(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool, logicalExtent: C7Size?) -> TextureLease?
    func makeLease(for texture: MTLTexture, logicalExtent: C7Size?) -> TextureLease
    func enqueueTextureSync(_ texture: MTLTexture)
}

protocol TextureAllocator: TextureAllocating {
    var strategy: TextureAllocationStrategy { get }
    func makeSnapshot() -> TextureAllocatorSnapshot
}

class TexturePoolAllocator: TextureAllocator {
    let texturePool: TexturePool
    let strategy: TextureAllocationStrategy
    let requestedStrategy: TextureAllocationStrategy?
    let allocationFallbackReason: String?
    private var textureRequestCount: Int = 0
    private var textureReuseHitCount: Int = 0
    private var heapBackedAllocationCount: Int = 0
    private var allocatorDecisions: [String] = []

    init(texturePool: TexturePool,
         strategy: TextureAllocationStrategy = .exact,
         requestedStrategy: TextureAllocationStrategy? = nil,
         allocationFallbackReason: String? = nil) {
        self.texturePool = texturePool
        self.strategy = strategy
        self.requestedStrategy = requestedStrategy
        self.allocationFallbackReason = allocationFallbackReason
    }

    func resolvedAllowsSizeTolerance(_ requested: Bool, pixelFormat: MTLPixelFormat, decisionRecorder: ((String) -> Void)? = nil) -> Bool {
        requested
    }

    func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool = false) -> MTLTexture? {
        textureRequestCount += 1
        let allowsSizeTolerance = resolvedAllowsSizeTolerance(
            allowsSizeTolerance,
            pixelFormat: pixelFormat,
            decisionRecorder: { [weak self] decision in
                self?.allocatorDecisions.append(decision)
            }
        )
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

    func dequeueTextureLease(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool = false, logicalExtent: C7Size? = nil) -> TextureLease? {
        textureRequestCount += 1
        let allowsSizeTolerance = resolvedAllowsSizeTolerance(
            allowsSizeTolerance,
            pixelFormat: pixelFormat,
            decisionRecorder: { [weak self] decision in
                self?.allocatorDecisions.append(decision)
            }
        )
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

    func makeLease(for texture: MTLTexture, logicalExtent: C7Size? = nil) -> TextureLease {
        texturePool.makeLease(for: texture, logicalExtent: logicalExtent)
    }

    func enqueueTextureSync(_ texture: MTLTexture) {
        texturePool.enqueueTextureSync(texture)
    }

    func makeSnapshot() -> TextureAllocatorSnapshot {
        TextureAllocatorSnapshot(
            allocationStrategy: strategy,
            requestedAllocationStrategy: requestedStrategy,
            allocationFallbackReason: allocationFallbackReason,
            textureRequestCount: textureRequestCount,
            textureReuseHitCount: textureReuseHitCount,
            heapBackedAllocationCount: heapBackedAllocationCount,
            allocatorDecisions: Array(allocatorDecisions.suffix(32))
        )
    }

    func recordHeapBackedAllocation() {
        heapBackedAllocationCount += 1
        allocatorDecisions.append("heapBackedAllocation")
    }
}

final class ExactTextureAllocator: TexturePoolAllocator {
    init(texturePool: TexturePool, requestedStrategy: TextureAllocationStrategy? = nil, allocationFallbackReason: String? = nil) {
        super.init(
            texturePool: texturePool,
            strategy: .exact,
            requestedStrategy: requestedStrategy,
            allocationFallbackReason: allocationFallbackReason
        )
    }

    override func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool = false) -> MTLTexture? {
        super.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: false
        )
    }

    override func dequeueTextureLease(width: Int,
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

final class TolerantTextureAllocator: TexturePoolAllocator {
    init(texturePool: TexturePool, requestedStrategy: TextureAllocationStrategy? = nil, allocationFallbackReason: String? = nil) {
        super.init(
            texturePool: texturePool,
            strategy: .tolerant,
            requestedStrategy: requestedStrategy,
            allocationFallbackReason: allocationFallbackReason
        )
    }

    override func resolvedAllowsSizeTolerance(_ requested: Bool, pixelFormat: MTLPixelFormat, decisionRecorder: ((String) -> Void)? = nil) -> Bool {
        guard requested else { return false }
        guard !PixelFormatContract(pixelFormat: pixelFormat, preservesInput: false).isHighPrecision else {
            decisionRecorder?("highPrecisionForcesExactMatch")
            return false
        }
        return true
    }

    override func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool = true) -> MTLTexture? {
        super.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: true
        )
    }

    override func dequeueTextureLease(width: Int,
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

final class HeapBackedTextureAllocator: TexturePoolAllocator {
    init(texturePool: TexturePool, requestedStrategy: TextureAllocationStrategy? = nil, allocationFallbackReason: String? = nil) {
        super.init(
            texturePool: texturePool,
            strategy: .heapBacked,
            requestedStrategy: requestedStrategy,
            allocationFallbackReason: allocationFallbackReason
        )
    }

    override func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, allowsSizeTolerance: Bool = false) -> MTLTexture? {
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

    override func dequeueTextureLease(width: Int,
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
