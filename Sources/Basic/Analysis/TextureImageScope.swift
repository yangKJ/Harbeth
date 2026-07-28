//
//  TextureImageScope.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import CoreGraphics
import Metal

/// GPU 图像示波器类型。
public enum TextureImageScopeKind: String, Sendable, Codable, Equatable, Hashable {
    case luminanceWaveform
    case rgbWaveform
    case vectorscope
}

/// GPU 图像示波器的输出配置。
public struct TextureImageScopeConfiguration: Sendable, Codable, Equatable, Hashable {
    public let kind: TextureImageScopeKind
    public let width: Int
    public let height: Int
    public let intensity: Float
    public let pixelFormat: PixelFormatContract

    public init(
        kind: TextureImageScopeKind,
        width: Int = 256,
        height: Int = 128,
        intensity: Float = 0.08,
        pixelFormat: PixelFormatContract = .rgba16Float
    ) {
        self.kind = kind
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.intensity = max(intensity, 0.0001)
        self.pixelFormat = pixelFormat.preservesInput ? .rgba16Float : pixelFormat
    }

    public var fingerprint: String {
        "scope=\(kind.rawValue)|size=\(width)x\(height)|intensity=\(intensity)|\(pixelFormat.fingerprint)"
    }
}

/// 完全由 GPU 生成的示波器纹理结果。
public struct RenderedTextureImageScope: @unchecked Sendable {
    public let configuration: TextureImageScopeConfiguration
    public let attachment: RenderedAttachment

    init(configuration: TextureImageScopeConfiguration, attachment: RenderedAttachment) {
        self.configuration = configuration
        self.attachment = attachment
    }

    public var texture: MTLTexture { attachment.texture }

    public func makeCGImage(colorSpace: CGColorSpace? = nil) -> CGImage? {
        attachment.makeCGImage(colorSpace: colorSpace, alphaType: .alphaIsOne)
    }
}

public extension MTLTextureCompatible_ {
    /// 在 GPU 上生成亮度波形、RGB 波形或矢量示波器。
    func renderImageScope(_ configuration: TextureImageScopeConfiguration) throws -> RenderedTextureImageScope {
        try GPUImageScopeBackend.render(texture: target, configuration: configuration)
    }
}

public extension RenderedAttachment {
    func renderImageScope(_ configuration: TextureImageScopeConfiguration) throws -> RenderedTextureImageScope {
        try texture.c7.renderImageScope(configuration)
    }
}

public extension RenderedAttachmentSet {
    func renderImageScope(
        for semantic: RenderOutputAttachmentSemantic = .primaryColor,
        configuration: TextureImageScopeConfiguration
    ) throws -> RenderedTextureImageScope? {
        try attachment(for: semantic)?.renderImageScope(configuration)
    }
}

public extension RenderedFrame {
    func renderImageScope(_ configuration: TextureImageScopeConfiguration) throws -> RenderedTextureImageScope {
        try texture.c7.renderImageScope(configuration)
    }
}
