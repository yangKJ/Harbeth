//
//  RenderCommand.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public struct RenderGeometryDescriptor: Sendable, Codable, Equatable, Hashable {
    public let vertexCount: Int
    public let vertexStride: Int
    public let usesCustomVertices: Bool

    public init(vertexCount: Int,
                vertexStride: Int = 4,
                usesCustomVertices: Bool = false) {
        self.vertexCount = max(vertexCount, 0)
        self.vertexStride = max(vertexStride, 1)
        self.usesCustomVertices = usesCustomVertices
    }

    public var fingerprint: String {
        [
            "vertexCount=\(vertexCount)",
            "vertexStride=\(vertexStride)",
            "customVertices=\(usesCustomVertices ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct RenderCommandDescriptor: Sendable, Codable, Equatable, Hashable {
    public let vertexFunction: KernelFunctionIdentity
    public let fragmentFunction: KernelFunctionIdentity
    public let renderPass: RenderPassContract
    public let outputContract: RenderOutputContract
    public let geometry: RenderGeometryDescriptor
    public let fragmentTextureCount: Int
    public let parameterFingerprint: String
    public let parameterBindings: [KernelParameterBinding]

    public init(vertexFunction: KernelFunctionIdentity,
                fragmentFunction: KernelFunctionIdentity,
                renderPass: RenderPassContract,
                outputContract: RenderOutputContract,
                geometry: RenderGeometryDescriptor,
                fragmentTextureCount: Int,
                parameterFingerprint: String,
                parameterBindings: [KernelParameterBinding] = []) {
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.renderPass = renderPass
        self.outputContract = outputContract
        self.geometry = geometry
        self.fragmentTextureCount = max(fragmentTextureCount, 0)
        self.parameterFingerprint = parameterFingerprint
        self.parameterBindings = parameterBindings
    }

    public var fingerprint: String {
        [
            vertexFunction.fingerprint,
            fragmentFunction.fingerprint,
            renderPass.fingerprint,
            outputContract.fingerprint,
            geometry.fingerprint,
            "fragmentTextures=\(fragmentTextureCount)",
            "parameters=\(parameterFingerprint)",
            "bindings=\(parameterBindings.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }
}

public struct RenderCommandBatchDescriptor: Sendable, Codable, Equatable, Hashable {
    public let renderPass: RenderPassContract
    public let outputContract: RenderOutputContract
    public let commandCount: Int
    public let drawCallCount: Int
    public let commandFingerprints: [String]

    public init(renderPass: RenderPassContract,
                outputContract: RenderOutputContract,
                commandCount: Int,
                drawCallCount: Int,
                commandFingerprints: [String]) {
        self.renderPass = renderPass
        self.outputContract = outputContract
        self.commandCount = max(commandCount, 0)
        self.drawCallCount = max(drawCallCount, 0)
        self.commandFingerprints = commandFingerprints
    }

    public var fingerprint: String {
        [
            renderPass.fingerprint,
            outputContract.fingerprint,
            "commandCount=\(commandCount)",
            "drawCalls=\(drawCallCount)",
            "commands=\(commandFingerprints.joined(separator: "||"))"
        ].joined(separator: "|")
    }
}

public struct RenderCommand {
    public let descriptor: RenderCommandDescriptor
    public let filter: RenderProtocol
    public let sourceTexture: MTLTexture

    public init(filter: RenderProtocol,
                sourceTexture: MTLTexture,
                renderPass: RenderPassContract? = nil) {
        self.filter = filter
        self.sourceTexture = sourceTexture
        self.descriptor = filter.renderCommandDescriptor(
            inputSize: C7Size(width: sourceTexture.width, height: sourceTexture.height),
            renderPass: renderPass
        )
    }
}

public struct RenderCommandBatch {
    public let descriptor: RenderCommandBatchDescriptor
    public let renderPass: RenderPassContract
    public let destinationTexturesByAttachmentIndex: [Int: MTLTexture]
    public let commands: [RenderCommand]

    public init(renderPass: RenderPassContract,
                destinationTexturesByAttachmentIndex: [Int: MTLTexture],
                commands: [RenderCommand]) throws {
        guard commands.isEmpty == false else {
            throw HarbethError.configurationInvalid("Render command batch must contain at least one command.")
        }
        _ = try renderPass.makeDescriptor(destinationTexturesByAttachmentIndex: destinationTexturesByAttachmentIndex)
        for command in commands where command.descriptor.renderPass != renderPass {
            throw HarbethError.configurationInvalid(
                "Render command batch contains a command whose render pass contract does not match the batch render pass."
            )
        }
        let outputContract = commands[0].descriptor.outputContract
        for command in commands where command.descriptor.outputContract != outputContract {
            throw HarbethError.configurationInvalid(
                "Render command batch contains a command whose output contract does not match the batch output contract."
            )
        }
        self.renderPass = renderPass
        self.destinationTexturesByAttachmentIndex = destinationTexturesByAttachmentIndex
        self.commands = commands
        self.descriptor = RenderCommandBatchDescriptor(
            renderPass: renderPass,
            outputContract: outputContract,
            commandCount: commands.count,
            drawCallCount: commands.count,
            commandFingerprints: commands.map(\.descriptor.fingerprint)
        )
    }
}

public extension RenderProtocol {
    func renderCommandDescriptor(inputSize: C7Size,
                                 renderPass: RenderPassContract? = nil) -> RenderCommandDescriptor {
        let vertexIdentity: KernelFunctionIdentity
        let fragmentIdentity: KernelFunctionIdentity
        switch modifier {
        case .render(let vertex, let fragment):
            vertexIdentity = KernelFunctionIdentity(kind: .render, primaryName: vertex)
            fragmentIdentity = KernelFunctionIdentity(kind: .render, primaryName: fragment)
        default:
            vertexIdentity = KernelFunctionIdentity(kind: .render, primaryName: "unsupportedVertex")
            fragmentIdentity = KernelFunctionIdentity(kind: .render, primaryName: "unsupportedFragment")
        }
        let customVertices = setupVertices(inputSize: inputSize)
        let vertexStride = renderVertexStride
        let geometry = RenderGeometryDescriptor(
            vertexCount: max((customVertices ?? Rendering.defaultVertices).count / max(vertexStride, 1), 0),
            vertexStride: vertexStride,
            usesCustomVertices: customVertices != nil
        )
        let parameterFingerprint = factors.map { String(format: "%.4f", $0) }.joined(separator: ",")
        let parameterBindings = kernelParameterBindings
        let outputContract = renderOutputContract
        let resolvedRenderPass = renderPass ?? RenderPassContract(
            colorAttachments: outputContract.attachments.map {
                ColorAttachmentContract(index: $0.index, pixelFormat: $0.pixelFormat.metalPixelFormat)
            },
            sampleCount: 1,
            usesCustomVertexLayout: geometry.usesCustomVertices || vertexStride != 4
        )
        return RenderCommandDescriptor(
            vertexFunction: vertexIdentity,
            fragmentFunction: fragmentIdentity,
            renderPass: resolvedRenderPass,
            outputContract: outputContract,
            geometry: geometry,
            fragmentTextureCount: 1 + otherInputTextures.count,
            parameterFingerprint: parameterFingerprint,
            parameterBindings: parameterBindings
        )
    }
}
