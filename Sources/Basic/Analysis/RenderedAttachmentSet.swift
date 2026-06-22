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

    init(index: Int,
         semantic: RenderOutputAttachmentSemantic,
         texture: MTLTexture,
         debugPolicy: RenderOutputAttachmentDebugPolicy) {
        self.index = index
        self.semantic = semantic
        self.texture = texture
        self.pixelFormat = texture.pixelFormat
        self.debugPolicy = debugPolicy
    }

    public func makeCGImage(colorSpace: CGColorSpace? = nil,
                            alphaType: AlphaType = .premultiplied) -> CGImage? {
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

    public func makeCGImage(for semantic: RenderOutputAttachmentSemantic,
                            colorSpace: CGColorSpace? = nil,
                            alphaType: AlphaType = .premultiplied) -> CGImage? {
        attachment(for: semantic)?.makeCGImage(colorSpace: colorSpace, alphaType: alphaType)
    }
}

public extension RenderProtocol {
    /// 直接执行一次多 attachment render，并把所有输出 attachment 以稳定结构返回。
    ///
    /// 这个入口刻意保持轻量，只服务单个 render primitive 的附件输出调试与分析读取，
    /// 不把 Harbeth 扩展成重型 editor runtime。
    func renderAttachmentSet(from sourceTexture: MTLTexture, identifier: String = "RenderAttachmentSet") throws -> RenderedAttachmentSet {
        let inputSize = C7Size(width: sourceTexture.width, height: sourceTexture.height)
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
        guard let commandBuffer = Shared.shared.commandQueue.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        commandBuffer.label = "Harbeth.RenderAttachmentSet.\(identifier)"
        try Rendering.encode(batch: batch, commandBuffer: commandBuffer)
        commandBuffer.commitAndWaitUntilCompleted(identifier: identifier)

        let attachments: [RenderedAttachment] = descriptor.outputContract.attachments.compactMap { attachment in
            guard let texture = destinationTextures[attachment.index] else { return nil }
            return RenderedAttachment(
                index: attachment.index,
                semantic: attachment.semantic,
                texture: texture,
                debugPolicy: attachment.debugPolicy
            )
        }
        return RenderedAttachmentSet(
            outputContract: descriptor.outputContract,
            attachments: attachments
        )
    }

    private func makeDestinationTextures(outputContract: RenderOutputContract,
                                         outputSize: C7Size,
                                         identifier: String) throws -> [Int: MTLTexture] {
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
