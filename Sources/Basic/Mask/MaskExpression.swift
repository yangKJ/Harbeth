//
//  MaskExpression.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import Metal

public indirect enum MaskExpression: @unchecked Sendable {
    case source(MaskDescriptor)
    case add(MaskExpression, MaskExpression)
    case intersect(MaskExpression, MaskExpression)
    case subtract(MaskExpression, MaskExpression)
    case exclude(MaskExpression, MaskExpression)
    case invert(MaskExpression)
    case opacity(MaskExpression, Float)

    public var fingerprint: String {
        switch self {
        case .source(let mask):
            return [
                "source(\(mask.plane.descriptor.resourceIdentity.fingerprint))",
                "component=\(mask.component.rawValue)",
                "invert=\(mask.invert ? 1 : 0)",
                "opacity=\(mask.opacity)",
                "feather=\(mask.featherPolicy.amount)"
            ].joined(separator: "|")
        case .add(let lhs, let rhs):
            return "add{\(lhs.fingerprint)}{\(rhs.fingerprint)}"
        case .intersect(let lhs, let rhs):
            return "intersect{\(lhs.fingerprint)}{\(rhs.fingerprint)}"
        case .subtract(let lhs, let rhs):
            return "subtract{\(lhs.fingerprint)}{\(rhs.fingerprint)}"
        case .exclude(let lhs, let rhs):
            return "exclude{\(lhs.fingerprint)}{\(rhs.fingerprint)}"
        case .invert(let value):
            return "invert{\(value.fingerprint)}"
        case .opacity(let value, let opacity):
            return "opacity(\(min(max(opacity, 0), 1))){\(value.fingerprint)}"
        }
    }
}

public struct MaskExpressionPlan: Sendable, Codable, Equatable, Hashable {
    public let nodeCount: Int
    public let passCount: Int
    public let commonSubexpressionCount: Int
    public let estimatedIntermediateByteCount: Int
    public let maximumLiveTextureCount: Int
    public let dirtyBounds: MaskCoverageBounds?
    public let allocationStrategy: TextureAllocationStrategy
    public let operations: [String]
}

struct MaskExpressionExecutionResult {
    let plane: MaskPlane
    let plan: MaskExpressionPlan
    let cacheHitCount: Int
}

enum MaskExpressionCompiler {
    static func compile(_ expression: MaskExpression) -> MaskExpressionPlan {
        var visited: Set<String> = []
        var nodeCount = 0
        var passCount = 0
        var reused = 0
        var estimatedBytes = 0
        var operations: [String] = []
        var dirtyBounds: MaskCoverageBounds?

        func visit(_ expression: MaskExpression) -> (width: Int, height: Int) {
            let key = expression.fingerprint
            if !visited.insert(key).inserted {
                reused += 1
                return extent(of: expression)
            }
            nodeCount += 1
            switch expression {
            case .source(let mask):
                dirtyBounds = union(dirtyBounds, mask.plane.descriptor.lastModifiedBounds)
                operations.append("source")
            case .invert(let value):
                _ = visit(value)
                operations.append("invertMetadata")
            case .opacity(let value, _):
                _ = visit(value)
                operations.append("opacityMetadata")
            case .add(let lhs, let rhs),
                 .intersect(let lhs, let rhs),
                 .subtract(let lhs, let rhs),
                 .exclude(let lhs, let rhs):
                let lhsExtent = visit(lhs)
                _ = visit(rhs)
                passCount += 1
                estimatedBytes += lhsExtent.width * lhsExtent.height * 2
                operations.append(operationName(expression))
            }
            return extent(of: expression)
        }
        _ = visit(expression)
        return MaskExpressionPlan(
            nodeCount: nodeCount,
            passCount: passCount,
            commonSubexpressionCount: reused,
            estimatedIntermediateByteCount: estimatedBytes,
            maximumLiveTextureCount: passCount == 0 ? 1 : 3,
            dirtyBounds: dirtyBounds,
            allocationStrategy: Shared.shared.defaultTextureAllocationStrategy,
            operations: operations
        )
    }
}

public extension MaskExpression {
    var compiledPlan: MaskExpressionPlan { MaskExpressionCompiler.compile(self) }
}

extension MaskExpression {
    func execute(profile: RenderProfile = .stablePreview, storageFormat: MaskStorageFormat = .coverage16Float) throws -> MaskExpressionExecutionResult {
        let plan = MaskExpressionCompiler.compile(self)
        var memo: [String: MaskDescriptor] = [:]
        var cacheHitCount = 0

        func evaluate(_ expression: MaskExpression) throws -> MaskDescriptor {
            let key = expression.fingerprint
            if let cached = memo[key] {
                cacheHitCount += 1
                return cached
            }
            let output: MaskDescriptor
            switch expression {
            case .source(let descriptor):
                output = descriptor
            case .invert(let value):
                var descriptor = try evaluate(value)
                descriptor.invert.toggle()
                output = descriptor
            case .opacity(let value, let opacity):
                var descriptor = try evaluate(value)
                descriptor.opacity = min(max(descriptor.opacity * opacity, 0), 1)
                output = descriptor
            case .add(let lhs, let rhs):
                output = try combine(lhs, rhs, mode: .add)
            case .intersect(let lhs, let rhs):
                output = try combine(lhs, rhs, mode: .multiply)
            case .subtract(let lhs, let rhs):
                output = try combine(lhs, rhs, mode: .subtract)
            case .exclude(let lhs, let rhs):
                output = try combine(lhs, rhs, mode: .exclude)
            }
            memo[key] = output
            return output
        }

        func combine(_ lhs: MaskExpression, _ rhs: MaskExpression, mode: MaskBlendMode) throws -> MaskDescriptor {
            let left = try evaluate(lhs)
            var right = try evaluate(rhs)
            guard left.texture.width == right.texture.width, left.texture.height == right.texture.height else {
                throw HarbethError.textureSizeMismatch
            }
            right.blendMode = mode
            var io = HarbethIO(
                element: left.texture,
                filter: MaskCoverageBlend(
                    baseComponent: left.component,
                    baseInvert: left.invert,
                    baseFeatherPolicy: left.featherPolicy,
                    baseOpacity: left.opacity,
                    mask: right
                )
            ).configured(for: profile)
            io.bufferPixelFormat = storageFormat.pixelFormat
            let texture = try io.output()
            let identity = MaskResourceIdentity(
                identifier: "maskExpression:\(expressionFingerprint(lhs, rhs, mode))",
                revision: max(
                    left.plane.descriptor.resourceIdentity.revision,
                    right.plane.descriptor.resourceIdentity.revision
                ) &+ 1,
                generation: max(
                    left.plane.descriptor.resourceIdentity.generation,
                    right.plane.descriptor.resourceIdentity.generation
                )
            )
            return MaskPlane(
                texture: texture,
                coordinateSpace: left.plane.descriptor.coordinateSpace,
                sourceToMaskTransform: left.plane.descriptor.sourceToMaskTransform,
                sampling: left.plane.descriptor.sampling,
                coverageSemantics: .continuous,
                storageFormat: storageFormat,
                resourceIdentity: identity,
                lastModifiedBounds: union(
                    left.plane.descriptor.lastModifiedBounds,
                    right.plane.descriptor.lastModifiedBounds
                )
            ).maskDescriptor()
        }

        let result = try evaluate(self)
        let normalized = try MaskProcessingRecipe(mask: result).makeCoverageTexture()
        let plane = MaskPlane(
            texture: normalized,
            coordinateSpace: result.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: result.plane.descriptor.sourceToMaskTransform,
            sampling: result.plane.descriptor.sampling,
            coverageSemantics: .continuous,
            storageFormat: MaskStorageFormat(normalized.pixelFormat),
            resourceIdentity: result.plane.descriptor.resourceIdentity,
            lastModifiedBounds: plan.dirtyBounds
        )
        return MaskExpressionExecutionResult(plane: plane, plan: plan, cacheHitCount: cacheHitCount)
    }
}

private func extent(of expression: MaskExpression) -> (width: Int, height: Int) {
    switch expression {
    case .source(let mask): return (mask.texture.width, mask.texture.height)
    case .add(let lhs, _), .intersect(let lhs, _), .subtract(let lhs, _), .exclude(let lhs, _): return extent(of: lhs)
    case .invert(let value), .opacity(let value, _): return extent(of: value)
    }
}

private func operationName(_ expression: MaskExpression) -> String {
    switch expression {
    case .add: return "add"
    case .intersect: return "intersect"
    case .subtract: return "subtract"
    case .exclude: return "exclude"
    case .invert: return "invertMetadata"
    case .opacity: return "opacityMetadata"
    case .source: return "source"
    }
}

private func expressionFingerprint(_ lhs: MaskExpression, _ rhs: MaskExpression, _ mode: MaskBlendMode) -> String {
    "\(mode.rawValue){\(lhs.fingerprint)}{\(rhs.fingerprint)}"
}

private func union(_ lhs: MaskCoverageBounds?, _ rhs: MaskCoverageBounds?) -> MaskCoverageBounds? {
    guard let lhs else { return rhs }
    guard let rhs else { return lhs }
    let minX = min(lhs.x, rhs.x)
    let minY = min(lhs.y, rhs.y)
    let maxX = max(lhs.x + lhs.width, rhs.x + rhs.width)
    let maxY = max(lhs.y + lhs.height, rhs.y + rhs.height)
    return MaskCoverageBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}
