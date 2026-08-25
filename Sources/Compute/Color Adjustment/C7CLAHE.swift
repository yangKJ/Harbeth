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
public struct C7CLAHE: C7MetalCommandEncodingProtocol {

    /// 直方图 LUT 的固定 bin 数。256 与 8-bit SDR 亮度域对应。
    public static let histogramBinCount = 256

    /// 一个 CLAHE render 只编码一个 clear pass、histogram、LUT 和 apply 三个 compute pass。
    /// 这是内部资源回归合同，不是额外的公开执行入口。
    static let commandEncoderCount = 4

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
        .metalCommand(label: "C7CLAHE")
    }

    public var factors: [Float] {
        [clipLimit, Float(tileGridSize.columns), Float(tileGridSize.rows)]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    public var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(aliasingPolicy: .requiredDistinct)
    }

    public var kernelOutputContract: RenderOutputContract {
        RenderOutputContract(alpha: .premultiplied)
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

    public func metalCommandExecutionRoute(
        in environment: MetalCommandEnvironment
    ) -> MetalCommandExecutionRoute {
        .preferred
    }

    public func encodeMetalCommands(
        context: MetalCommandEncodingContext,
        route: MetalCommandExecutionRoute
    ) throws -> MTLTexture {
        guard route == .preferred else {
            throw HarbethError.filterParameterInvalid("C7CLAHE only supports its declared preferred route.")
        }
        let destination = context.destinationTexture
        let source = context.sourceTexture
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
        let device = context.device

        let temporaryBuffers = try HarbethContext.shared.claheTemporaryBufferPool.checkout(
            device: device,
            histogramLength: histogramLength,
            countLength: countLength,
            lookupLength: lookupLength
        )
        var recyclesOnFailure = true
        defer {
            if recyclesOnFailure {
                HarbethContext.shared.claheTemporaryBufferPool.recycle(temporaryBuffers)
            }
        }
        let histogram = temporaryBuffers.histogram
        let sampleCounts = temporaryBuffers.sampleCounts
        let lookupTable = temporaryBuffers.lookupTable

        try clear([histogram, sampleCounts], commandBuffer: context.commandBuffer)
        try encodeHistogram(
            source: source,
            histogram: histogram,
            sampleCounts: sampleCounts,
            grid: executionGrid,
            commandBuffer: context.commandBuffer,
            environment: context.environment
        )
        try encodeLookupTable(
            histogram: histogram,
            sampleCounts: sampleCounts,
            lookupTable: lookupTable,
            grid: executionGrid,
            commandBuffer: context.commandBuffer,
            environment: context.environment
        )
        try encodeApply(
            source: source,
            destination: destination,
            lookupTable: lookupTable,
            grid: executionGrid,
            commandBuffer: context.commandBuffer,
            environment: context.environment
        )
        context.commandBuffer.addCompletedHandler { _ in
            HarbethContext.shared.claheTemporaryBufferPool.recycle(temporaryBuffers)
        }
        recyclesOnFailure = false
        return destination
    }

    private func clear(_ buffers: [MTLBuffer], commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        encoder.label = "C7CLAHE clear encoder"
        for buffer in buffers {
            encoder.fill(buffer: buffer, range: 0..<buffer.length, value: 0)
        }
        encoder.endEncoding()
    }

    private func encodeHistogram(source: MTLTexture,
                                 histogram: MTLBuffer,
                                 sampleCounts: MTLBuffer,
                                 grid: TileGridSize,
                                 commandBuffer: MTLCommandBuffer,
                                 environment: MetalCommandEnvironment) throws {
        let pipeline = try environment.makeComputePipelineState(
            KernelFunctionIdentity(kind: .compute, primaryName: "C7CLAHEHistogram")
        )
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
                                   commandBuffer: MTLCommandBuffer,
                                   environment: MetalCommandEnvironment) throws {
        let pipeline = try environment.makeComputePipelineState(
            KernelFunctionIdentity(kind: .compute, primaryName: "C7CLAHEBuildLookupTable")
        )
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
                             commandBuffer: MTLCommandBuffer,
                             environment: MetalCommandEnvironment) throws {
        let pipeline = try environment.makeComputePipelineState(
            KernelFunctionIdentity(kind: .compute, primaryName: "C7CLAHEApply")
        )
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

/// 仅供 CLAHE 使用的短生命周期 GPU buffer 池。每组 buffer 都会等关联 command buffer 完成后
/// 才归还，避免被并发 render 提前复用；缓存最多保留两组，限制长期 private-memory 占用。
final class CLAHETemporaryBufferPool: @unchecked Sendable {

    struct Statistics: Equatable {
        let totalBufferAllocations: Int
        let totalBufferReuses: Int
        let peakInFlightSetCount: Int
        let cachedSetCount: Int
    }

    struct Key: Hashable, Sendable {
        let deviceIdentifier: ObjectIdentifier
        let histogramLength: Int
        let countLength: Int
        let lookupLength: Int
    }

    struct BufferSet: @unchecked Sendable {
        let key: Key
        let histogram: MTLBuffer
        let sampleCounts: MTLBuffer
        let lookupTable: MTLBuffer
    }

    private let lock = NSLock()
    private let maximumCachedSetCount = 2
    private var cachedSets: [Key: [BufferSet]] = [:]
    private var totalBufferAllocations = 0
    private var totalBufferReuses = 0
    private var inFlightSetCount = 0
    private var peakInFlightSetCount = 0

    func checkout(device: MTLDevice,
                  histogramLength: Int,
                  countLength: Int,
                  lookupLength: Int) throws -> BufferSet {
        let key = Key(
            deviceIdentifier: ObjectIdentifier(device),
            histogramLength: histogramLength,
            countLength: countLength,
            lookupLength: lookupLength
        )

        lock.lock()
        if var available = cachedSets[key], let bufferSet = available.popLast() {
            cachedSets[key] = available.isEmpty ? nil : available
            totalBufferReuses += 3
            recordCheckoutLocked()
            lock.unlock()
            return bufferSet
        }
        lock.unlock()

        guard let histogram = device.makeBuffer(length: histogramLength, options: .storageModePrivate),
              let sampleCounts = device.makeBuffer(length: countLength, options: .storageModePrivate),
              let lookupTable = device.makeBuffer(length: lookupLength, options: .storageModePrivate) else {
            throw HarbethError.textureLoader
        }
        histogram.label = "C7CLAHE histogram"
        sampleCounts.label = "C7CLAHE sample counts"
        lookupTable.label = "C7CLAHE lookup table"

        let bufferSet = BufferSet(
            key: key,
            histogram: histogram,
            sampleCounts: sampleCounts,
            lookupTable: lookupTable
        )
        lock.lock()
        totalBufferAllocations += 3
        recordCheckoutLocked()
        lock.unlock()
        return bufferSet
    }

    func recycle(_ bufferSet: BufferSet) {
        lock.lock()
        defer { lock.unlock() }
        inFlightSetCount = max(inFlightSetCount - 1, 0)
        guard cachedSetCountLocked < maximumCachedSetCount else { return }
        cachedSets[bufferSet.key, default: []].append(bufferSet)
    }

    var statistics: Statistics {
        lock.lock()
        defer { lock.unlock() }
        return Statistics(
            totalBufferAllocations: totalBufferAllocations,
            totalBufferReuses: totalBufferReuses,
            peakInFlightSetCount: peakInFlightSetCount,
            cachedSetCount: cachedSetCountLocked
        )
    }

    func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedSets.removeAll()
        totalBufferAllocations = 0
        totalBufferReuses = 0
        // 不触碰 in-flight 计数；完成回调仍会安全归还正在使用的 buffer。
        peakInFlightSetCount = inFlightSetCount
    }

    /// 清理已完成且暂存的 buffer；不会影响仍被 command buffer 持有的集合。
    func purge() {
        lock.lock()
        cachedSets.removeAll()
        lock.unlock()
    }

    private var cachedSetCountLocked: Int {
        cachedSets.values.reduce(0) { $0 + $1.count }
    }

    private func recordCheckoutLocked() {
        inFlightSetCount += 1
        peakInFlightSetCount = max(peakInFlightSetCount, inFlightSetCount)
    }
}
