//
//  TextureAllocator.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
@preconcurrency import Metal

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
        guard self == .heapBacked, !heapTexturePoolSupported else { return nil }
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
    public let heapCount: Int
    public let heapReservedMemory: Int
    public let heapUsedMemory: Int
    public let heapAllocationFallbackCount: Int
    public let allocatorDecisions: [String]

    public init(allocationStrategy: TextureAllocationStrategy,
                requestedAllocationStrategy: TextureAllocationStrategy? = nil,
                allocationFallbackReason: String? = nil,
                textureRequestCount: Int,
                textureReuseHitCount: Int,
                heapBackedAllocationCount: Int,
                heapCount: Int = 0,
                heapReservedMemory: Int = 0,
                heapUsedMemory: Int = 0,
                heapAllocationFallbackCount: Int = 0,
                allocatorDecisions: [String]) {
        self.allocationStrategy = allocationStrategy
        self.requestedAllocationStrategy = requestedAllocationStrategy
        self.allocationFallbackReason = allocationFallbackReason
        self.textureRequestCount = textureRequestCount
        self.textureReuseHitCount = textureReuseHitCount
        self.heapBackedAllocationCount = heapBackedAllocationCount
        self.heapCount = heapCount
        self.heapReservedMemory = heapReservedMemory
        self.heapUsedMemory = heapUsedMemory
        self.heapAllocationFallbackCount = heapAllocationFallbackCount
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
    func dequeueTexture(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool) -> MTLTexture?
    func dequeueTextureLease(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool, logicalExtent: C7Size?) -> TextureLease?
    func makeTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture?
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
    private let stateLock = NSLock()
    private var textureRequestCount = 0
    private var textureReuseHitCount = 0
    private var heapBackedAllocationCount = 0
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

    func resolvedAllowsSizeTolerance(_ requested: Bool,
                                     pixelFormat: MTLPixelFormat,
                                     decisionRecorder: ((String) -> Void)? = nil) -> Bool {
        requested
    }

    func dequeueTexture(width: Int,
                        height: Int,
                        pixelFormat: MTLPixelFormat,
                        allowsSizeTolerance: Bool = false) -> MTLTexture? {
        recordRequest()
        let allowsTolerance = resolvedTolerance(allowsSizeTolerance, pixelFormat: pixelFormat)
        recordDecision(allowsTolerance ? "dequeueToleranceMatch" : "dequeueExactMatch")
        let texture = allowsTolerance
            ? texturePool.dequeueTexture(width: width, height: height, pixelFormat: pixelFormat)
            : texturePool.dequeueExactTexture(width: width, height: height, pixelFormat: pixelFormat)
        if let texture { recordReuse(texture: texture) }
        return texture
    }

    func dequeueTextureLease(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             allowsSizeTolerance: Bool = false,
                             logicalExtent: C7Size? = nil) -> TextureLease? {
        recordRequest()
        let allowsTolerance = resolvedTolerance(allowsSizeTolerance, pixelFormat: pixelFormat)
        let lease = texturePool.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsTolerance,
            logicalExtent: logicalExtent
        )
        recordDecision(allowsTolerance ? "leaseToleranceMatch" : "leaseExactMatch")
        if let lease { recordReuse(texture: lease.texture) }
        return lease
    }

    func dequeueTexture(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool = false) -> MTLTexture? {
        recordRequest()
        let allowsTolerance = resolvedTolerance(allowsSizeTolerance, pixelFormat: descriptor.pixelFormat)
        recordDecision(allowsTolerance ? "descriptorToleranceMatch" : "descriptorExactMatch")
        let texture = texturePool.dequeueTexture(matching: descriptor, allowsSizeTolerance: allowsTolerance)
        if let texture { recordReuse(texture: texture) }
        return texture
    }

    func dequeueTextureLease(matching descriptor: MTLTextureDescriptor,
                             allowsSizeTolerance: Bool = false,
                             logicalExtent: C7Size? = nil) -> TextureLease? {
        recordRequest()
        let allowsTolerance = resolvedTolerance(allowsSizeTolerance, pixelFormat: descriptor.pixelFormat)
        let lease = texturePool.dequeueTextureLease(
            matching: descriptor,
            allowsSizeTolerance: allowsTolerance,
            logicalExtent: logicalExtent
        )
        recordDecision(allowsTolerance ? "descriptorLeaseToleranceMatch" : "descriptorLeaseExactMatch")
        if let lease { recordReuse(texture: lease.texture) }
        return lease
    }

    func makeTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture? {
        recordDecision("deviceTextureAllocation")
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        recordObservedAllocation(texture, heapBacked: false)
        return texture
    }

    func makeLease(for texture: MTLTexture, logicalExtent: C7Size? = nil) -> TextureLease {
        texturePool.makeLease(for: texture, logicalExtent: logicalExtent)
    }

    func enqueueTextureSync(_ texture: MTLTexture) {
        texturePool.enqueueTextureSync(texture)
    }

    func makeSnapshot() -> TextureAllocatorSnapshot {
        stateLock.lock()
        let requestCount = textureRequestCount
        let reuseCount = textureReuseHitCount
        let heapAllocationCount = heapBackedAllocationCount
        let decisions = Array(allocatorDecisions.suffix(32))
        stateLock.unlock()
        let poolStatistics = texturePool.statistics
        return TextureAllocatorSnapshot(
            allocationStrategy: strategy,
            requestedAllocationStrategy: requestedStrategy,
            allocationFallbackReason: allocationFallbackReason,
            textureRequestCount: requestCount,
            textureReuseHitCount: reuseCount,
            heapBackedAllocationCount: heapAllocationCount,
            heapCount: poolStatistics.heapCount,
            heapReservedMemory: poolStatistics.heapReservedMemory,
            heapUsedMemory: poolStatistics.heapUsedMemory,
            heapAllocationFallbackCount: poolStatistics.heapAllocationFallbackCount,
            allocatorDecisions: decisions
        )
    }

    func recordHeapBackedAllocation() {
        stateLock.lock()
        heapBackedAllocationCount += 1
        allocatorDecisions.append("heapBackedAllocation")
        stateLock.unlock()
    }

    func recordObservedAllocation(_ texture: MTLTexture, heapBacked: Bool) {
        RenderResourceObservationScope.current?.recordAllocation(texture: texture, heapBacked: heapBacked)
    }

    func recordDecision(_ decision: String) {
        stateLock.lock()
        allocatorDecisions.append(decision)
        if allocatorDecisions.count > 128 {
            allocatorDecisions.removeFirst(allocatorDecisions.count - 128)
        }
        stateLock.unlock()
    }

    private func recordRequest() {
        stateLock.lock()
        textureRequestCount += 1
        stateLock.unlock()
        RenderResourceObservationScope.current?.recordRequest()
    }

    private func recordReuse(texture: MTLTexture? = nil) {
        stateLock.lock()
        textureReuseHitCount += 1
        stateLock.unlock()
        if let texture {
            RenderResourceObservationScope.current?.recordReuse(texture: texture)
        }
    }

    private func resolvedTolerance(_ requested: Bool, pixelFormat: MTLPixelFormat) -> Bool {
        resolvedAllowsSizeTolerance(
            requested,
            pixelFormat: pixelFormat,
            decisionRecorder: { [weak self] in self?.recordDecision($0) }
        )
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

    override func resolvedAllowsSizeTolerance(_ requested: Bool,
                                              pixelFormat: MTLPixelFormat,
                                              decisionRecorder: ((String) -> Void)? = nil) -> Bool {
        requested
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

    override func resolvedAllowsSizeTolerance(_ requested: Bool,
                                              pixelFormat: MTLPixelFormat,
                                              decisionRecorder: ((String) -> Void)? = nil) -> Bool {
        guard requested else { return false }
        guard !PixelFormatContract(pixelFormat: pixelFormat, preservesInput: false).isHighPrecision else {
            decisionRecorder?("highPrecisionForcesExactMatch")
            return false
        }
        return true
    }

    override func dequeueTexture(width: Int,
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

    override func dequeueTexture(matching descriptor: MTLTextureDescriptor,
                                 allowsSizeTolerance: Bool = true) -> MTLTexture? {
        super.dequeueTexture(matching: descriptor, allowsSizeTolerance: true)
    }

    override func dequeueTextureLease(matching descriptor: MTLTextureDescriptor,
                                      allowsSizeTolerance: Bool = true,
                                      logicalExtent: C7Size? = nil) -> TextureLease? {
        super.dequeueTextureLease(
            matching: descriptor,
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

    override func makeTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture? {
        if let texture = texturePool.makeHeapTexture(descriptor: descriptor, device: device) {
            recordHeapBackedAllocation()
            recordObservedAllocation(texture, heapBacked: true)
            return texture
        }
        recordDecision("heapAllocationFallbackToDevice")
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        recordObservedAllocation(texture, heapBacked: false)
        return texture
    }
}
