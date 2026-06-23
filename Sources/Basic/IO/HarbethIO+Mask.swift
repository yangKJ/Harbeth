//
//  HarbethIO+Mask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Metal

extension HarbethIO {

    /// 从当前 `HarbethIO` 输出结果直接生成 mask texture。
    ///
    /// 适合上层先用轻量 filters 路线得到结果，再按 analysis scope 提取局部区域。
    public func renderMaskTexture(profile: RenderProfile = .readbackQuality,
                                  derivative: ImageDerivativeSpec? = nil,
                                  scope: TextureAnalysisScope,
                                  pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try renderFrame(profile: profile, derivative: derivative).makeMaskTexture(
            scope: scope,
            pixelFormat: pixelFormat
        )
    }

    /// 从当前 `HarbethIO` 输出结果直接生成 `MaskDescriptor`。
    public func renderMaskDescriptor(profile: RenderProfile = .readbackQuality,
                                     derivative: ImageDerivativeSpec? = nil,
                                     scope: TextureAnalysisScope,
                                     component: MaskComponent = .red,
                                     blendMode: MaskBlendMode = .mix,
                                     invert: Bool = false,
                                     featherPolicy: MaskFeatherPolicy = .none,
                                     opacity: Float = 1.0,
                                     pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try renderFrame(profile: profile, derivative: derivative).makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }

    /// 当末端 filter 是 render primitive 时，从指定 attachment 直接提取 mask texture。
    public func renderAttachmentMaskTexture(profile: RenderProfile = .readbackQuality,
                                            semantic: RenderOutputAttachmentSemantic,
                                            scope: TextureAnalysisScope,
                                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try renderAttachmentSet(profile: profile)?.makeMaskTexture(
            for: semantic,
            scope: scope,
            pixelFormat: pixelFormat
        )
    }

    /// 当末端 filter 是 render primitive 时，从指定 attachment 直接提取 `MaskDescriptor`。
    public func renderAttachmentMaskDescriptor(profile: RenderProfile = .readbackQuality,
                                               semantic: RenderOutputAttachmentSemantic,
                                               scope: TextureAnalysisScope,
                                               component: MaskComponent = .red,
                                               blendMode: MaskBlendMode = .mix,
                                               invert: Bool = false,
                                               featherPolicy: MaskFeatherPolicy = .none,
                                               opacity: Float = 1.0,
                                               pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try renderAttachmentSet(profile: profile)?.makeMaskDescriptor(
            for: semantic,
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

extension HarbethIO where Dest == MTLTexture {

    /// 为已经产出的前景 texture 提供一个轻量局部贴回入口。
    ///
    /// 调用方只需要提供背景、前景和 mask，仍然继续走 `HarbethIO` 路线；
    /// 底层执行 primitive `MaskRegionBlend` 保持内部化。
    public static func maskedBlend(background: MTLTexture,
                                   foreground: MTLTexture,
                                   mask: MaskDescriptor) -> HarbethIO<MTLTexture> {
        HarbethIO(
            element: background,
            filter: MaskRegionBlend(effectTexture: foreground, mask: mask)
        )
    }
}
