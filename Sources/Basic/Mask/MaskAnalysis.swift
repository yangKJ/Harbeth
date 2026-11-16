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
        let pipeline = try Compute.makeComputePipelineState(with: "MaskAnalyzeCoverageBlocks")
        guard let buffer = texture.device.makeBuffer(
            length: valueCount * MemoryLayout<UInt32>.stride,
            options: .storageModePrivate
        ), let result = texture.device.makeBuffer(length: 9 * MemoryLayout<UInt64>.stride, options: .storageModeShared),
           let commandBuffer = makeMaskCommandBuffer(for: texture.device),
           let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
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
            threadsPerThreadgroup: MTLSize(width: blockSize, height: blockSize, depth: 1)
        )
        encoder.endEncoding()
        let finalizePipeline = try Compute.makeComputePipelineState(with: "MaskAnalyzeCoverageFinalize")
        guard let finalize = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        var finalizeParameters = [UInt32(blockCount), UInt32(texture.width), UInt32(texture.height)]
        finalize.setComputePipelineState(finalizePipeline)
        finalize.setBuffer(buffer, offset: 0, index: 0)
        finalize.setBuffer(result, offset: 0, index: 1)
        finalize.setBytes(&finalizeParameters, length: finalizeParameters.count * MemoryLayout<UInt32>.stride, index: 2)
        finalize.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        finalize.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }

        let values = result.contents().bindMemory(to: UInt64.self, capacity: 9)
        let activeCount = values[0]
        let minX = Int(values[1]), minY = Int(values[2]), maxX = Int(values[3]), maxY = Int(values[4])
        let sumX = values[5], sumY = values[6]
        let coverageSum = Double(Float(bitPattern: UInt32(truncatingIfNeeded: values[7])))
        let edgeCount = values[8]

        guard activeCount > 0 else {
            let pixelCount = max(texture.width * texture.height, 1)
            return MaskAnalysis(bounds: nil, coverageFraction: Float(coverageSum / Double(pixelCount)), centroid: nil, activePixelCount: 0, edgePixelFraction: 0)
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
