//
//  AdvancedMetalKernel.swift
//  Harbeth
//
//  Created by Condy on 2026/6/11.
//

import Foundation
import MetalKit

public enum MetalCapability: String, CaseIterable, Sendable, Codable {
    case customAdvancedEncoder
    case heapTexturePool
    case meshShaders
    case metalFX
    case metalIO
    case renderDynamicLibraries
    case renderFunctionPointers
    case rayTracing
    case sparseTextures
}

public enum MetalCapabilityStatus: Equatable {
    case unsupported
    case supported
    case requiresConcreteImplementationCheck
}

public struct MetalCapabilityReport: Equatable {
    public let capability: MetalCapability
    public let status: MetalCapabilityStatus
    public let minimumPlatform: String
    public let reason: String

    public var isSupported: Bool {
        status == .supported
    }

    public var canBeImplementedByHigherPackage: Bool {
        status == .supported || status == .requiresConcreteImplementationCheck
    }
}

public protocol C7AdvancedMetalKernelProtocol: C7FilterProtocol {
    var advancedMetalCapability: MetalCapability { get }

    var advancedMetalFunction: String { get }

    var advancedMetalLibrarySource: KernelLibrarySource { get }

    var advancedMetalFunctionConstants: [KernelFunctionConstantDescriptor] { get }

    func canUseAdvancedMetal(on device: MTLDevice) -> Bool

    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture

    func encodeAdvanced(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture

    func encodeFallback(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture
}

extension C7AdvancedMetalKernelProtocol {
    public var advancedMetalCapability: MetalCapability {
        if case .advancedMetal(let capability, _) = modifier {
            return capability
        }
        return .customAdvancedEncoder
    }

    public var advancedMetalFunction: String {
        if case .advancedMetal(_, let function) = modifier {
            return function
        }
        return modifier.name
    }

    public var advancedMetalLibrarySource: KernelLibrarySource {
        .automatic
    }

    public var advancedMetalFunctionConstants: [KernelFunctionConstantDescriptor] {
        []
    }

    public func canUseAdvancedMetal(on device: MTLDevice) -> Bool {
        Device.metalCapabilityReport(advancedMetalCapability, on: device).isSupported
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        if canUseAdvancedMetal(on: HarbethContext.shared.device) {
            return try encodeAdvanced(commandBuffer: commandBuffer, textures: textures)
        }
        return try encodeFallback(commandBuffer: commandBuffer, textures: textures)
    }

    public func encodeAdvanced(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        throw HarbethError.filterParameterInvalid("Advanced Metal path is not implemented for \(advancedMetalFunction).")
    }

    public func encodeFallback(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard textures.count >= 2 else {
            throw HarbethError.filterParameterInvalid("textures count must be >= 2")
        }
        let outputTexture = textures[0]
        let inputTexture = textures[1]

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }

        let pipelineState = try advancedMetalPipelineState(
            identity: KernelFunctionIdentity(
                kind: .advancedMetal,
                primaryName: advancedMetalFunction,
                librarySource: advancedMetalLibrarySource,
                functionConstants: advancedMetalFunctionConstants
            )
        )

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)
        for (index, texture) in textures.dropFirst(2).enumerated() {
            encoder.setTexture(texture, index: index + 2)
        }

        let defaultRegionContext: [Float] = [
            0, 0, Float(inputTexture.width), Float(inputTexture.height),
            0, 0, Float(outputTexture.width), Float(outputTexture.height)
        ]
        defaultRegionContext.withUnsafeBytes {
            encoder.setBytes($0.baseAddress!, length: $0.count, index: 30)
        }

        let parameterBindings = kernelParameterBindings
        if parameterBindings.isEmpty {
            for (index, factor) in factors.enumerated() {
                var f = factor
                encoder.setBytes(&f, length: MemoryLayout<Float>.size, index: index)
            }
        } else {
            KernelBindingEncoder.encode(parameterBindings, stage: .compute, on: encoder)
        }

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (outputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (outputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        return outputTexture
    }

    private func advancedMetalPipelineState(identity: KernelFunctionIdentity) throws -> MTLComputePipelineState {
        let context = HarbethContext.shared

        if let cached = context.computePipelineState(for: identity) {
            return cached
        }

        let pipeline = try context.makeComputePipelineState(identity: identity)
        context.setComputePipelineState(pipeline, for: identity)
        return pipeline
    }
}
