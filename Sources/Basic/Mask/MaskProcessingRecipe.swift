//
//  MaskProcessingRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Foundation
import Metal

public enum MaskCoverageThreshold: Sendable, Equatable, Hashable {
    case none
    case hard(Float)

    var resolvedValue: Float? {
        switch self {
        case .none:
            return nil
        case .hard(let value):
            guard value.isFinite else { return 0 }
            return min(max(value, 0), 1)
        }
    }
}

public struct MaskCoverageBounds: Sendable, Equatable, Hashable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct MaskProcessingRecipe {
    public let mask: MaskDescriptor
    public let threshold: MaskCoverageThreshold

    public init(mask: MaskDescriptor, threshold: MaskCoverageThreshold = .none) {
        self.mask = mask
        self.threshold = threshold
    }

    public func makeCoverageTexture(matching sourceTexture: MTLTexture? = nil) throws -> MTLTexture {
        try validate(matching: sourceTexture)
        let normalized = try HarbethIO(
            element: mask.texture,
            filter: MaskCoverageExtract(mask: mask)
        )
        .renderTexture(profile: .readbackQuality)

        guard let resolvedThreshold = threshold.resolvedValue else {
            return normalized
        }
        return try thresholdedCoverageTexture(from: normalized, threshold: resolvedThreshold)
    }

    public func coverageBounds(matching sourceTexture: MTLTexture? = nil) throws -> MaskCoverageBounds? {
        try analysis(matching: sourceTexture).bounds
    }

    public func isEmpty(matching sourceTexture: MTLTexture? = nil) throws -> Bool {
        try analysis(matching: sourceTexture).isEmpty
    }

    public func analysis(matching sourceTexture: MTLTexture? = nil) throws -> MaskAnalysis {
        let coverageTexture = try makeCoverageTexture(matching: sourceTexture)
        return try MaskGPUAnalysisBackend.analyze(texture: coverageTexture, threshold: 0.001)
    }
}

public extension MaskDescriptor {
    func processing(threshold: MaskCoverageThreshold = .none) -> MaskProcessingRecipe {
        MaskProcessingRecipe(mask: self, threshold: threshold)
    }
}

private extension MaskProcessingRecipe {
    func validate(matching sourceTexture: MTLTexture?) throws {
        guard let sourceTexture else { return }
        guard mask.texture.width == sourceTexture.width,
              mask.texture.height == sourceTexture.height else {
            throw HarbethError.textureSizeMismatch
        }
    }

    func thresholdedCoverageTexture(from texture: MTLTexture, threshold: Float) throws -> MTLTexture {
        try HarbethIO(element: texture, filter: MaskPointThreshold(threshold: threshold))
            .configured(for: .readbackQuality)
            .output()
    }

    static func coverageBounds(in bytes: Data,
                               width: Int,
                               height: Int,
                               threshold: Float?) -> MaskCoverageBounds? {
        let resolvedThreshold = threshold ?? 0
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        bytes.withUnsafeBytes { rawBuffer in
            let rgba = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let coverage = Float(rgba[offset]) / 255.0
                    if coverage <= 0 || coverage < resolvedThreshold {
                        continue
                    }
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }
        return MaskCoverageBounds(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }
}
