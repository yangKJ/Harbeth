//
//  HarbethRenderPassContract.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
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

public struct HarbethColorAttachmentContract: Sendable, Codable, Equatable, Hashable {
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

public struct HarbethRenderPassContract: Sendable, Codable, Equatable, Hashable {
    public let colorAttachments: [HarbethColorAttachmentContract]
    public let sampleCount: Int
    public let hasDepthAttachment: Bool
    public let hasStencilAttachment: Bool
    public let usesCustomVertexLayout: Bool

    public init(colorAttachments: [HarbethColorAttachmentContract],
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
                                   usesCustomVertexLayout: Bool = false) -> HarbethRenderPassContract {
        HarbethRenderPassContract(
            colorAttachments: [
                HarbethColorAttachmentContract(
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

    func makeDescriptor(destinationTexture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        for attachment in colorAttachments where attachment.index < 8 {
            guard let colorAttachment = descriptor.colorAttachments[attachment.index] else {
                continue
            }
            colorAttachment.texture = destinationTexture
            colorAttachment.loadAction = attachment.loadBehavior.metalValue
            colorAttachment.storeAction = attachment.storeBehavior.metalValue
            if attachment.clearsOnLoad {
                colorAttachment.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
            }
        }
        return descriptor
    }
}
