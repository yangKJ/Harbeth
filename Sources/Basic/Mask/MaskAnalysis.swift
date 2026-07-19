//
//  MaskAnalysis.swift
//  Harbeth
//
//  Created by Condy on 2026/7/19.
//

import CoreGraphics
import Foundation
import Metal

public struct MaskAnalysis: Sendable, Equatable {
    public let bounds: MaskCoverageBounds?
    public let coverageFraction: Float
    public let centroid: CGPoint?
    public let activePixelCount: Int
    public let edgePixelFraction: Float

    public init(bounds: MaskCoverageBounds?,
                coverageFraction: Float,
                centroid: CGPoint?,
                activePixelCount: Int,
                edgePixelFraction: Float) {
        self.bounds = bounds
        self.coverageFraction = min(max(coverageFraction, 0), 1)
        self.centroid = centroid
        self.activePixelCount = max(activePixelCount, 0)
        self.edgePixelFraction = min(max(edgePixelFraction, 0), 1)
    }

    public var isEmpty: Bool { activePixelCount == 0 }
}
enum MaskGPUAnalysisBackend {
    private static let blockSize = 16
    private static let valuesPerBlock = 9

    static func analyze(texture: MTLTexture, threshold: Float) throws -> MaskAnalysis {
        let blockCountX = max((texture.width + blockSize - 1) / blockSize, 1)
        let blockCountY = max((texture.height + blockSize - 1) / blockSize, 1)
        let blockCount = blockCountX * blockCountY
        let valueCount = blockCount * valuesPerBlock
        guard let buffer = texture.device.makeBuffer(
            length: valueCount * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        ), let queue = texture.device.makeCommandQueue(),
           let commandBuffer = queue.makeCommandBuffer(),
           let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        memset(buffer.contents(), 0, buffer.length)

        let pipeline = try Compute.makeComputePipelineState(with: "MaskAnalyzeCoverageBlocks")
        var parameters: [UInt32] = [
            UInt32(blockSize), UInt32(blockCountX), UInt32(texture.width), UInt32(texture.height),
            threshold.bitPattern
        ]
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.setBytes(&parameters, length: parameters.count * MemoryLayout<UInt32>.stride, index: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: blockCountX, height: blockCountY, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }

        let values = buffer.contents().bindMemory(to: UInt32.self, capacity: valueCount)
        var activeCount: UInt64 = 0
        var minX = texture.width
        var minY = texture.height
        var maxX = -1
        var maxY = -1
        var sumX: UInt64 = 0
        var sumY: UInt64 = 0
        var coverageSum: Double = 0
        var edgeCount: UInt64 = 0
        for block in 0..<blockCount {
            let offset = block * valuesPerBlock
            let count = UInt64(values[offset])
            guard count > 0 else { continue }
            activeCount += count
            minX = min(minX, Int(values[offset + 1]))
            minY = min(minY, Int(values[offset + 2]))
            maxX = max(maxX, Int(values[offset + 3]))
            maxY = max(maxY, Int(values[offset + 4]))
            sumX += UInt64(values[offset + 5])
            sumY += UInt64(values[offset + 6])
            coverageSum += Double(Float(bitPattern: values[offset + 7]))
            edgeCount += UInt64(values[offset + 8])
        }

        guard activeCount > 0 else {
            return MaskAnalysis(bounds: nil, coverageFraction: 0, centroid: nil, activePixelCount: 0, edgePixelFraction: 0)
        }
        let bounds = MaskCoverageBounds(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        let pixelCount = max(texture.width * texture.height, 1)
        return MaskAnalysis(
            bounds: bounds,
            coverageFraction: Float(coverageSum / Double(pixelCount)),
            centroid: CGPoint(
                x: Double(sumX) / Double(activeCount) / Double(max(texture.width - 1, 1)),
                y: Double(sumY) / Double(activeCount) / Double(max(texture.height - 1, 1))
            ),
            activePixelCount: Int(activeCount),
            edgePixelFraction: Float(Double(edgeCount) / Double(activeCount))
        )
    }
}
