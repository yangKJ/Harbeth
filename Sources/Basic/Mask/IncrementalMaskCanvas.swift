//
//  IncrementalMaskCanvas.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import Metal

public struct MaskCanvasUpdate: Sendable, Equatable {
    public let dirtyBounds: MaskCoverageBounds?
    public let encodedPointCount: Int
    public let revision: UInt64
    public let generation: UInt64

    init(dirtyBounds: MaskCoverageBounds?, encodedPointCount: Int, revision: UInt64, generation: UInt64) {
        self.dirtyBounds = dirtyBounds
        self.encodedPointCount = encodedPointCount
        self.revision = revision
        self.generation = generation
    }
}

/// 持久 GPU coverage 画布。每次笔画只编码脏矩形，不重新栅格化历史路径。
public final class IncrementalMaskCanvas: @unchecked Sendable {
    public let size: C7Size
    public let storageFormat: MaskStorageFormat
    public let coordinateSpace: MaskCoordinateSpace

    private let stateLock = NSLock()
    private var texture: MTLTexture
    private let identifier: String
    private var revision: UInt64 = 0
    private var generation: UInt64 = 0
    private var lastModifiedBounds: MaskCoverageBounds?
    private var textureHasSnapshot = false

    public init(size: C7Size,
                storageFormat: MaskStorageFormat = .coverage8,
                coordinateSpace: MaskCoordinateSpace = .sourceNormalized,
                identifier: String = UUID().uuidString) throws {
        self.size = C7Size(width: max(size.width, 1), height: max(size.height, 1))
        self.storageFormat = storageFormat
        self.coordinateSpace = coordinateSpace
        self.identifier = identifier
        self.texture = try Self.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            storageFormat: storageFormat,
            identifier: identifier
        )
        try Self.clear(texture: texture)
    }

    @discardableResult
    public func apply(points: [MaskBrushPoint],
                      settings: MaskBrushSettings = MaskBrushSettings(),
                      generation requestedGeneration: UInt64? = nil,
                      cancellation: TextureMultiPassCancellationToken? = nil) throws -> MaskCanvasUpdate {
        try stateLock.withLock {
            if let requestedGeneration, requestedGeneration < generation {
                throw HarbethError.incrementalMaskCanvasStaleGeneration(requested: requestedGeneration, current: generation)
            }
            let targetGeneration = requestedGeneration ?? generation
            if cancellation?.isCancelled == true { throw HarbethError.textureMultiPassCancelled }
            guard settings.flow > 0, settings.density > 0 else {
                generation = targetGeneration
                return MaskCanvasUpdate(dirtyBounds: nil, encodedPointCount: 0, revision: revision, generation: generation)
            }
            let prepared = MaskBrushRecipe.prepareIncremental(points: points, settings: settings)
            guard !prepared.isEmpty else {
                generation = targetGeneration
                return MaskCanvasUpdate(dirtyBounds: nil, encodedPointCount: 0, revision: revision, generation: generation)
            }
            var chunkStart = 0
            var modifiedBounds: MaskCoverageBounds?
            var chunks: [(points: [MaskBrushPoint], bounds: MaskCoverageBounds)] = []
            while chunkStart < prepared.count {
                if cancellation?.isCancelled == true { throw HarbethError.textureMultiPassCancelled }
                let chunkEnd = min(chunkStart + MaskBrushRecipe.maximumPreparedPointCount, prepared.count)
                let chunk = Array(prepared[chunkStart..<chunkEnd])
                if let chunkBounds = Self.dirtyBounds(
                    points: chunk,
                    settings: settings,
                    width: texture.width,
                    height: texture.height
                ) {
                    chunks.append((chunk, chunkBounds))
                    modifiedBounds = Self.union(modifiedBounds, chunkBounds)
                }
                guard chunkEnd < prepared.count else { break }
                chunkStart = chunkEnd - 1
            }
            guard let modifiedBounds else {
                generation = targetGeneration
                return MaskCanvasUpdate(dirtyBounds: nil, encodedPointCount: 0, revision: revision, generation: generation)
            }
            if cancellation?.isCancelled == true { throw HarbethError.textureMultiPassCancelled }
            if textureHasSnapshot {
                texture = try Self.copy(texture: texture, identifier: identifier)
                textureHasSnapshot = false
            }
            // 每个 chunk 都相对同一份调用前 coverage 计算，避免公共端点在低 flow 下重复累积。
            let baselineTexture = chunks.count > 1 ? try Self.copy(texture: texture, identifier: "\(identifier).baseline") : nil
            guard let commandBuffer = makeMaskCommandBuffer(for: texture.device) else {
                throw HarbethError.commandBuffer
            }
            for chunk in chunks {
                try Self.encode(
                    points: chunk.points,
                    settings: settings,
                    dirtyBounds: chunk.bounds,
                    texture: texture,
                    baselineTexture: baselineTexture,
                    commandBuffer: commandBuffer
                )
            }
            if cancellation?.isCancelled == true { throw HarbethError.textureMultiPassCancelled }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            if commandBuffer.status == .error {
                throw commandBuffer.error ?? HarbethError.commandBuffer
            }
            generation = targetGeneration
            revision &+= 1
            lastModifiedBounds = modifiedBounds
            return MaskCanvasUpdate(
                dirtyBounds: modifiedBounds,
                encodedPointCount: prepared.count,
                revision: revision,
                generation: generation
            )
        }
    }

    @discardableResult
    public func reset(generation requestedGeneration: UInt64? = nil) throws -> MaskCanvasUpdate {
        try stateLock.withLock {
            if let requestedGeneration, requestedGeneration < generation {
                throw HarbethError.incrementalMaskCanvasStaleGeneration(requested: requestedGeneration, current: generation)
            }
            let targetGeneration = requestedGeneration ?? generation
            if textureHasSnapshot {
                let replacement = try Self.makeTexture(
                    width: texture.width,
                    height: texture.height,
                    storageFormat: storageFormat,
                    identifier: identifier
                )
                try Self.clear(texture: replacement)
                texture = replacement
                textureHasSnapshot = false
            } else {
                try Self.clear(texture: texture)
            }
            generation = targetGeneration
            revision &+= 1
            lastModifiedBounds = MaskCoverageBounds(x: 0, y: 0, width: texture.width, height: texture.height)
            return MaskCanvasUpdate(
                dirtyBounds: lastModifiedBounds,
                encodedPointCount: 0,
                revision: revision,
                generation: generation
            )
        }
    }

    public func snapshot(sampling: MaskSamplingContract = .softCoverage) -> MaskPlane {
        stateLock.withLock {
            let plane = MaskPlane(
                texture: texture,
                coordinateSpace: coordinateSpace,
                sampling: sampling,
                coverageSemantics: .continuous,
                storageFormat: storageFormat,
                resourceIdentity: MaskResourceIdentity(identifier: identifier, revision: revision, generation: generation),
                lastModifiedBounds: lastModifiedBounds
            )
            textureHasSnapshot = true
            return plane
        }
    }
}

private extension IncrementalMaskCanvas {
    static func makeTexture(width: Int, height: Int, storageFormat: MaskStorageFormat, identifier: String) throws -> MTLTexture {
        try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                .texturePixelFormat: storageFormat.pixelFormat,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ],
            identifier: "IncrementalMaskCanvas.\(identifier)"
        )
    }

    static func copy(texture source: MTLTexture, identifier: String) throws -> MTLTexture {
        let output = try makeTexture(
            width: source.width,
            height: source.height,
            storageFormat: MaskStorageFormat(source.pixelFormat),
            identifier: "\(identifier).copy"
        )
        guard let commandBuffer = makeMaskCommandBuffer(for: source.device),
              let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        encoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
            to: output,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }
        return output
    }

    static func dirtyBounds(points: [MaskBrushPoint], settings: MaskBrushSettings, width: Int, height: Int) -> MaskCoverageBounds? {
        guard !points.isEmpty else { return nil }
        let shortEdge = Float(max(min(width, height), 1))
        let radius = CGFloat(settings.width * 0.5 * shortEdge + 2)
        let xs = points.map { $0.point.x * CGFloat(width) }
        let ys = points.map { $0.point.y * CGFloat(height) }
        let minX = max(Int(floor((xs.min() ?? 0) - radius)), 0)
        let minY = max(Int(floor((ys.min() ?? 0) - radius)), 0)
        let maxX = min(Int(ceil((xs.max() ?? 0) + radius)), width - 1)
        let maxY = min(Int(ceil((ys.max() ?? 0) + radius)), height - 1)
        guard maxX >= minX, maxY >= minY else { return nil }
        return MaskCoverageBounds(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func clear(texture: MTLTexture) throws {
        try encodeKernel(
            named: "InnerIncrementalMaskClear",
            texture: texture,
            bounds: MaskCoverageBounds(x: 0, y: 0, width: texture.width, height: texture.height)
        ) { _ in }
    }

    static func encode(points: [MaskBrushPoint],
                       settings: MaskBrushSettings,
                       dirtyBounds: MaskCoverageBounds,
                       texture: MTLTexture,
                       baselineTexture: MTLTexture?,
                       commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        var hasEndedEncoding = false
        defer { if !hasEndedEncoding { encoder.endEncoding() } }
        let kernel = baselineTexture == nil ? "InnerIncrementalBrushMask" : "InnerIncrementalBrushMaskFromBaseline"
        let pipeline = try Compute.makeComputePipelineState(with: kernel)
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        if let baselineTexture {
            encoder.setTexture(baselineTexture, index: 1)
        }
        var metadata: [Float] = [
            Float(points.count), settings.width, settings.hardness,
            settings.flow, settings.density, settings.mode == .erase ? 1 : 0,
            Float(dirtyBounds.x), Float(dirtyBounds.y)
        ]
        var values = points.reduce(into: [Float]()) { result, point in
            result.append(contentsOf: [Float(point.point.x), Float(point.point.y), point.pressure, 0])
        }
        encoder.setBytes(&metadata, length: metadata.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setBytes(&values, length: values.count * MemoryLayout<Float>.stride, index: 1)
        let groupWidth = max(min(pipeline.threadExecutionWidth, dirtyBounds.width), 1)
        let groupHeight = max(min(pipeline.maxTotalThreadsPerThreadgroup / groupWidth, dirtyBounds.height), 1)
        encoder.dispatchThreads(
            MTLSize(width: dirtyBounds.width, height: dirtyBounds.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: groupWidth, height: groupHeight, depth: 1)
        )
        encoder.endEncoding()
        hasEndedEncoding = true
    }

    static func encodeKernel(named name: String,
                             texture: MTLTexture,
                             bounds: MaskCoverageBounds,
                             configure: (MTLComputeCommandEncoder) -> Void) throws {
        guard let commandBuffer = makeMaskCommandBuffer(for: texture.device),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.commandBuffer
        }
        var hasEndedEncoding = false
        defer { if !hasEndedEncoding { encoder.endEncoding() } }
        let pipeline = try Compute.makeComputePipelineState(with: name)
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        configure(encoder)
        let groupWidth = max(min(pipeline.threadExecutionWidth, bounds.width), 1)
        let groupHeight = max(min(pipeline.maxTotalThreadsPerThreadgroup / groupWidth, bounds.height), 1)
        encoder.dispatchThreads(
            MTLSize(width: bounds.width, height: bounds.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: groupWidth, height: groupHeight, depth: 1)
        )
        encoder.endEncoding()
        hasEndedEncoding = true
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }
    }

    static func union(_ lhs: MaskCoverageBounds?, _ rhs: MaskCoverageBounds) -> MaskCoverageBounds {
        guard let lhs else { return rhs }
        let minX = min(lhs.x, rhs.x)
        let minY = min(lhs.y, rhs.y)
        let maxX = max(lhs.x + lhs.width, rhs.x + rhs.width)
        let maxY = max(lhs.y + lhs.height, rhs.y + rhs.height)
        return MaskCoverageBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private extension NSLock {
    func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try action()
    }
}
