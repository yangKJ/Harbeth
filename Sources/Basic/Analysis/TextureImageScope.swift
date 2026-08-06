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
    public let valueRange: TextureAnalysisValueRange
    public let normalizesDensity: Bool

    public init(
        kind: TextureImageScopeKind,
        width: Int = 256,
        height: Int = 128,
        intensity: Float = 0.08,
        pixelFormat: PixelFormatContract = .rgba16Float,
        valueRange: TextureAnalysisValueRange = .normalized,
        normalizesDensity: Bool = true
    ) {
        self.kind = kind
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.intensity = max(intensity, 0.0001)
        self.pixelFormat = pixelFormat.preservesInput ? .rgba16Float : pixelFormat
        self.valueRange = valueRange
        self.normalizesDensity = normalizesDensity
    }

    public var fingerprint: String {
        "scope=\(kind.rawValue)|size=\(width)x\(height)|intensity=\(intensity)|range=\(valueRange.fingerprint)|normalizedDensity=\(normalizesDensity ? 1 : 0)|\(pixelFormat.fingerprint)"
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case width
        case height
        case intensity
        case pixelFormat
        case valueRange
        case normalizesDensity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(TextureImageScopeKind.self, forKey: .kind),
            width: try container.decode(Int.self, forKey: .width),
            height: try container.decode(Int.self, forKey: .height),
            intensity: try container.decode(Float.self, forKey: .intensity),
            pixelFormat: try container.decode(PixelFormatContract.self, forKey: .pixelFormat),
            valueRange: try container.decodeIfPresent(TextureAnalysisValueRange.self, forKey: .valueRange) ?? .normalized,
            normalizesDensity: try container.decodeIfPresent(Bool.self, forKey: .normalizesDensity) ?? true
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(pixelFormat, forKey: .pixelFormat)
        try container.encode(valueRange, forKey: .valueRange)
        try container.encode(normalizesDensity, forKey: .normalizesDensity)
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

    /// 把示波器编码进调用方 command buffer，不提交也不等待。
    /// 调用方可把它与同一帧的其他 GPU 工作合并，结果纹理在 command buffer 完成后可读。
    func encodeImageScope(
        _ configuration: TextureImageScopeConfiguration,
        into commandBuffer: MTLCommandBuffer
    ) throws -> RenderedTextureImageScope {
        try GPUImageScopeBackend.encode(texture: target, configuration: configuration, into: commandBuffer)
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
