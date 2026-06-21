//
//  AdvancedMetalKernel.swift
//  Harbeth
//
//  Created by Condy on 2026/6/11.
//

import Foundation
import MetalKit

public enum C7MetalCapability: String, CaseIterable, Sendable, Codable {
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

public enum C7MetalCapabilityStatus: Equatable {
    case unsupported
    case supported
    case requiresConcreteImplementationCheck
}

public struct C7MetalCapabilityReport: Equatable {
    public let capability: C7MetalCapability
    public let status: C7MetalCapabilityStatus
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
    var advancedMetalCapability: C7MetalCapability { get }

    var advancedMetalFunction: String { get }

    var advancedMetalLibrarySource: KernelLibrarySource { get }

    var advancedMetalFunctionConstants: [KernelFunctionConstantDescriptor] { get }

    func canUseAdvancedMetal(on device: MTLDevice) -> Bool

    func setupAdvancedMetalParameters(for encoder: MTLComputeCommandEncoder, textures: [MTLTexture])

    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture

    func encodeAdvanced(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture

    func encodeFallback(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture
}

extension C7AdvancedMetalKernelProtocol {
    public var advancedMetalCapability: C7MetalCapability {
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

    public func setupAdvancedMetalParameters(for encoder: MTLComputeCommandEncoder, textures: [MTLTexture]) { }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        if canUseAdvancedMetal(on: Shared.shared.metalDevice) {
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

        for (index, factor) in factors.enumerated() {
            var f = factor
            encoder.setBytes(&f, length: MemoryLayout<Float>.size, index: index)
        }

        setupAdvancedMetalParameters(for: encoder, textures: textures)

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
        let device = Shared.shared.defaultDevice

        if let cached = device.pipelineState(for: identity) {
            return cached
        }

        let metalFunction = try Device.readMTLFunction(identity)
        let pipeline = try device.device.makeComputePipelineState(function: metalFunction)

        device.setPipelineState(pipeline, for: identity)
        return pipeline
    }
}
