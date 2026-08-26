//
//  StrokeSurface.swift
//  Harbeth
//
//  Created by Condy on 2026/8/26.
//

import CoreGraphics
import Foundation
@preconcurrency import Metal

public struct StrokeSurfaceColor: Sendable, Equatable {
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }
}

public struct StrokeSurfaceStyle: Sendable, Equatable {
    public let width: Float
    public let hardness: Float
    public let opacity: Float
    public let color: StrokeSurfaceColor
    public let erases: Bool

    public init(width: Float, hardness: Float = 0.72, opacity: Float = 1, color: StrokeSurfaceColor, erases: Bool = false) {
        self.width = min(max(width, 0.002), 1)
        self.hardness = min(max(hardness, 0), 1)
        self.opacity = min(max(opacity, 0), 1)
        self.color = color
        self.erases = erases
    }
}

public struct StrokeSurfaceStroke: Sendable, Equatable {
    public let points: [MaskBrushPoint]
    public let style: StrokeSurfaceStyle

    public init(points: [MaskBrushPoint], style: StrokeSurfaceStyle) {
        self.points = points
        self.style = style
    }
}

public enum StrokeSurfaceError: Error, Sendable, Equatable {
    case staleActualGeneration(requested: UInt64, current: UInt64)
    case stalePredictedGeneration(requested: UInt64, current: UInt64)
}

/// 供实时笔迹使用的双层 GPU 派生表面。
///
/// `actual` 只累积已确认的 coalesced touch；`predicted` 每次都清空后重绘，
/// 并在 GPU 完成时以 generation 丢弃过期预测。消费者仍独占 `InkStroke`、
/// 历史、保存与交互完成语义；这里不持有 UIKit 手势或产品状态。
public actor StrokeSurface {
    private var actualLease: TextureLease
    private var actualScratchLease: TextureLease
    private let predictedLease: TextureLease
    private let identifier: String
    private var actualRevision: UInt64 = 0
    private var actualGeneration: UInt64 = 0
    private var predictedGeneration: UInt64 = 0
    private var requiresActualClear = true

    public init(size: C7Size, identifier: String = UUID().uuidString) throws {
        self.identifier = identifier
        actualLease = try Self.makeLease(size: size, identifier: "\(identifier).actual")
        actualScratchLease = try Self.makeLease(size: size, identifier: "\(identifier).actualScratch")
        predictedLease = try Self.makeLease(size: size, identifier: "\(identifier).predicted")
    }

    /// 增量提交真实输入。该方法只 encode/commit，不等待 GPU 完成；同一 runtime queue
    /// 上的 `RenderView` 会自然排在本次写入之后，并通过 `TextureLease` 保活纹理。
    @discardableResult
    public func appendActual(points: [MaskBrushPoint], style: StrokeSurfaceStyle, generation: UInt64) throws -> RenderedFrame {
        guard generation >= actualGeneration else {
            throw StrokeSurfaceError.staleActualGeneration(requested: generation, current: actualGeneration)
        }
        actualGeneration = generation
        guard !points.isEmpty else { return actualFrame(generation: generation) }
        guard let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        if requiresActualClear {
            try Self.encodeClear(texture: actualLease.texture, commandBuffer: commandBuffer)
            requiresActualClear = false
        }
        try encode(strokes: [StrokeSurfaceStroke(points: points, style: style)], commandBuffer: commandBuffer)
        actualLease.retainUntilCompleted(by: commandBuffer)
        actualScratchLease.retainUntilCompleted(by: commandBuffer)
        commandBuffer.commit()
        actualRevision &+= 1
        return actualFrame(generation: generation)
    }

    /// 从 vector truth 重放真实层。调用方应在撤销、重做、删除、移动、重开或尺寸变化时
    /// 创建新 surface 并调用本方法，不能复用旧纹理遮住模型的新状态。
    @discardableResult
    public func replayActual(strokes: [StrokeSurfaceStroke], generation: UInt64) throws -> RenderedFrame {
        guard generation >= actualGeneration else {
            throw StrokeSurfaceError.staleActualGeneration(requested: generation, current: actualGeneration)
        }
        actualGeneration = generation
        guard let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        try Self.encodeClear(texture: actualLease.texture, commandBuffer: commandBuffer)
        requiresActualClear = false
        try encode(strokes: strokes, commandBuffer: commandBuffer)
        actualLease.retainUntilCompleted(by: commandBuffer)
        actualScratchLease.retainUntilCompleted(by: commandBuffer)
        commandBuffer.commit()
        actualRevision &+= 1
        return actualFrame(generation: generation)
    }

    /// 用最新预测替换 predicted 层。旧 command buffer 可以继续执行，但只有仍是最新
    /// generation 的完成结果才会交给调用方显示。
    public func replacePredicted(points: [MaskBrushPoint], style: StrokeSurfaceStyle, generation: UInt64) async throws -> RenderedFrame? {
        guard generation >= predictedGeneration else {
            throw StrokeSurfaceError.stalePredictedGeneration(requested: generation, current: predictedGeneration)
        }
        predictedGeneration = generation
        guard let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        if !points.isEmpty {
            try encodePredicted(points: points, style: style, texture: predictedLease.texture, commandBuffer: commandBuffer)
        } else {
            try Self.encodeClear(texture: predictedLease.texture, commandBuffer: commandBuffer)
        }
        predictedLease.retainUntilCompleted(by: commandBuffer)
        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in continuation.resume() }
            commandBuffer.commit()
        }
        guard commandBuffer.status != .error else {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }
        guard generation == predictedGeneration, !points.isEmpty else { return nil }
        return RenderedFrame(
            texture: predictedLease.texture,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB),
            alphaType: .premultiplied,
            cachePolicy: .transient,
            orientation: .up,
            profile: .interactiveLatency,
            generation: generation,
            identifier: "\(identifier).predicted",
            metadata: ["strokeLayer": "predicted"],
            lease: predictedLease
        )
    }

    public func actualFrame(generation: UInt64) -> RenderedFrame {
        RenderedFrame(
            texture: actualLease.texture,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB),
            alphaType: .premultiplied,
            cachePolicy: .transient,
            orientation: .up,
            profile: .interactiveLatency,
            generation: generation,
            identifier: "\(identifier).actual",
            metadata: ["strokeLayer": "actual", "strokeRevision": String(actualRevision)],
            lease: actualLease
        )
    }
}

private extension StrokeSurface {
    static func makeLease(size: C7Size, identifier: String) throws -> TextureLease {
        let extent = boundedExtent(for: size)
        return try TextureLoader.makeTextureLease(
            width: extent.width,
            height: extent.height,
            options: [
                .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ],
            identifier: "StrokeSurface.\(identifier)"
        )
    }

    /// 实时笔迹是显示用派生表面，不应因为无限延展的纸面超过基础 Metal 纹理尺寸。
    /// 坐标仍保持 normalized，因此降采样不会改变笔迹、命中或重放的几何真相。
    static func boundedExtent(for size: C7Size) -> C7Size {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let maximumDimension = 8_192
        let scale = min(1, Double(maximumDimension) / Double(max(width, height)))
        return C7Size(
            width: max(Int((Double(width) * scale).rounded()), 1),
            height: max(Int((Double(height) * scale).rounded()), 1)
        )
    }

    func encode(strokes: [StrokeSurfaceStroke], commandBuffer: MTLCommandBuffer) throws {
        for stroke in strokes where !stroke.points.isEmpty {
            var start = 0
            while start < stroke.points.count {
                let end = min(start + MaskBrushRecipe.maximumPreparedPointCount, stroke.points.count)
                try encodeStroke(
                    points: Array(stroke.points[start..<end]),
                    style: stroke.style,
                    source: actualLease.texture,
                    destination: actualScratchLease.texture,
                    commandBuffer: commandBuffer
                )
                swap(&actualLease, &actualScratchLease)
                guard end < stroke.points.count else { break }
                start = end - 1
            }
        }
    }

    func encodeStroke(
        points: [MaskBrushPoint],
        style: StrokeSurfaceStyle,
        source: MTLTexture,
        destination: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        defer { encoder.endEncoding() }
        let pipeline = try Compute.makeComputePipelineState(with: "InnerStrokeSurfaceAccumulate")
        var metadata: [Float] = [
            Float(points.count), style.width, style.hardness, style.opacity,
            style.color.red, style.color.green, style.color.blue, style.color.alpha,
            style.erases ? 1 : 0
        ]
        var values = points.reduce(into: [Float]()) { result, point in
            result.append(contentsOf: [Float(point.point.x), Float(point.point.y), point.pressure, 0])
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&metadata, length: metadata.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setBytes(&values, length: values.count * MemoryLayout<Float>.stride, index: 1)
        Self.dispatch(pipeline: pipeline, texture: destination, encoder: encoder)
    }

    func encodePredicted(
        points: [MaskBrushPoint],
        style: StrokeSurfaceStyle,
        texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        defer { encoder.endEncoding() }
        let pipeline = try Compute.makeComputePipelineState(with: "InnerStrokeSurfaceTransient")
        var metadata: [Float] = [
            Float(points.count), style.width, style.hardness, style.opacity,
            style.color.red, style.color.green, style.color.blue, style.color.alpha,
            style.erases ? 1 : 0
        ]
        var values = points.reduce(into: [Float]()) { result, point in
            result.append(contentsOf: [Float(point.point.x), Float(point.point.y), point.pressure, 0])
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&metadata, length: metadata.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setBytes(&values, length: values.count * MemoryLayout<Float>.stride, index: 1)
        Self.dispatch(pipeline: pipeline, texture: texture, encoder: encoder)
    }

    static func encodeClear(texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        defer { encoder.endEncoding() }
        let pipeline = try Compute.makeComputePipelineState(with: "InnerStrokeSurfaceClear")
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        dispatch(pipeline: pipeline, texture: texture, encoder: encoder)
    }

    static func dispatch(pipeline: MTLComputePipelineState, texture: MTLTexture, encoder: MTLComputeCommandEncoder) {
        let width = max(min(pipeline.threadExecutionWidth, texture.width), 1)
        let height = max(min(pipeline.maxTotalThreadsPerThreadgroup / width, texture.height), 1)
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
        encoder.dispatchThreadgroups(
            MTLSize(
                width: (texture.width + width - 1) / width,
                height: (texture.height + height - 1) / height,
                depth: 1
            ),
            threadsPerThreadgroup: threadsPerThreadgroup
        )
    }
}
