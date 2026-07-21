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
    case edgeCleanup(blackPoint: Float, whitePoint: Float)
    case decontaminate(radius: Int)

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
        case .edgeCleanup(let black, let white): return "cleanup(\(Self.float(black)),\(Self.float(white)))"
        case .decontaminate(let radius): return "decontaminate(\(max(radius, 1)))"
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
}

public enum MaskGraphCompiler {
    public static func compile(_ operations: [MaskDerivedOperation]) -> MaskExecutionPlan {
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

public struct MaskDerivedResult {
    public let texture: MTLTexture
    public let analysis: MaskAnalysis
    public let plan: MaskExecutionPlan
    public let cacheHit: Bool

    public var dirtyBounds: MaskCoverageBounds? { analysis.bounds }
}

public final class MaskExecutionCache {
    public static let shared = MaskExecutionCache()

    private final class EntryBox {
        let result: MaskDerivedResult
        init(_ result: MaskDerivedResult) { self.result = result }
    }

    private let cache = NSCache<NSString, EntryBox>()

    public init(countLimit: Int = 48) {
        cache.countLimit = max(countLimit, 1)
    }

    public func removeAll() { cache.removeAllObjects() }

    fileprivate func result(for key: String) -> MaskDerivedResult? {
        cache.object(forKey: key as NSString)?.result
    }

    fileprivate func insert(_ result: MaskDerivedResult, for key: String) {
        cache.setObject(EntryBox(result), forKey: key as NSString)
    }
}

/// First-class derived mask graph with compilation, cancellation, caching, analysis, and dirty bounds.
public struct MaskDerivedRecipe {
    public let baseMask: MaskDescriptor
    public let sourceIdentifier: String
    public let guideTexture: MTLTexture?
    public var operations: [MaskDerivedOperation]
    public var profile: RenderProfile
    public var storageFormat: MaskStorageFormat

    public init(baseMask: MaskDescriptor,
                sourceIdentifier: String,
                guideTexture: MTLTexture? = nil,
                operations: [MaskDerivedOperation],
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.baseMask = baseMask
        self.sourceIdentifier = sourceIdentifier
        self.guideTexture = guideTexture
        self.operations = operations
        self.profile = profile
        self.storageFormat = storageFormat
    }

    public var compiledPlan: MaskExecutionPlan { MaskGraphCompiler.compile(operations) }

    public var fingerprint: String {
        [
            "source=\(sourceIdentifier)",
            "base=\(baseMask.graphDescriptor.fingerprint)",
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

    public func execute(cancellation: TextureMultiPassCancellationToken? = nil,
                        cache: MaskExecutionCache? = .shared) throws -> MaskDerivedResult {
        let executionCacheKey = executionCacheKey
        if let cached = cache?.result(for: executionCacheKey) {
            return MaskDerivedResult(texture: cached.texture, analysis: cached.analysis, plan: cached.plan, cacheHit: true)
        }
        try checkCancellation(cancellation)
        let plan = compiledPlan
        var current = try MaskProcessingRecipe(mask: baseMask).makeCoverageTexture()
        for operation in plan.operations {
            try checkCancellation(cancellation)
            current = try apply(operation, to: current)
            try checkCancellation(cancellation)
        }
        current = try convert(current, to: storageFormat.pixelFormat)
        let analysis = try MaskGPUAnalysisBackend.analyze(texture: current, threshold: 0.001)
        let result = MaskDerivedResult(texture: current, analysis: analysis, plan: plan, cacheHit: false)
        cache?.insert(result, for: executionCacheKey)
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
    /// The public graph fingerprint remains deterministic, while the in-memory
    /// execution cache must also distinguish the concrete guide texture.
    var executionCacheKey: String {
        guard let guideTexture else { return fingerprint }
        return "\(fingerprint)|guideTexture=\(ObjectIdentifier(guideTexture as AnyObject))"
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
            return try HarbethIO(
                element: texture,
                filter: MaskEdgeAwareFeather(guideTexture: guideTexture, radius: radius, edgeSensitivity: sensitivity)
            ).configured(for: profile).output()
        case .edgeCleanup(let blackPoint, let whitePoint):
            return try HarbethIO(
                element: texture,
                filter: MaskEdgeCleanup(blackPoint: blackPoint, whitePoint: whitePoint)
            ).configured(for: profile).output()
        case .decontaminate(let radius):
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
}
