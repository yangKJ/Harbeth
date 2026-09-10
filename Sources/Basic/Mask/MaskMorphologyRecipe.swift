//
//  MaskMorphologyRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Metal

/// 通用 mask 形态学组合，不携带任何产品语义。
public enum MaskMorphologyOperation: Sendable, Equatable, Hashable {
    case erosion
    case dilation
    case opening
    case closing
}

public enum MaskEdgeBandKind: Sendable, Equatable, Hashable {
    case inner
    case outer
    case blend
}

public struct MaskMorphologyRecipe: Sendable {
    public let operation: MaskMorphologyOperation
    public let kernelSize: Int

    public init(operation: MaskMorphologyOperation, kernelSize: Int = 3) {
        self.operation = operation
        self.kernelSize = Self.normalizedKernelSize(kernelSize)
    }

    public func makeTexture(from mask: MaskDescriptor) throws -> MTLTexture {
        let coverage = try normalizedCoverage(from: mask)
        return try apply(operation, to: coverage)
    }

    public func makeEdgeBand(from mask: MaskDescriptor, kind: MaskEdgeBandKind) throws -> MTLTexture {
        let coverage = try normalizedCoverage(from: mask)
        let eroded = try morphology(.erosion, coverage)
        let dilated = try morphology(.dilation, coverage)
        switch kind {
        case .inner:
            return try subtract(coverage, by: eroded)
        case .outer:
            return try subtract(dilated, by: coverage)
        case .blend:
            let inner = try subtract(coverage, by: eroded)
            let outer = try subtract(dilated, by: coverage)
            return try add(inner, outer)
        }
    }
}

private extension MaskMorphologyRecipe {
    static func normalizedKernelSize(_ value: Int) -> Int {
        let clamped = min(max(value, 1), 9)
        return clamped.isMultiple(of: 2) ? min(clamped + 1, 9) : clamped
    }

    func normalizedCoverage(from mask: MaskDescriptor) throws -> MTLTexture {
        try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
    }

    func apply(_ operation: MaskMorphologyOperation, to texture: MTLTexture) throws -> MTLTexture {
        switch operation {
        case .erosion, .dilation:
            return try morphology(operation, texture)
        case .opening:
            let eroded = try morphology(.erosion, texture)
            return try morphology(.dilation, eroded)
        case .closing:
            let dilated = try morphology(.dilation, texture)
            return try morphology(.erosion, dilated)
        }
    }

    func morphology(_ operation: MaskMorphologyOperation, _ texture: MTLTexture) throws -> MTLTexture {
        let type: C7Morphology.OperationType
        switch operation {
        case .erosion:
            type = .erosion
        case .dilation:
            type = .dilation
        case .opening, .closing:
            throw HarbethError.filterParameterInvalid("morphology operation")
        }
        return try HarbethIO(
            element: texture,
            filter: C7Morphology(operation: type, kernelSize: Float(kernelSize))
        ).output()
    }

    func subtract(_ base: MTLTexture, by mask: MTLTexture) throws -> MTLTexture {
        try HarbethIO(
            element: base,
            filter: MaskCoverageBlend(
                baseComponent: .red,
                mask: MaskDescriptor(texture: mask, component: .red, blendMode: .subtract)
            )
        ).output()
    }

    func add(_ base: MTLTexture, _ mask: MTLTexture) throws -> MTLTexture {
        try HarbethIO(
            element: base,
            filter: MaskCoverageBlend(
                baseComponent: .red,
                mask: MaskDescriptor(texture: mask, component: .red, blendMode: .add)
            )
        ).output()
    }
}
