//
//  MaskMatteRefinement.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import Metal
@preconcurrency import MetalPerformanceShaders

/// 以 0.5 为边界、内部小于 0.5、外部大于 0.5 的归一化有符号距离场。
struct MaskSignedDistanceFieldRecipe {
    let maxDistance: Float
    let threshold: Float
    let profile: RenderProfile

    init(maxDistance: Float = 64, threshold: Float = 0.5, profile: RenderProfile = .inspectionQuality) {
        self.maxDistance = min(max(maxDistance.isFinite ? maxDistance : 64, 1), 512)
        self.threshold = min(max(threshold.isFinite ? threshold : 0.5, 0), 1)
        self.profile = profile
    }

    func makePlane(from mask: MaskDescriptor) throws -> MaskPlane {
        let coverage = try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
        var insideIO = HarbethIO(element: coverage, filter: MaskPointThreshold(threshold: threshold))
            .configured(for: profile)
        insideIO.bufferPixelFormat = .r8Unorm
        let inside = try insideIO.output()
        var outsideIO = HarbethIO(
            element: coverage,
            filter: MaskCoverageExtract(mask: MaskDescriptor(texture: coverage, component: .red, invert: true))
        ).configured(for: profile)
        outsideIO.bufferPixelFormat = .r8Unorm
        let outside = try outsideIO.output()
        let distanceToInside = try distanceTransform(inside)
        let distanceToOutside = try distanceTransform(outside)
        var io = HarbethIO(
            element: distanceToInside,
            filter: MaskSignedDistanceCombine(distanceToOutside: distanceToOutside, maxDistance: maxDistance)
        ).configured(for: profile)
        io.bufferPixelFormat = .r16Float
        let texture = try io.output()
        return MaskPlane(
            texture: texture,
            coordinateSpace: mask.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: mask.plane.descriptor.sourceToMaskTransform,
            sampling: .softCoverage,
            coverageSemantics: .continuous,
            storageFormat: .coverage16Float,
            resourceIdentity: mask.plane.descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: mask.plane.descriptor.lastModifiedBounds
        )
    }

    func makeTexture(from mask: MaskDescriptor) throws -> MTLTexture {
        try makePlane(from: mask).texture
    }
}

struct MaskEdgeRefinementRecipe {
    let shift: Float
    let innerFeather: Float
    let outerFeather: Float
    let maxDistance: Float
    let threshold: Float
    let profile: RenderProfile

    init(shift: Float = 0,
                innerFeather: Float = 0,
                outerFeather: Float = 0,
                maxDistance: Float = 64,
                threshold: Float = 0.5,
                profile: RenderProfile = .inspectionQuality) {
        self.shift = shift.isFinite ? shift : 0
        self.innerFeather = max(innerFeather.isFinite ? innerFeather : 0, 0)
        self.outerFeather = max(outerFeather.isFinite ? outerFeather : 0, 0)
        self.maxDistance = min(max(maxDistance.isFinite ? maxDistance : 64, 1), 512)
        self.threshold = min(max(threshold.isFinite ? threshold : 0.5, 0), 1)
        self.profile = profile
    }

    func makePlane(from mask: MaskDescriptor, storageFormat: MaskStorageFormat = .coverage16Float) throws -> MaskPlane {
        let signedDistance = try MaskSignedDistanceFieldRecipe(
            maxDistance: maxDistance,
            threshold: threshold,
            profile: profile
        ).makePlane(from: mask)
        var io = HarbethIO(
            element: signedDistance.texture,
            filter: MaskSignedDistanceCoverage(
                shift: shift,
                innerFeather: innerFeather,
                outerFeather: outerFeather,
                maxDistance: maxDistance
            )
        ).configured(for: profile)
        io.bufferPixelFormat = storageFormat.pixelFormat
        return MaskPlane(
            texture: try io.output(),
            coordinateSpace: mask.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: mask.plane.descriptor.sourceToMaskTransform,
            sampling: .softCoverage,
            coverageSemantics: .continuous,
            storageFormat: storageFormat,
            resourceIdentity: mask.plane.descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: mask.plane.descriptor.lastModifiedBounds
        )
    }
}

/// MPS 两阶段 guided filter。模型或主体识别不在这里；这里只精修已存在的 soft matte。
struct MaskGuidedRefinementRecipe {
    let radius: Int
    let epsilon: Float
    let coefficientScale: Float
    let storageFormat: MaskStorageFormat

    init(radius: Int = 8,
                epsilon: Float = 0.001,
                coefficientScale: Float = 0.5,
                storageFormat: MaskStorageFormat = .coverage16Float) {
        self.radius = min(max(radius, 1), 64)
        self.epsilon = max(epsilon.isFinite ? epsilon : 0.001, 0.000_001)
        self.coefficientScale = min(max(coefficientScale.isFinite ? coefficientScale : 0.5, 0.125), 1)
        self.storageFormat = storageFormat
    }

    func makePlane(from mask: MaskDescriptor,
                   guidanceTexture: MTLTexture,
                   confidenceTexture: MTLTexture? = nil) throws -> MaskPlane {
        let normalizedCoverage = try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
        var coverageIO = HarbethIO(
            element: normalizedCoverage,
            filter: MaskCoverageExtract(mask: MaskDescriptor(texture: normalizedCoverage, component: .red))
        ).configured(for: .inspectionQuality)
        coverageIO.bufferPixelFormat = .r16Float
        let coverage = try coverageIO.output()
        guard coverage.width == guidanceTexture.width,
              coverage.height == guidanceTexture.height,
              confidenceTexture.map({ $0.width == coverage.width && $0.height == coverage.height }) ?? true else {
            throw HarbethError.textureSizeMismatch
        }
        let confidence: MTLTexture?
        if let confidenceTexture {
            var confidenceIO = HarbethIO(
                element: confidenceTexture,
                filter: MaskCoverageExtract(mask: MaskDescriptor(texture: confidenceTexture, component: .red))
            ).configured(for: .inspectionQuality)
            confidenceIO.bufferPixelFormat = .r16Float
            confidence = try confidenceIO.output()
        } else {
            confidence = nil
        }

        let coefficientWidth = max(Int((Float(coverage.width) * coefficientScale).rounded()), 1)
        let coefficientHeight = max(Int((Float(coverage.height) * coefficientScale).rounded()), 1)
        let coefficients = try Self.makeTexture(
            device: coverage.device,
            width: coefficientWidth,
            height: coefficientHeight,
            pixelFormat: .rgba16Float,
            identifier: "MaskGuidedRefinement.coefficients"
        )
        let reconstructionOutput = try Self.makeTexture(
            device: coverage.device,
            width: coverage.width,
            height: coverage.height,
            pixelFormat: .r16Float,
            identifier: "MaskGuidedRefinement.output"
        )
        guard let commandBuffer = makeMaskCommandBuffer(for: coverage.device) else {
            throw HarbethError.commandBuffer
        }
        let filter = MPSImageGuidedFilter(device: coverage.device, kernelDiameter: radius * 2 + 1)
        filter.epsilon = epsilon
        filter.options = .allowReducedPrecision
        filter.encodeRegression(
            to: commandBuffer,
            sourceTexture: coverage,
            guidanceTexture: guidanceTexture,
            weightsTexture: confidence,
            destinationCoefficientsTexture: coefficients
        )
        filter.encodeReconstruction(
            to: commandBuffer,
            guidanceTexture: guidanceTexture,
            coefficientsTexture: coefficients,
            destinationTexture: reconstructionOutput
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }
        let output: MTLTexture
        if storageFormat.pixelFormat == reconstructionOutput.pixelFormat {
            output = reconstructionOutput
        } else {
            var conversion = HarbethIO(
                element: reconstructionOutput,
                filter: MaskCoverageExtract(mask: MaskDescriptor(texture: reconstructionOutput, component: .red))
            ).configured(for: .inspectionQuality)
            conversion.bufferPixelFormat = storageFormat.pixelFormat
            output = try conversion.output()
        }
        return MaskPlane(
            texture: output,
            coordinateSpace: mask.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: mask.plane.descriptor.sourceToMaskTransform,
            sampling: .softCoverage,
            coverageSemantics: .continuous,
            storageFormat: storageFormat,
            resourceIdentity: mask.plane.descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: mask.plane.descriptor.lastModifiedBounds
        )
    }
}

private extension MaskSignedDistanceFieldRecipe {
    func distanceTransform(_ input: MTLTexture) throws -> MTLTexture {
        let output = try MaskGuidedRefinementRecipe.makeTexture(
            device: input.device,
            width: input.width,
            height: input.height,
            pixelFormat: .r16Float,
            identifier: "MaskSignedDistanceField.distance"
        )
        guard let commandBuffer = makeMaskCommandBuffer(for: input.device) else {
            throw HarbethError.commandBuffer
        }
        let transform = MPSImageEuclideanDistanceTransform(device: input.device)
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
            transform.searchLimitRadius = maxDistance
        }
        transform.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw commandBuffer.error ?? HarbethError.commandBuffer
        }
        return output
    }
}

private extension MaskGuidedRefinementRecipe {
    static func makeTexture(device: MTLDevice,
                            width: Int,
                            height: Int,
                            pixelFormat: MTLPixelFormat,
                            identifier: String) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: max(width, 1),
            height: max(height, 1),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let texture = HarbethContext.shared.textureAllocator.makeTexture(
            descriptor: descriptor,
            device: device
        ) else {
            throw HarbethError.makeTexture
        }
        texture.label = identifier
        return texture
    }
}
