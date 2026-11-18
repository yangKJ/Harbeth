//
//  Plugin.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import CoreImage
import CoreVideo
import CoreMedia

public typealias PluginDiagnostics = [String: String]

/// 私有插件包统一向 Harbeth core 暴露的结果载体。
///
/// 这里不承载业务策略，只描述“插件算完之后，把什么交回 Harbeth”。
public enum PluginOutput {
    case texture(MTLTexture)
    /// 完整帧保留像素语义与租约；独立裸纹理由调用方保证生命周期。
    case frame(RenderedFrame)
    case image(C7Image)
    case cgImage(CGImage)
    case ciImage(CIImage)
    case pixelBuffer(CVPixelBuffer)
    case sampleBuffer(CMSampleBuffer)
    case filters([C7FilterProtocol])
    case editRecipe(EditRecipe)
    case localEffect(LocalEffectRecipe)
    case layerComposite(LayerCompositeRecipe)
}

extension PluginOutput {
    public var kind: String {
        switch self {
        case .texture:
            return "texture"
        case .frame:
            return "frame"
        case .image:
            return "image"
        case .cgImage:
            return "cgImage"
        case .ciImage:
            return "ciImage"
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
        case .texture, .frame, .image, .cgImage, .ciImage, .pixelBuffer, .sampleBuffer:
            return true
        case .filters, .editRecipe, .localEffect, .layerComposite:
            return false
        }
    }

    public func makeImageSource() throws -> ImageSource {
        switch self {
        case .texture(let texture):
            return .texture(texture)
        case .frame(let frame):
            return .renderedFrame(frame)
        case .image(let image):
            return .image(image)
        case .cgImage(let image):
            return .cgImage(image)
        case .ciImage(let image):
            return .ciImage(image)
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
        if case .frame(let frame) = self {
            if frame.profile == profile { return frame }
            return try ImageNode.source(.renderedFrame(frame)).makeFrame(profile: profile)
        }
        return try FrameRenderer(source: makeImageSource(), profile: profile).renderFrame()
    }
}

public protocol Plugin {
    var pluginIdentifier: String { get }
    var capability: PluginCapability { get }
    func makeOutput(frame: RenderedFrame) throws -> PluginOutput
    func makeOutput(frame: RenderedFrame, context: PluginContext) throws -> PluginOutput
    func makeDiagnostics(frame: RenderedFrame) throws -> PluginDiagnostics?
}

public extension Plugin {
    var capability: PluginCapability {
        .unverified
    }

    func makeOutput(frame: RenderedFrame, context: PluginContext) throws -> PluginOutput {
        try makeOutput(frame: frame)
    }

    func makeDiagnostics(frame: RenderedFrame) throws -> PluginDiagnostics? {
        nil
    }
}

/// 输出分类标记，不额外约束返回类型；完整帧输出应使用 PluginOutput.frame。
public protocol TexturePlugin: Plugin { }

/// 配方类插件的分类标记，不代表执行是惰性的；已准备的配方直接交给 pluginOutput 入口。
public protocol FilterPlugin: Plugin { }

/// 局部效果插件的分类标记；单独的蒙版应先组成 LocalEffectRecipe 或 EditRecipe。
public protocol MaskPlugin: Plugin { }

@MainActor
public protocol PreviewDisplaying: AnyObject {
    var texture: MTLTexture? { get set }
    var currentRenderedFrame: RenderedFrame? { get }
    func display(_ frame: RenderedFrame?)
}
