//
//  C7CLAHE.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import Metal

/// 对亮度执行局部对比度限制自适应直方图均衡化。
///
/// CLAHE 会分别统计每个 tile 的亮度直方图，限制单个 bin 的最大计数后生成
/// 映射表，再在相邻 tile 之间双线性插值。它按亮度比例缩放 RGB，尽量避免分别
/// 均衡 RGB 通道造成的明显色偏；输入和输出都遵守预乘 alpha 合同。
///
/// 该滤镜面向 SDR 亮度范围。透明像素及直色彩含有负值或大于 1 分量的 HDR/EDR
/// 像素会保持原样，不参与直方图统计，避免将审美局部对比度处理误用为 tone mapping。
public struct C7CLAHE: C7AdvancedMetalKernelProtocol {

    /// 直方图 LUT 的固定 bin 数。256 与 8-bit SDR 亮度域对应。
    public static let histogramBinCount = 256

    public static let clipLimitRange: ParameterRange<Float, Self> = .init(min: 0.25, max: 16, value: 2)

    /// tile 网格。维度会限制在 1...16，避免单帧临时直方图 buffer 无界增长。
    public struct TileGridSize: Sendable, Codable, Equatable, Hashable {
        public static let minimumDimension = 1
        public static let maximumDimension = 16

        public let columns: Int
        public let rows: Int

        public init(columns: Int = 8, rows: Int = 8) {
            self.columns = min(max(columns, Self.minimumDimension), Self.maximumDimension)
            self.rows = min(max(rows, Self.minimumDimension), Self.maximumDimension)
        }
    }

    /// 单个亮度 bin 最多可保留的平均 tile bin 计数倍数。
    /// 数值越小，局部对比度越受限；数值越大，结果越接近未限制的局部均衡化。
    @Clamping(clipLimitRange.min...clipLimitRange.max) public var clipLimit: Float = clipLimitRange.value

    /// 局部直方图网格尺寸。
    public var tileGridSize: TileGridSize

    public var modifier: ModifierEnum {
        .advancedMetal(capability: .customAdvancedEncoder, function: advancedMetalFunction)
    }

    public var factors: [Float] {
        [clipLimit, Float(tileGridSize.columns), Float(tileGridSize.rows)]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    public var advancedMetalCapability: C7MetalCapability {
        .customAdvancedEncoder
    }

    public var advancedMetalFunction: String {
        "C7CLAHEApply"
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .global,
            coordinateDependency: .fullImage,
            globalDependency: .imageStatistics,
            fusionPolicy: .disabled
        )
    }

    public init(clipLimit: Float = clipLimitRange.value, tileGridSize: TileGridSize = .init()) {
        self.clipLimit = clipLimit
        self.tileGridSize = tileGridSize
    }

    /// CLAHE 的编码仅使用基础 compute 功能，不依赖可选的 Metal 专用硬件特性。
    public func canUseAdvancedMetal(on device: MTLDevice) -> Bool {
        true
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard textures.count >= 2 else {
            throw HarbethError.filterParameterInvalid("C7CLAHE requires destination and source textures.")
        }
        let destination = textures[0]
        let source = textures[1]
        guard destination !== source else {
            throw HarbethError.filterParameterInvalid("C7CLAHE requires distinct source and destination textures.")
        }
        guard destination.width == source.width, destination.height == source.height else {
            throw HarbethError.textureSizeMismatch
        }

        let executionGrid = TileGridSize(
            columns: min(tileGridSize.columns, source.width),
            rows: min(tileGridSize.rows, source.height)
        )
        let tileCount = executionGrid.columns * executionGrid.rows
        let histogramLength = tileCount * Self.histogramBinCount * MemoryLayout<UInt32>.stride
        let countLength = tileCount * MemoryLayout<UInt32>.stride
        let lookupLength = tileCount * Self.histogramBinCount * MemoryLayout<Float>.stride
        let device = HarbethContext.shared.device

        guard let histogram = device.makeBuffer(length: histogramLength, options: .storageModePrivate),
              let sampleCounts = device.makeBuffer(length: countLength, options: .storageModePrivate),
              let lookupTable = device.makeBuffer(length: lookupLength, options: .storageModePrivate) else {
            throw HarbethError.textureLoader
        }
        histogram.label = "C7CLAHE histogram"
        sampleCounts.label = "C7CLAHE sample counts"
        lookupTable.label = "C7CLAHE lookup table"

        try clear(histogram, commandBuffer: commandBuffer)
        try clear(sampleCounts, commandBuffer: commandBuffer)
        try encodeHistogram(
            source: source,
            histogram: histogram,
            sampleCounts: sampleCounts,
            grid: executionGrid,
            commandBuffer: commandBuffer
        )
        try encodeLookupTable(
            histogram: histogram,
            sampleCounts: sampleCounts,
            lookupTable: lookupTable,
            grid: executionGrid,
            commandBuffer: commandBuffer
        )
        try encodeApply(
            source: source,
            destination: destination,
            lookupTable: lookupTable,
            grid: executionGrid,
            commandBuffer: commandBuffer
        )
        return destination
    }

    private func clear(_ buffer: MTLBuffer, commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        encoder.fill(buffer: buffer, range: 0..<buffer.length, value: 0)
        encoder.endEncoding()
    }

    private func encodeHistogram(source: MTLTexture,
                                 histogram: MTLBuffer,
                                 sampleCounts: MTLBuffer,
                                 grid: TileGridSize,
                                 commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try Compute.makeComputePipelineState(with: "C7CLAHEHistogram")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        encoder.label = "C7CLAHE histogram encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setBuffer(histogram, offset: 0, index: 0)
        encoder.setBuffer(sampleCounts, offset: 0, index: 1)
        setGridParameters(on: encoder, grid: grid, columnsIndex: 2, rowsIndex: 3)
        dispatchPixels(source, on: encoder)
        encoder.endEncoding()
    }

    private func encodeLookupTable(histogram: MTLBuffer,
                                   sampleCounts: MTLBuffer,
                                   lookupTable: MTLBuffer,
                                   grid: TileGridSize,
                                   commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try Compute.makeComputePipelineState(with: "C7CLAHEBuildLookupTable")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        encoder.label = "C7CLAHE lookup encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(histogram, offset: 0, index: 0)
        encoder.setBuffer(sampleCounts, offset: 0, index: 1)
        encoder.setBuffer(lookupTable, offset: 0, index: 2)
        setGridParameters(on: encoder, grid: grid, columnsIndex: 3, rowsIndex: 4)
        var limit = clipLimit
        encoder.setBytes(&limit, length: MemoryLayout<Float>.size, index: 5)
        let tileCount = grid.columns * grid.rows
        let threadsPerGroup = MTLSize(width: min(tileCount, 64), height: 1, depth: 1)
        let groups = MTLSize(width: (tileCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }

    private func encodeApply(source: MTLTexture,
                             destination: MTLTexture,
                             lookupTable: MTLBuffer,
                             grid: TileGridSize,
                             commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try Compute.makeComputePipelineState(with: advancedMetalFunction)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        encoder.label = "C7CLAHE apply encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(destination, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setBuffer(lookupTable, offset: 0, index: 0)
        setGridParameters(on: encoder, grid: grid, columnsIndex: 1, rowsIndex: 2)
        dispatchPixels(destination, on: encoder)
        encoder.endEncoding()
    }

    private func setGridParameters(on encoder: MTLComputeCommandEncoder,
                                   grid: TileGridSize,
                                   columnsIndex: Int,
                                   rowsIndex: Int) {
        var columns = UInt32(grid.columns)
        var rows = UInt32(grid.rows)
        encoder.setBytes(&columns, length: MemoryLayout<UInt32>.size, index: columnsIndex)
        encoder.setBytes(&rows, length: MemoryLayout<UInt32>.size, index: rowsIndex)
    }

    private func dispatchPixels(_ texture: MTLTexture, on encoder: MTLComputeCommandEncoder) {
        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (texture.width + threads.width - 1) / threads.width,
            height: (texture.height + threads.height - 1) / threads.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
    }
}
