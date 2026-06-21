//
//  RenderPassContract.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum RenderAttachmentLoadBehavior: String, Sendable, Codable, Equatable, Hashable {
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

public enum RenderAttachmentStoreBehavior: String, Sendable, Codable, Equatable, Hashable {
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

public struct ColorAttachmentContract: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let pixelFormat: String?
    public let loadBehavior: RenderAttachmentLoadBehavior
    public let storeBehavior: RenderAttachmentStoreBehavior
    public let clearsOnLoad: Bool

    public init(index: Int = 0,
                pixelFormat: MTLPixelFormat? = nil,
                loadBehavior: RenderAttachmentLoadBehavior = .clear,
                storeBehavior: RenderAttachmentStoreBehavior = .store) {
        self.index = index
        self.pixelFormat = pixelFormat.map { String(describing: $0) }
        self.loadBehavior = loadBehavior
        self.storeBehavior = storeBehavior
        self.clearsOnLoad = loadBehavior == .clear
    }

    public var fingerprint: String {
        [
            "attachment=\(index)",
            "pixelFormat=\(pixelFormat ?? "preserve")",
            "load=\(loadBehavior.rawValue)",
            "store=\(storeBehavior.rawValue)"
        ].joined(separator: "|")
    }
}

public struct RenderPassContract: Sendable, Codable, Equatable, Hashable {
    public let colorAttachments: [ColorAttachmentContract]
    public let sampleCount: Int
    public let hasDepthAttachment: Bool
    public let hasStencilAttachment: Bool
    public let usesCustomVertexLayout: Bool

    public init(colorAttachments: [ColorAttachmentContract],
                sampleCount: Int = 1,
                hasDepthAttachment: Bool = false,
                hasStencilAttachment: Bool = false,
                usesCustomVertexLayout: Bool = false) {
        self.colorAttachments = colorAttachments.sorted { $0.index < $1.index }
        self.sampleCount = max(sampleCount, 1)
        self.hasDepthAttachment = hasDepthAttachment
        self.hasStencilAttachment = hasStencilAttachment
        self.usesCustomVertexLayout = usesCustomVertexLayout
    }

    public static func singleColor(pixelFormat: MTLPixelFormat? = nil,
                                   sampleCount: Int = 1,
                                   usesCustomVertexLayout: Bool = false) -> RenderPassContract {
        RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(
                    index: 0,
                    pixelFormat: pixelFormat,
                    loadBehavior: .clear,
                    storeBehavior: .store
                )
            ],
            sampleCount: sampleCount,
            usesCustomVertexLayout: usesCustomVertexLayout
        )
    }

    public var fingerprint: String {
        [
            "attachments=\(colorAttachments.map(\.fingerprint).joined(separator: "||"))",
            "sampleCount=\(sampleCount)",
            "depth=\(hasDepthAttachment ? 1 : 0)",
            "stencil=\(hasStencilAttachment ? 1 : 0)",
            "customVertex=\(usesCustomVertexLayout ? 1 : 0)"
        ].joined(separator: "|")
    }

    public func makeDescriptor(destinationTexturesByAttachmentIndex textures: [Int: MTLTexture]) throws -> MTLRenderPassDescriptor {
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
            if attachment.clearsOnLoad {
                colorAttachment.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
            }
        }
        return descriptor
    }

    func makeDescriptor(destinationTexture: MTLTexture) -> MTLRenderPassDescriptor {
        let bindings = Dictionary(
            uniqueKeysWithValues: colorAttachments.map { ($0.index, destinationTexture) }
        )
        return (try? makeDescriptor(destinationTexturesByAttachmentIndex: bindings)) ?? MTLRenderPassDescriptor()
    }

    private func validate(texture: MTLTexture,
                          for attachment: ColorAttachmentContract,
                          referenceTexture: MTLTexture) throws {
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
           String(describing: texture.pixelFormat) != pixelFormatName {
            throw HarbethError.configurationInvalid(
                "Render pass pixel format mismatch on attachment \(attachment.index). Texture pixelFormat=\(texture.pixelFormat), expected \(pixelFormatName)."
            )
        }
    }
}
