//
//  C7LocalTone.swift
//  Harbeth
//
//  Created by Condy on 2026/10/30.
//

import Foundation
import Metal

/// 正向增强局部层次，负向围绕局部中位数压缩反差；共享一次完整逻辑网格统计。
public struct C7LocalTone: C7MetalCommandEncodingProtocol {
    public var amount: Float
    public var clipLimit: Float
    public var tileGridSize: C7CLAHE.TileGridSize

    public init(amount: Float = 0, clipLimit: Float = 2, tileGridSize: C7CLAHE.TileGridSize = .init()) {
        self.amount = amount
        self.clipLimit = clipLimit
        self.tileGridSize = tileGridSize
    }

    public var modifier: ModifierEnum { .metalCommand(label: "C7LocalTone") }
    public var factors: [Float] { [amount, clipLimit, Float(tileGridSize.columns), Float(tileGridSize.rows)] }
    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
    public var destinationTextureContract: FilterDestinationTextureContract { .init(aliasingPolicy: .requiredDistinct) }
    public var kernelOutputContract: RenderOutputContract { .init(alpha: .premultiplied) }
    public var kernelPixelContract: KernelPixelContract {
        .init(
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

    public func validate() throws {
        guard amount.isFinite, (-1...1).contains(amount), clipLimit.isFinite, (0.25...16).contains(clipLimit) else {
            throw HarbethError.filterParameterInvalid("局部影调参数越界或非有限")
        }
    }

    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }

    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        try validate()
        guard route == .preferred else { throw HarbethError.filterParameterInvalid("局部影调不支持替代路线") }
        guard context.sourceTexture.width == context.destinationTexture.width,
              context.sourceTexture.height == context.destinationTexture.height else {
            throw HarbethError.textureSizeMismatch
        }
        if amount == 0 {
            guard let encoder = context.commandBuffer.makeBlitCommandEncoder() else { throw HarbethError.makeBlitCommandEncoder }
            encoder.copy(from: context.sourceTexture, to: context.destinationTexture)
            encoder.endEncoding()
            return context.destinationTexture
        }
        let statistics = try LocalToneStatistics(
            device: context.device,
            width: context.sourceTexture.width,
            height: context.sourceTexture.height,
            clipLimit: clipLimit,
            grid: tileGridSize
        )
        try statistics.encodeClear(commandBuffer: context.commandBuffer)
        try statistics.encodeAccumulate(source: context.sourceTexture, origin: .zero, commandBuffer: context.commandBuffer)
        try statistics.encodePrepare(commandBuffer: context.commandBuffer)
        try statistics.encodeApply(
            source: context.sourceTexture,
            destination: context.destinationTexture,
            origin: .zero,
            amount: amount,
            commandBuffer: context.commandBuffer
        )
        return context.destinationTexture
    }
}

/// 调用方独占本次统计；同一队列依次清零、累计所有输入区域、准备、应用。不得跨照片复用。
public final class LocalToneStatistics {
    private let device: MTLDevice
    private let width: Int
    private let height: Int
    private let clipLimit: Float
    private let grid: C7CLAHE.TileGridSize
    private let histogram: MTLBuffer
    private let sampleCounts: MTLBuffer
    private let lookupTable: MTLBuffer
    private let percentiles: MTLBuffer

    public init(device: MTLDevice, width: Int, height: Int, clipLimit: Float, grid: C7CLAHE.TileGridSize) throws {
        guard width > 0, height > 0, width <= Int(Int32.max) / 16, height <= Int(Int32.max) / 16,
              Int64(width) * Int64(height) <= Int64(UInt32.max),
              clipLimit.isFinite, (0.25...16).contains(clipLimit) else {
            throw HarbethError.filterParameterInvalid("局部统计尺寸或参数无效")
        }
        self.device = device
        self.width = width
        self.height = height
        self.clipLimit = clipLimit
        self.grid = .init(columns: min(grid.columns, width), rows: min(grid.rows, height))
        let tileCount = self.grid.columns * self.grid.rows
        guard let histogram = device.makeBuffer(length: tileCount * 256 * 4, options: .storageModePrivate),
              let counts = device.makeBuffer(length: tileCount * 4, options: .storageModePrivate),
              let lookup = device.makeBuffer(length: tileCount * 256 * 4, options: .storageModePrivate),
              let percentiles = device.makeBuffer(length: tileCount * 3 * 4, options: .storageModePrivate) else {
            throw HarbethError.makeTexture
        }
        self.histogram = histogram
        self.sampleCounts = counts
        self.lookupTable = lookup
        self.percentiles = percentiles
    }

    public func encodeClear(commandBuffer: MTLCommandBuffer) throws {
        try validate(commandBuffer)
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else { throw HarbethError.makeBlitCommandEncoder }
        for buffer in [histogram, sampleCounts, lookupTable, percentiles] {
            encoder.fill(buffer: buffer, range: 0..<buffer.length, value: 0)
        }
        encoder.endEncoding()
    }

    public func encodeAccumulate(source: MTLTexture, origin: SIMD2<UInt32>, commandBuffer: MTLCommandBuffer) throws {
        try validate(commandBuffer, source: source, origin: origin)
        let encoder = try makeEncoder("localToneAccumulate", commandBuffer)
        encoder.setTexture(source, index: 0)
        encoder.setBuffer(histogram, offset: 0, index: 0)
        encoder.setBuffer(sampleCounts, offset: 0, index: 1)
        let values = parameters(origin: origin)
        values.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 2) }
        dispatch(source, encoder)
        encoder.endEncoding()
    }

    public func encodePrepare(commandBuffer: MTLCommandBuffer) throws {
        try validate(commandBuffer)
        let encoder = try makeEncoder("C7CLAHEBuildLookupTable", commandBuffer)
        encoder.setBuffer(histogram, offset: 0, index: 0)
        encoder.setBuffer(sampleCounts, offset: 0, index: 1)
        encoder.setBuffer(lookupTable, offset: 0, index: 2)
        var columns = UInt32(grid.columns)
        var rows = UInt32(grid.rows)
        var limit = clipLimit
        encoder.setBytes(&columns, length: 4, index: 3)
        encoder.setBytes(&rows, length: 4, index: 4)
        encoder.setBytes(&limit, length: 4, index: 5)
        dispatchGrid(encoder)
        encoder.endEncoding()

        let percentileEncoder = try makeEncoder("localTonePercentiles", commandBuffer)
        percentileEncoder.setBuffer(histogram, offset: 0, index: 0)
        percentileEncoder.setBuffer(sampleCounts, offset: 0, index: 1)
        percentileEncoder.setBuffer(percentiles, offset: 0, index: 2)
        percentileEncoder.setBytes(&columns, length: 4, index: 3)
        percentileEncoder.setBytes(&rows, length: 4, index: 4)
        dispatchGrid(percentileEncoder)
        percentileEncoder.endEncoding()
    }

    public func encodeApply(
        source: MTLTexture,
        destination: MTLTexture,
        origin: SIMD2<UInt32>,
        amount: Float,
        usesCLAHEMapping: Bool = false,
        commandBuffer: MTLCommandBuffer
    ) throws {
        try validate(commandBuffer, source: source, origin: origin)
        guard amount.isFinite, (-1...1).contains(amount), source !== destination,
              destination.device === device,
              source.width == destination.width,
              source.height == destination.height else {
            throw HarbethError.filterParameterInvalid("局部影调目标或强度无效")
        }
        let encoder = try makeEncoder("localToneApply", commandBuffer)
        encoder.setTexture(destination, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setBuffer(lookupTable, offset: 0, index: 0)
        encoder.setBuffer(percentiles, offset: 0, index: 1)
        let values = parameters(origin: origin) + [amount.bitPattern, usesCLAHEMapping ? 1 : 0]
        values.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 2) }
        dispatch(destination, encoder)
        encoder.endEncoding()
    }

    private func parameters(origin: SIMD2<UInt32>) -> [UInt32] {
        [UInt32(width), UInt32(height), origin.x, origin.y, UInt32(grid.columns), UInt32(grid.rows)]
    }

    private func validate(_ command: MTLCommandBuffer, source: MTLTexture? = nil, origin: SIMD2<UInt32> = .zero) throws {
        guard command.device === device else { throw HarbethError.configurationInvalid("局部统计设备不匹配") }
        if let source {
            guard source.device === device, Int(origin.x) + source.width <= width,
                  Int(origin.y) + source.height <= height else {
                throw HarbethError.textureSizeMismatch
            }
        }
    }

    private func makeEncoder(_ name: String, _ command: MTLCommandBuffer) throws -> MTLComputeCommandEncoder {
        let pipeline = try MetalCommandEnvironment(device: device).makeComputePipelineState(
            .init(kind: .compute, primaryName: name)
        )
        guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        encoder.label = name
        encoder.setComputePipelineState(pipeline)
        return encoder
    }

    private func dispatchGrid(_ encoder: MTLComputeCommandEncoder) {
        let count = grid.columns * grid.rows
        let width = min(count, 64)
        encoder.dispatchThreadgroups(
            MTLSize(width: (count + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
    }

    private func dispatch(_ texture: MTLTexture, _ encoder: MTLComputeCommandEncoder) {
        encoder.dispatchThreadgroups(
            MTLSize(width: (texture.width + 15) / 16, height: (texture.height + 15) / 16, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
        )
    }
}
