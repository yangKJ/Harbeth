//
//  RenderPassContract.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

enum RenderAttachmentLoadBehavior: String, Sendable, Codable, Equatable, Hashable {
    case dontCare
    case load
    case clear

    var metalValue: MTLLoadAction {
        switch self {
        case .dontCare:
            return .dontCare
        case .load:
            return .load
        case .clear:
            return .clear
        }
    }
}

enum RenderAttachmentStoreBehavior: String, Sendable, Codable, Equatable, Hashable {
    case dontCare
    case store
    case multisampleResolve
    case storeAndMultisampleResolve

    var metalValue: MTLStoreAction {
        switch self {
        case .dontCare:
            return .dontCare
        case .store:
            return .store
        case .multisampleResolve:
            return .multisampleResolve
        case .storeAndMultisampleResolve:
            return .storeAndMultisampleResolve
        }
    }
}

struct ColorAttachmentContract: Sendable, Codable, Equatable, Hashable {
    let index: Int
    let pixelFormat: String?
    let loadBehavior: RenderAttachmentLoadBehavior
    let storeBehavior: RenderAttachmentStoreBehavior
    let clearsOnLoad: Bool

    init(index: Int = 0,
         pixelFormat: MTLPixelFormat? = nil,
         loadBehavior: RenderAttachmentLoadBehavior = .clear,
         storeBehavior: RenderAttachmentStoreBehavior = .store) {
        self.index = index
        self.pixelFormat = pixelFormat.map { PixelFormatContract(pixelFormat: $0, preservesInput: false).name }
        self.loadBehavior = loadBehavior
        self.storeBehavior = storeBehavior
        self.clearsOnLoad = loadBehavior == .clear
    }

    var fingerprint: String {
        [
            "attachment=\(index)",
            "pixelFormat=\(pixelFormat ?? "preserve")",
            "load=\(loadBehavior.rawValue)",
            "store=\(storeBehavior.rawValue)"
        ].joined(separator: "|")
    }
}

struct RenderPassContract: Sendable, Codable, Equatable, Hashable {
    let colorAttachments: [ColorAttachmentContract]
    let sampleCount: Int
    let hasDepthAttachment: Bool
    let hasStencilAttachment: Bool
    let usesCustomVertexLayout: Bool
    let blendMode: RenderBlendMode

    init(colorAttachments: [ColorAttachmentContract],
         sampleCount: Int = 1,
         hasDepthAttachment: Bool = false,
         hasStencilAttachment: Bool = false,
         usesCustomVertexLayout: Bool = false,
         blendMode: RenderBlendMode = .disabled) {
        self.colorAttachments = colorAttachments.sorted { $0.index < $1.index }
        self.sampleCount = max(sampleCount, 1)
        self.hasDepthAttachment = hasDepthAttachment
        self.hasStencilAttachment = hasStencilAttachment
        self.usesCustomVertexLayout = usesCustomVertexLayout
        self.blendMode = blendMode
    }

    static func singleColor(pixelFormat: MTLPixelFormat? = nil,
                            sampleCount: Int = 1,
                            usesCustomVertexLayout: Bool = false,
                            loadBehavior: RenderAttachmentLoadBehavior = .clear,
                            storeBehavior: RenderAttachmentStoreBehavior = .store,
                            blendMode: RenderBlendMode = .disabled) -> RenderPassContract {
        RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(
                    index: 0,
                    pixelFormat: pixelFormat,
                    loadBehavior: loadBehavior,
                    storeBehavior: storeBehavior
                )
            ],
            sampleCount: sampleCount,
            usesCustomVertexLayout: usesCustomVertexLayout,
            blendMode: blendMode
        )
    }

    var fingerprint: String {
        [
            "attachments=\(colorAttachments.map(\.fingerprint).joined(separator: "||"))",
            "sampleCount=\(sampleCount)",
            "depth=\(hasDepthAttachment ? 1 : 0)",
            "stencil=\(hasStencilAttachment ? 1 : 0)",
            "customVertex=\(usesCustomVertexLayout ? 1 : 0)",
            "blend=\(blendMode.rawValue)"
        ].joined(separator: "|")
    }

    func makeDescriptor(destinationTexturesByAttachmentIndex textures: [Int: MTLTexture],
                        resolveTexturesByAttachmentIndex resolveTextures: [Int: MTLTexture] = [:]) throws -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        guard let primaryAttachment = colorAttachments.first else {
            throw HarbethError.configurationInvalid("Render pass must declare at least one color attachment.")
        }
        guard let primaryTexture = textures[primaryAttachment.index] else {
            throw HarbethError.configurationInvalid("Missing destination texture for color attachment \(primaryAttachment.index).")
        }
        for attachment in colorAttachments {
            guard let texture = textures[attachment.index] else {
                throw HarbethError.configurationInvalid("Missing destination texture for color attachment \(attachment.index).")
            }
            try validate(texture: texture, for: attachment, referenceTexture: primaryTexture)
            guard let colorAttachment = descriptor.colorAttachments[attachment.index] else {
                continue
            }
            colorAttachment.texture = texture
            colorAttachment.loadAction = attachment.loadBehavior.metalValue
            colorAttachment.storeAction = attachment.storeBehavior.metalValue
            if let resolveTexture = resolveTextures[attachment.index] {
                try validateResolveTexture(resolveTexture, for: attachment, multisampleTexture: texture)
                colorAttachment.resolveTexture = resolveTexture
            } else if attachment.storeBehavior == .multisampleResolve
                        || attachment.storeBehavior == .storeAndMultisampleResolve {
                throw HarbethError.configurationInvalid(
                    "Missing resolve texture for color attachment \(attachment.index)."
                )
            }
            if attachment.clearsOnLoad {
                colorAttachment.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
            }
        }
        return descriptor
    }

    private func validateResolveTexture(_ resolveTexture: MTLTexture,
                                        for attachment: ColorAttachmentContract,
                                        multisampleTexture: MTLTexture) throws {
        guard multisampleTexture.sampleCount > 1 else {
            throw HarbethError.configurationInvalid("Resolve source must be multisampled.")
        }
        guard resolveTexture.sampleCount == 1,
              resolveTexture.width == multisampleTexture.width,
              resolveTexture.height == multisampleTexture.height,
              resolveTexture.pixelFormat == multisampleTexture.pixelFormat,
              resolveTexture.usage.contains(.renderTarget) else {
            throw HarbethError.configurationInvalid(
                "Resolve texture for attachment \(attachment.index) must declare renderTarget usage, be single-sample, and match size/pixel format."
            )
        }
    }

    private func validate(texture: MTLTexture, for attachment: ColorAttachmentContract, referenceTexture: MTLTexture) throws {
        guard texture.usage.contains(.renderTarget) else {
            throw HarbethError.configurationInvalid(
                "Render pass attachment \(attachment.index) must declare MTLTextureUsage.renderTarget."
            )
        }
        guard texture.width == referenceTexture.width,
              texture.height == referenceTexture.height else {
            throw HarbethError.configurationInvalid(
                "Render pass color attachments must share the same size. Attachment \(attachment.index) is \(texture.width)x\(texture.height), expected \(referenceTexture.width)x\(referenceTexture.height)."
            )
        }
        let expectedSampleCount = max(sampleCount, 1)
        guard texture.sampleCount == expectedSampleCount else {
            throw HarbethError.configurationInvalid(
                "Render pass sample count mismatch on attachment \(attachment.index). Texture sampleCount=\(texture.sampleCount), expected \(expectedSampleCount)."
            )
        }
        if let pixelFormatName = attachment.pixelFormat,
           PixelFormatContract(pixelFormat: texture.pixelFormat, preservesInput: false).name != pixelFormatName {
            throw HarbethError.configurationInvalid(
                "Render pass pixel format mismatch on attachment \(attachment.index). Texture pixelFormat=\(texture.pixelFormat), expected \(pixelFormatName)."
            )
        }
    }
}
