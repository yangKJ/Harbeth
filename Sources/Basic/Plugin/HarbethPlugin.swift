//
//  HarbethPlugin.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import CoreVideo
import CoreMedia

public typealias HarbethPluginDiagnostics = [String: String]

/// 私有插件包统一向 Harbeth core 暴露的结果载体。
///
/// 这里不承载业务策略，只描述“插件算完之后，把什么交回 Harbeth”。
public enum HarbethPluginOutput {
    case texture(MTLTexture)
    case image(C7Image)
    case cgImage(CGImage)
    case pixelBuffer(CVPixelBuffer)
    case sampleBuffer(CMSampleBuffer)
    case filters([C7FilterProtocol])
    case editRecipe(EditRecipe)
    case localEffect(LocalEffectRecipe)
    case layerComposite(LayerCompositeRecipe)
}

extension HarbethPluginOutput {
    public var kind: String {
        switch self {
        case .texture:
            return "texture"
        case .image:
            return "image"
        case .cgImage:
            return "cgImage"
        case .pixelBuffer:
            return "pixelBuffer"
        case .sampleBuffer:
            return "sampleBuffer"
        case .filters:
            return "filters"
        case .editRecipe:
            return "editRecipe"
        case .localEffect:
            return "localEffect"
        case .layerComposite:
            return "layerComposite"
        }
    }

    public var isSourceLike: Bool {
        switch self {
        case .texture, .image, .cgImage, .pixelBuffer, .sampleBuffer:
            return true
        case .filters, .editRecipe, .localEffect, .layerComposite:
            return false
        }
    }

    public func makeImageSource() throws -> ImageSource {
        switch self {
        case .texture(let texture):
            return .texture(texture)
        case .image(let image):
            return .image(image)
        case .cgImage(let image):
            return .cgImage(image)
        case .pixelBuffer(let pixelBuffer):
            return .pixelBuffer(pixelBuffer)
        case .sampleBuffer(let sampleBuffer):
            return .sampleBuffer(sampleBuffer)
        case .filters, .editRecipe, .localEffect, .layerComposite:
            throw HarbethError.configurationInvalid(
                "Plugin output \(kind) cannot be materialized as an ImageSource."
            )
        }
    }

    public func sourceDescriptor() throws -> ImageSourceDescriptor {
        try makeImageSource().descriptor
    }

    public func makePreviewFrame(profile: RenderProfile = .stablePreview) throws -> RenderedFrame {
        try FrameRenderer(source: makeImageSource(), profile: profile).renderFrame()
    }
}

public protocol HarbethPlugin {
    var pluginIdentifier: String { get }
    func makeOutput(frame: RenderedFrame) throws -> HarbethPluginOutput
    func makeDiagnostics(frame: RenderedFrame) throws -> HarbethPluginDiagnostics?
}

public extension HarbethPlugin {
    func makeDiagnostics(frame: RenderedFrame) throws -> HarbethPluginDiagnostics? {
        nil
    }
}

/// 适合“直接产出 texture / image / pixelBuffer / sampleBuffer”的插件。
public protocol HarbethTexturePlugin: HarbethPlugin { }

/// 适合“返回 filters / edit recipe / layer composite”的插件。
public protocol HarbethFilterPlugin: HarbethPlugin { }

/// 适合“返回 local effect / edit recipe”等局部编辑结果的插件。
public protocol HarbethMaskPlugin: HarbethPlugin { }

public protocol HarbethPreviewDisplaying: AnyObject {
    var texture: MTLTexture? { get set }
    var currentRenderedFrame: RenderedFrame? { get }
    func display(_ frame: RenderedFrame?)
}
