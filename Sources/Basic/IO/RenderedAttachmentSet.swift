//
//  RenderedAttachmentSet.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics
import Metal

/// 单个 render attachment 的稳定包装，便于上层按 semantic 做调试、读回和预览。
public struct RenderedAttachment: @unchecked Sendable {
    public let index: Int
    public let semantic: RenderOutputAttachmentSemantic
    public let texture: MTLTexture
    public let pixelFormat: MTLPixelFormat
    public let debugPolicy: RenderOutputAttachmentDebugPolicy

    init(index: Int, semantic: RenderOutputAttachmentSemantic, texture: MTLTexture, debugPolicy: RenderOutputAttachmentDebugPolicy) {
        self.index = index
        self.semantic = semantic
        self.texture = texture
        self.pixelFormat = texture.pixelFormat
        self.debugPolicy = debugPolicy
    }

    public func makeCGImage(colorSpace: CGColorSpace? = nil, alphaType: AlphaType = .premultiplied) -> CGImage? {
        texture.c7.toCGImage(
            colorSpace: colorSpace,
            pixelFormat: debugPolicy.preferredReadbackPixelFormat.metalPixelFormat,
            alphaType: alphaType
        )
    }
}

/// 一次多 attachment render 的稳定输出集合。
public struct RenderedAttachmentSet: @unchecked Sendable {
    public let outputContract: RenderOutputContract
    public let attachments: [RenderedAttachment]

    init(outputContract: RenderOutputContract, attachments: [RenderedAttachment]) {
        self.outputContract = outputContract
        self.attachments = attachments.sorted { $0.index < $1.index }
    }

    public var primary: RenderedAttachment? {
        attachment(for: .primaryColor)
    }

    public var debugPolicies: [RenderOutputAttachmentDebugPolicy] {
        attachments.map(\.debugPolicy)
    }

    public func attachment(index: Int) -> RenderedAttachment? {
        attachments.first { $0.index == index }
    }

    public func attachment(for semantic: RenderOutputAttachmentSemantic) -> RenderedAttachment? {
        attachments.first { $0.semantic == semantic }
    }

    public func texture(for semantic: RenderOutputAttachmentSemantic) -> MTLTexture? {
        attachment(for: semantic)?.texture
    }

    public func makeCGImage(for semantic: RenderOutputAttachmentSemantic, colorSpace: CGColorSpace? = nil, alphaType: AlphaType = .premultiplied) -> CGImage? {
        attachment(for: semantic)?.makeCGImage(colorSpace: colorSpace, alphaType: alphaType)
    }
}

public extension RenderProtocol {
    /// 把多 attachment render 编码进调用方提供的 command buffer，但不负责提交或等待。
    ///
    /// command buffer 必须保留 encoded resources；返回纹理只有在它完成后才可做 CPU 读回。
    /// 调用方负责提交顺序、完成状态与错误处理。该入口允许上层把 attachment render 与后续
    /// GPU pass 放进同一批次。
    func encodeAttachmentSet(from sourceTexture: MTLTexture, commandBuffer: MTLCommandBuffer, identifier: String = "RenderAttachmentSet") throws -> RenderedAttachmentSet {
        guard sourceTexture.device === Shared.shared.metalDevice,
              commandBuffer.device === Shared.shared.metalDevice else {
            throw HarbethError.configurationInvalid("Attachment rendering requires source texture, command buffer, and Harbeth context to share one Metal device.")
        }
        guard commandBuffer.retainedReferences else {
            throw HarbethError.configurationInvalid("Attachment rendering requires a command buffer that retains encoded resources.")
        }
        guard commandBuffer.status == .notEnqueued || commandBuffer.status == .enqueued else {
            throw HarbethError.configurationInvalid("Attachment rendering requires a command buffer that still accepts encoding.")
        }
        let inputSize = C7Size(texture: sourceTexture)
        let descriptor = renderCommandDescriptor(inputSize: inputSize)
        let outputSize = resize(input: inputSize)
        let destinationTextures = try makeDestinationTextures(
            outputContract: descriptor.outputContract,
            outputSize: outputSize,
            identifier: identifier
        )
        let command = RenderCommand(
            filter: self,
            sourceTexture: sourceTexture,
            renderPass: descriptor.renderPass
        )
        let batch = try RenderCommandBatch(
            renderPass: descriptor.renderPass,
            destinationTexturesByAttachmentIndex: destinationTextures,
            commands: [command]
        )
        try Rendering.encode(batch: batch, commandBuffer: commandBuffer)

        let attachments: [RenderedAttachment] = descriptor.outputContract.attachments.compactMap { attachment in
            guard let texture = destinationTextures[attachment.index] else { return nil }
            return RenderedAttachment(
                index: attachment.index,
                semantic: attachment.semantic,
                texture: texture,
                debugPolicy: attachment.debugPolicy
            )
        }
        return RenderedAttachmentSet(outputContract: descriptor.outputContract, attachments: attachments)
    }

    /// 直接执行一次多 attachment render，并把所有输出 attachment 以稳定结构返回。
    ///
    /// 这个入口刻意保持为 attachment output bridge：
    /// 服务单个 render primitive 的附件读取、调试与后续分析装配，
    /// 不把 Harbeth 扩展成重型 editor runtime。
    func renderAttachmentSet(from sourceTexture: MTLTexture, identifier: String = "RenderAttachmentSet") throws -> RenderedAttachmentSet {
        guard let commandBuffer = Shared.shared.commandQueue.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        commandBuffer.label = "Harbeth.RenderAttachmentSet.\(identifier)"
        let attachmentSet = try encodeAttachmentSet(
            from: sourceTexture,
            commandBuffer: commandBuffer,
            identifier: identifier
        )
        commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)
        guard commandBuffer.status == .completed else {
            if let error = commandBuffer.error {
                throw HarbethError.error(error)
            }
            throw HarbethError.commandBufferAsyncCommit(commandBuffer.status)
        }
        return attachmentSet
    }

    private func makeDestinationTextures(outputContract: RenderOutputContract, outputSize: C7Size, identifier: String) throws -> [Int: MTLTexture] {
        var textures: [Int: MTLTexture] = [:]
        for attachment in outputContract.attachments {
            let pixelFormat = attachment.pixelFormat.metalPixelFormat ?? .rgba8Unorm
            let texture = try TextureLoader.makeTexture(
                width: outputSize.width,
                height: outputSize.height,
                options: [
                    .texturePixelFormat: pixelFormat,
                    .textureUsage: MTLTextureUsage([.shaderRead, .renderTarget])
                ],
                identifier: "\(identifier).attachment\(attachment.index)"
            )
            textures[attachment.index] = texture
        }
        return textures
    }
}
