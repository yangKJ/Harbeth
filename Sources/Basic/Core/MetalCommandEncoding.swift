//
//  MetalCommandEncoding.swift
//  Harbeth
//
//  Created by Condy on 2026/6/11.
//

import Foundation
import MetalKit

public enum MetalCapability: String, CaseIterable, Sendable, Codable {
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

/// The execution route finally selected by the Metal command filter on the current device.
public enum MetalCommandExecutionRoute: String, Sendable, Codable, Equatable, Hashable {
    case preferred
    case fallback
    case unavailable
}

/// Metal command route selection and coding shared device environment.
public struct MetalCommandEnvironment {
    public let device: MTLDevice

    public init(device: MTLDevice) {
        self.device = device
    }

    public func capabilityReport(_ capability: MetalCapability) -> MetalCapabilityReport {
        Device.metalCapabilityReport(capability, on: device)
    }

    public func makeMetalFunction(_ identity: KernelFunctionIdentity) throws -> MTLFunction {
        try validateRuntimeDevice()
        return try Device.readMTLFunction(identity)
    }

    public func makeComputePipelineState(_ identity: KernelFunctionIdentity) throws -> MTLComputePipelineState {
        try validateRuntimeDevice()
        let context = HarbethContext.shared
        if let cached = context.computePipelineState(for: identity) {
            return cached
        }
        return try context.makeComputePipelineState(identity: identity)
    }

    private func validateRuntimeDevice() throws {
        guard HarbethContext.shared.device === device else {
            throw HarbethError.configurationInvalid(
                "Metal command resource resolution requires Harbeth's active runtime device."
            )
        }
    }
}

/// The explicit resource context provided by Harbeth for a Metal command coding.
public struct MetalCommandEncodingContext {
    public let commandBuffer: MTLCommandBuffer
    public let sourceTexture: MTLTexture
    public let destinationTexture: MTLTexture
    public let auxiliaryTextures: [MTLTexture]
    public let environment: MetalCommandEnvironment

    public var device: MTLDevice {
        commandBuffer.device
    }

    init(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws {
        guard textures.count >= 2 else {
            throw HarbethError.filterParameterInvalid("Metal command encoding requires destination and source textures.")
        }
        let destinationTexture = textures[0]
        let sourceTexture = textures[1]
        let device = commandBuffer.device
        guard HarbethContext.shared.device === device else {
            throw HarbethError.configurationInvalid(
                "Metal command buffers must use Harbeth's active runtime device."
            )
        }
        guard textures.allSatisfy({ $0.device === device }) else {
            throw HarbethError.configurationInvalid(
                "Metal command buffer and textures must belong to the same MTLDevice."
            )
        }
        self.commandBuffer = commandBuffer
        self.sourceTexture = sourceTexture
        self.destinationTexture = destinationTexture
        self.auxiliaryTextures = Array(textures.dropFirst(2))
        self.environment = MetalCommandEnvironment(device: device)
    }
}

/// When the standard compute/render/blit/MPS and `C7FilterPipelineProtocol` cannot be expressed,
/// Allow the filter to take over the bottom escape of the command buffer encoding once.
///
/// Ordinary single pass compute should continue to be adopted even if external library or function constants are used.
/// `C7FilterProtocol + .compute(kernel:)`, do not upgrade to this agreement.
public protocol C7MetalCommandEncodingProtocol: C7FilterProtocol {
    var requiredMetalCapabilities: [MetalCapability] { get }

    func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute

    func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture
}

extension C7MetalCommandEncodingProtocol {
    public var requiredMetalCapabilities: [MetalCapability] { [] }

    func encodeMetalCommands(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let context = try MetalCommandEncodingContext(commandBuffer: commandBuffer, textures: textures)
        if destinationTextureContract.aliasingPolicy == .requiredDistinct,
           context.sourceTexture === context.destinationTexture {
            throw HarbethError.configurationInvalid(
                "Metal command contract requires distinct source and destination textures."
            )
        }
        let route = metalCommandExecutionRoute(in: context.environment)
        guard route != .unavailable else {
            let capabilities = requiredMetalCapabilities.map(\.rawValue).joined(separator: ",")
            throw HarbethError.filterError(
                name: String(describing: type(of: self)),
                reason: capabilities.isEmpty
                    ? "Metal command execution is unavailable on the active device."
                    : "Required Metal capabilities are unavailable: \(capabilities)."
            )
        }

        HarbethLogger.log(
            .info,
            category: "metalCommand",
            code: "harbeth.metal_command.route",
            outcome: route == .fallback ? .fallback : .observed,
            metadata: [
                "filter": String(describing: type(of: self)),
                "route": route.rawValue
            ],
            message: "Metal command filter selected its execution route."
        )

        let output = try encodeMetalCommands(context: context, route: route)
        try validateMetalCommandOutput(output, context: context)
        return output
    }

    private func validateMetalCommandOutput(_ output: MTLTexture, context: MetalCommandEncodingContext) throws {
        guard output.device === context.device else {
            throw HarbethError.configurationInvalid(
                "Metal command output texture must belong to the command buffer device."
            )
        }

        let expectedSize = resize(input: C7Size(texture: context.sourceTexture))
        guard output.width == expectedSize.width, output.height == expectedSize.height else {
            throw HarbethError.textureSizeMismatch
        }

        guard output === context.destinationTexture else {
            throw HarbethError.configurationInvalid(
                "Metal command encoding must write and return the destination texture."
            )
        }

        if let expectedPixelFormat = kernelOutputContract.primaryAttachment.pixelFormat.metalPixelFormat,
           output.pixelFormat != expectedPixelFormat {
            throw HarbethError.configurationInvalid(
                "Metal command output pixel format does not match its declared output contract."
            )
        }
    }
}
