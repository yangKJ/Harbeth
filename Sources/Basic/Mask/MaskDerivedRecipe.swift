//
//  MaskDerivedRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/19.
//

import Foundation
import Metal

public enum MaskDerivedOperation: Sendable, Equatable, Hashable {
    case threshold(Float)
    case grow(radius: Int)
    case shrink(radius: Int)
    case innerEdge(radius: Int)
    case outerEdge(radius: Int)
    case edge(radius: Int)
    case distanceField(maxDistance: Float, threshold: Float)
    case smartFeather(radius: Int, edgeSensitivity: Float)
    case shiftEdge(pixels: Float, maxDistance: Float)
    case feather(innerRadius: Float, outerRadius: Float, maxDistance: Float)
    case edgeCleanup(blackPoint: Float, whitePoint: Float)
    case contractEdge(radius: Int)

    var fingerprint: String {
        switch self {
        case .threshold(let value): return "threshold(\(Self.float(value)))"
        case .grow(let radius): return "grow(\(max(radius, 0)))"
        case .shrink(let radius): return "shrink(\(max(radius, 0)))"
        case .innerEdge(let radius): return "innerEdge(\(max(radius, 1)))"
        case .outerEdge(let radius): return "outerEdge(\(max(radius, 1)))"
        case .edge(let radius): return "edge(\(max(radius, 1)))"
        case .distanceField(let distance, let threshold): return "distance(\(Self.float(distance)),\(Self.float(threshold)))"
        case .smartFeather(let radius, let sensitivity): return "smartFeather(\(max(radius, 1)),\(Self.float(sensitivity)))"
        case .shiftEdge(let pixels, let distance): return "shiftEdge(\(Self.float(pixels)),\(Self.float(distance)))"
        case .feather(let inner, let outer, let distance): return "feather(\(Self.float(inner)),\(Self.float(outer)),\(Self.float(distance)))"
        case .edgeCleanup(let black, let white): return "cleanup(\(Self.float(black)),\(Self.float(white)))"
        case .contractEdge(let radius): return "contractEdge(\(max(radius, 1)))"
        }
    }

    private static func float(_ value: Float) -> String {
        String(format: "%.4f", value.isFinite ? value : 0)
    }
}
public struct MaskExecutionPlan: Sendable, Equatable {
    public let operations: [MaskDerivedOperation]
    public let eliminatedOperationCount: Int

    public var passCount: Int { operations.count }

    public var maximumHalo: Int {
        operations.reduce(0) { current, operation in
            switch operation {
            case .grow(let radius), .shrink(let radius),
                 .innerEdge(let radius), .outerEdge(let radius), .edge(let radius),
                 .contractEdge(let radius):
                return max(current, max(radius, 0))
            case .smartFeather(let radius, _):
                return max(current, max(radius, 0))
            case .distanceField(let distance, _):
                return max(current, Int(ceil(max(distance, 0))))
            case .shiftEdge(let pixels, let distance):
                return max(current, Int(ceil(max(abs(pixels), max(distance, 0)))))
            case .feather(let inner, let outer, let distance):
                return max(current, Int(ceil(max(inner, outer, distance))))
            case .threshold, .edgeCleanup:
                return current
            }
        }
    }
}

public struct MaskExecutionDiagnostics: Sendable, Equatable {
    public let passCount: Int
    public let eliminatedOperationCount: Int
    public let maximumHalo: Int
    public let estimatedIntermediateByteCount: Int
    public let allocationStrategy: TextureAllocationStrategy
    public let cacheHit: Bool
    public let dirtyBounds: MaskCoverageBounds?
}

enum MaskGraphCompiler {
    static func compile(_ operations: [MaskDerivedOperation]) -> MaskExecutionPlan {
        var result: [MaskDerivedOperation] = []
        for operation in operations {
            switch operation {
            case .grow(let radius) where radius <= 0,
                 .shrink(let radius) where radius <= 0:
                continue
            case .threshold:
                if case .threshold = result.last { result.removeLast() }
                result.append(operation)
            case .grow(let radius):
                if case .grow(let existing) = result.last {
                    result[result.count - 1] = .grow(radius: min(existing + radius, 32))
                } else {
                    result.append(.grow(radius: min(max(radius, 0), 32)))
                }
            case .shrink(let radius):
                if case .shrink(let existing) = result.last {
                    result[result.count - 1] = .shrink(radius: min(existing + radius, 32))
                } else {
                    result.append(.shrink(radius: min(max(radius, 0), 32)))
                }
            default:
                result.append(operation)
            }
        }
        return MaskExecutionPlan(
            operations: result,
            eliminatedOperationCount: max(operations.count - result.count, 0)
        )
    }
}

public struct MaskDerivedResult: @unchecked Sendable {
    public let texture: MTLTexture
    public let analysis: MaskAnalysis
    public let plan: MaskExecutionPlan
    public let cacheHit: Bool
    public let diagnostics: MaskExecutionDiagnostics

    public var dirtyBounds: MaskCoverageBounds? { diagnostics.dirtyBounds }
}

final class MaskExecutionCache: @unchecked Sendable {
    static let shared = MaskExecutionCache(usesContextStore: true)

    private final class EntryBox {
        let result: MaskDerivedResult
        init(_ result: MaskDerivedResult) { self.result = result }
    }

    private let usesContextStore: Bool
    private let localStore: DerivedResourceStore?

    private init(usesContextStore: Bool) {
        self.usesContextStore = usesContextStore
        self.localStore = nil
    }

    init(countLimit: Int = 48, byteLimit: Int = 64 * 1024 * 1024) {
        self.usesContextStore = false
        self.localStore = DerivedResourceStore(
            configuration: DerivedResourceCacheConfiguration(byteLimit: byteLimit, countLimit: countLimit)
        )
    }

    func removeAll() {
        store.invalidate(domain: .mask)
    }

    fileprivate func lookup(for key: String) -> (result: MaskDerivedResult?, identity: DerivedResourceIdentity) {
        let identity = store.makeIdentity(domain: .mask, fingerprint: key)
        let result = (store.value(for: identity) as? EntryBox)?.result
        return (result, identity)
    }

    fileprivate func insert(_ result: MaskDerivedResult, for identity: DerivedResourceIdentity) {
        store.insert(EntryBox(result), byteCost: max(result.texture.allocatedSize, 1), for: identity)
    }

    private var store: DerivedResourceStore {
        usesContextStore ? Shared.shared.defaultContext.derivedResourceStore : localStore!
    }
}

/// 一等派生蒙版图，覆盖编译、取消、缓存、分析与脏区诊断。
public struct MaskDerivedRecipe: @unchecked Sendable {
    public let baseMask: MaskDescriptor
    public let sourceIdentifier: String
    public let guideTexture: MTLTexture?
    /// `smartFeather` 的可选单通道置信度；内部会统一归一化为 coverage 纹理。
    public let guideConfidenceTexture: MTLTexture?
    public var operations: [MaskDerivedOperation]
    public var profile: RenderProfile
    public var storageFormat: MaskStorageFormat

    public init(baseMask: MaskDescriptor,
                sourceIdentifier: String,
                guideTexture: MTLTexture? = nil,
                guideConfidenceTexture: MTLTexture? = nil,
                operations: [MaskDerivedOperation],
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.baseMask = baseMask
        self.sourceIdentifier = sourceIdentifier
        self.guideTexture = guideTexture
        self.guideConfidenceTexture = guideConfidenceTexture
        self.operations = operations
        self.profile = profile
        self.storageFormat = storageFormat
    }

    public var compiledPlan: MaskExecutionPlan { MaskGraphCompiler.compile(operations) }

    public var fingerprint: String {
        [
            "source=\(sourceIdentifier)",
            "base=\(baseMask.graphDescriptor.fingerprint)",
            "guideConfidence=\(guideConfidenceTexture == nil ? 0 : 1)",
            "operations=\(compiledPlan.operations.map(\.fingerprint).joined(separator: ";"))",
            "storage=\(storageFormat.rawValue)",
            "profile=\(profile.rawValue)"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor { graphDescriptor() }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskDerivedRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: compiledPlan.passCount,
            steps: [],
            gradient: nil,
            shape: nil,
            path: nil
        )
    }

    public func execute(cancellation: TextureMultiPassCancellationToken? = nil) throws -> MaskDerivedResult {
        try execute(cancellation: cancellation, cache: .shared)
    }

    func execute(cancellation: TextureMultiPassCancellationToken? = nil,
                 cache: MaskExecutionCache?) throws -> MaskDerivedResult {
        let executionCacheKey = executionCacheKey
        let cacheLookup = cache?.lookup(for: executionCacheKey)
        if let cached = cacheLookup?.result {
            return MaskDerivedResult(
                texture: cached.texture,
                analysis: cached.analysis,
                plan: cached.plan,
                cacheHit: true,
                diagnostics: Self.diagnostics(
                    plan: cached.plan,
                    texture: cached.texture,
                    cacheHit: true,
                    dirtyBounds: cached.diagnostics.dirtyBounds
                )
            )
        }
        try checkCancellation(cancellation)
        let plan = compiledPlan
        let dirtyBounds = Self.expandedDirtyBounds(
            baseMask.plane.descriptor.lastModifiedBounds,
            halo: plan.maximumHalo,
            width: baseMask.texture.width,
            height: baseMask.texture.height
        )
        var current = try MaskProcessingRecipe(mask: baseMask).makeCoverageTexture()
        for operation in plan.operations {
            try checkCancellation(cancellation)
            current = try apply(operation, to: current)
            try checkCancellation(cancellation)
        }
        current = try convert(current, to: storageFormat.pixelFormat)
        let analysis = try MaskGPUAnalysisBackend.analyze(texture: current, threshold: 0.001)
        let result = MaskDerivedResult(
            texture: current,
            analysis: analysis,
            plan: plan,
            cacheHit: false,
            diagnostics: Self.diagnostics(
                plan: plan,
                texture: current,
                cacheHit: false,
                dirtyBounds: dirtyBounds
            )
        )
        if let cacheLookup {
            cache?.insert(result, for: cacheLookup.identity)
        }
        return result
    }

    public func makeTexture() throws -> MTLTexture { try execute().texture }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}

private extension MaskDerivedRecipe {
    static func diagnostics(plan: MaskExecutionPlan,
                            texture: MTLTexture,
                            cacheHit: Bool,
                            dirtyBounds: MaskCoverageBounds?) -> MaskExecutionDiagnostics {
        MaskExecutionDiagnostics(
            passCount: plan.passCount,
            eliminatedOperationCount: plan.eliminatedOperationCount,
            maximumHalo: plan.maximumHalo,
            estimatedIntermediateByteCount: max(texture.allocatedSize, 1) * max(plan.passCount, 1),
            allocationStrategy: Shared.shared.defaultTextureAllocationStrategy,
            cacheHit: cacheHit,
            dirtyBounds: dirtyBounds
        )
    }

    /// 公开图指纹保持确定性；内存执行缓存还必须区分实际引导纹理与蒙版资源版本。
    var executionCacheKey: String {
        var key = "\(fingerprint)|baseIdentity=\(baseMask.plane.descriptor.resourceIdentity.fingerprint)"
        if let guideTexture {
            key += "|guideTexture=\(ObjectIdentifier(guideTexture as AnyObject))"
        }
        if let guideConfidenceTexture {
            key += "|guideConfidenceTexture=\(ObjectIdentifier(guideConfidenceTexture as AnyObject))"
        }
        return key
    }

    func apply(_ operation: MaskDerivedOperation, to texture: MTLTexture) throws -> MTLTexture {
        let descriptor = MaskDescriptor(texture: texture, component: .red)
        switch operation {
        case .threshold(let value):
            return try HarbethIO(element: texture, filter: MaskPointThreshold(threshold: value)).configured(for: profile).output()
        case .grow(let radius):
            return try morphology(.dilation, radius: radius, texture: texture)
        case .shrink(let radius):
            return try morphology(.erosion, radius: radius, texture: texture)
        case .innerEdge(let radius):
            return try MaskMorphologyRecipe(operation: .erosion, kernelSize: radius * 2 + 1).makeEdgeBand(from: descriptor, kind: .inner)
        case .outerEdge(let radius):
            return try MaskMorphologyRecipe(operation: .dilation, kernelSize: radius * 2 + 1).makeEdgeBand(from: descriptor, kind: .outer)
        case .edge(let radius):
            return try MaskMorphologyRecipe(operation: .dilation, kernelSize: radius * 2 + 1).makeEdgeBand(from: descriptor, kind: .blend)
        case .distanceField(let maxDistance, let threshold):
            return try MaskDistanceFieldRecipe(maxDistance: maxDistance, threshold: threshold).makeTexture(from: descriptor)
        case .smartFeather(let radius, let sensitivity):
            guard let guideTexture,
                  guideTexture.width == texture.width,
                  guideTexture.height == texture.height else {
                throw HarbethError.textureSizeMismatch
            }
            return try MaskGuidedRefinementRecipe(
                radius: radius,
                epsilon: max(0.000_01, pow(1 - min(max(sensitivity, 0), 1), 2) * 0.02),
                coefficientScale: profile == .exportQuality ? 1 : 0.5,
                storageFormat: storageFormat
            ).makePlane(
                from: descriptor,
                guidanceTexture: guideTexture,
                confidenceTexture: guideConfidenceTexture
            ).texture
        case .shiftEdge(let pixels, let maxDistance):
            return try MaskEdgeRefinementRecipe(
                shift: pixels,
                maxDistance: maxDistance,
                profile: profile
            ).makePlane(from: descriptor, storageFormat: storageFormat).texture
        case .feather(let innerRadius, let outerRadius, let maxDistance):
            return try MaskEdgeRefinementRecipe(
                innerFeather: innerRadius,
                outerFeather: outerRadius,
                maxDistance: maxDistance,
                profile: profile
            ).makePlane(from: descriptor, storageFormat: storageFormat).texture
        case .edgeCleanup(let blackPoint, let whitePoint):
            return try HarbethIO(
                element: texture,
                filter: MaskEdgeCleanup(blackPoint: blackPoint, whitePoint: whitePoint)
            ).configured(for: profile).output()
        case .contractEdge(let radius):
            let contracted = try morphology(.erosion, radius: radius, texture: texture)
            return try HarbethIO(
                element: contracted,
                filter: MaskEdgeCleanup(blackPoint: 0.08, whitePoint: 0.92)
            ).configured(for: profile).output()
        }
    }

    func morphology(_ operation: MaskMorphologyOperation, radius: Int, texture: MTLTexture) throws -> MTLTexture {
        var output = texture
        var remaining = min(max(radius, 0), 32)
        while remaining > 0 {
            let passRadius = min(remaining, 4)
            output = try MaskMorphologyRecipe(operation: operation, kernelSize: passRadius * 2 + 1)
                .makeTexture(from: MaskDescriptor(texture: output, component: .red))
            remaining -= passRadius
        }
        return output
    }

    func convert(_ texture: MTLTexture, to pixelFormat: MTLPixelFormat) throws -> MTLTexture {
        guard texture.pixelFormat != pixelFormat else { return texture }
        var io = HarbethIO(
            element: texture,
            filter: MaskCoverageExtract(mask: MaskDescriptor(texture: texture, component: .red))
        ).configured(for: profile)
        io.bufferPixelFormat = pixelFormat
        return try io.output()
    }

    func checkCancellation(_ token: TextureMultiPassCancellationToken?) throws {
        if token?.isCancelled == true { throw TextureMultiPassError.cancelled }
    }

    static func expandedDirtyBounds(_ bounds: MaskCoverageBounds?,
                                    halo: Int,
                                    width: Int,
                                    height: Int) -> MaskCoverageBounds? {
        guard let bounds else { return nil }
        let expansion = max(halo, 0)
        let minX = max(bounds.x - expansion, 0)
        let minY = max(bounds.y - expansion, 0)
        let maxX = min(bounds.x + bounds.width + expansion, width)
        let maxY = min(bounds.y + bounds.height + expansion, height)
        guard maxX > minX, maxY > minY else { return nil }
        return MaskCoverageBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
