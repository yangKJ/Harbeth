//
//  ImageNode+Mask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
import Metal

extension ImageNode {
    /// 清除软蒙版边缘的颜色污染，并保持在 `ImageNode` 主路线内处理。
    /// 蒙版尺寸必须与节点最终渲染尺寸一致。
    public func decontaminating(mask: MaskDescriptor,
                                radius: Int = 8,
                                strength: Float = 0.8,
                                opaqueThreshold: Float = 0.9) throws -> ImageNode {
        let coverage = try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
        return applying(MaskForegroundColorDecontamination(
            coverageTexture: coverage,
            radius: min(max(radius, 1), 32),
            strength: min(max(strength.isFinite ? strength : 0.8, 0), 1),
            opaqueThreshold: min(max(opaqueThreshold.isFinite ? opaqueThreshold : 0.9, 0.5), 1)
        ))
    }

    public func applying(mask plane: MaskPlane,
                         filters: [C7FilterProtocol],
                         component: MaskComponent = .red,
                         invert: Bool = false,
                         opacity: Float = 1,
                         mode: EditRecipeMode = .preview) -> ImageNode {
        applying(
            mask: plane.maskDescriptor(component: component, invert: invert, opacity: opacity),
            filters: filters,
            mode: mode
        )
    }

    public func applying(mask expression: MaskExpression,
                         filters: [C7FilterProtocol],
                         profile: RenderProfile = .stablePreview,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        let plane = try expression.execute(profile: profile).plane
        return applying(mask: plane, filters: filters, mode: mode)
    }

    /// 复用局部效果管线的像素精确语义，把效果纹理合成到当前节点。
    /// 大图 tile 等高级宿主可通过这个窄入口避免图层二次采样。
    public func compositing(effectTexture: MTLTexture, mask: MaskDescriptor) -> ImageNode {
        applying(MaskRegionBlend(effectTexture: effectTexture, mask: mask))
    }

    public func applying(mask: MaskDescriptor, filter: C7FilterProtocol, mode: EditRecipeMode = .preview) -> ImageNode {
        applying(mask: mask, filters: [filter], mode: mode)
    }

    public func applying(mask: MaskDescriptor, filters: [C7FilterProtocol], mode: EditRecipeMode = .preview) -> ImageNode {
        applying(mask: mask, filters: filters, foregroundBlendType: nil, foregroundBlendOpacity: 1.0, mode: mode)
    }

    public func applying(mask: MaskDescriptor,
                         filters: [C7FilterProtocol],
                         foregroundBlendType: C7Blend.BlendType?,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) -> ImageNode {
        applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                foregroundBlendType: foregroundBlendType,
                foregroundBlendOpacity: foregroundBlendOpacity
            ),
            mode: mode
        )
    }

    public func applying(mask: MaskCompositeRecipe, filter: C7FilterProtocol, mode: EditRecipeMode = .preview) -> ImageNode {
        applying(mask: mask, filters: [filter], mode: mode)
    }

    public func applying(mask: MaskCompositeRecipe, filters: [C7FilterProtocol], mode: EditRecipeMode = .preview) -> ImageNode {
        applying(
            mask: mask,
            filters: filters,
            foregroundBlendType: nil,
            foregroundBlendOpacity: 1.0,
            mode: mode
        )
    }

    public func applying(mask: MaskCompositeRecipe,
                         filters: [C7FilterProtocol],
                         foregroundBlendType: C7Blend.BlendType?,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) -> ImageNode {
        applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                foregroundBlendType: foregroundBlendType,
                foregroundBlendOpacity: foregroundBlendOpacity
            ),
            mode: mode
        )
    }

    public func applying(mask: MaskGradientRecipe,
                         filter: C7FilterProtocol,
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity,
            mode: mode
        )
    }

    public func applying(mask: MaskGradientRecipe,
                         filters: [C7FilterProtocol],
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                foregroundBlendType: foregroundBlendType,
                foregroundBlendOpacity: foregroundBlendOpacity
            ),
            mode: mode
        )
    }

    public func applying(mask: MaskShapeRecipe,
                         filter: C7FilterProtocol,
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity,
            mode: mode
        )
    }

    public func applying(mask: MaskShapeRecipe,
                         filters: [C7FilterProtocol],
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                foregroundBlendType: foregroundBlendType,
                foregroundBlendOpacity: foregroundBlendOpacity
            ),
            mode: mode
        )
    }

    public func applying(mask: MaskPathRecipe,
                         filter: C7FilterProtocol,
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity,
            mode: mode
        )
    }

    public func applying(mask: MaskPathRecipe,
                         filters: [C7FilterProtocol],
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         foregroundBlendType: C7Blend.BlendType? = nil,
                         foregroundBlendOpacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                foregroundBlendType: foregroundBlendType,
                foregroundBlendOpacity: foregroundBlendOpacity
            ),
            mode: mode
        )
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol],
                                        mask: MaskDescriptor,
                                        foregroundBlendType: C7Blend.BlendType?,
                                        foregroundBlendOpacity: Float) -> LocalEffectRecipe {
        LocalEffectRecipe(
            filters: filters,
            mask: mask,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol],
                                        mask: MaskCompositeRecipe,
                                        foregroundBlendType: C7Blend.BlendType?,
                                        foregroundBlendOpacity: Float) -> LocalEffectRecipe {
        LocalEffectRecipe(
            filters: filters,
            maskRecipe: mask,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }

    private static func makeLocalEffect<R: MaskRecipe>(filters: [C7FilterProtocol],
                                                       mask: R,
                                                       component: MaskComponent,
                                                       blendMode: MaskBlendMode,
                                                       invert: Bool,
                                                       featherPolicy: MaskFeatherPolicy,
                                                       opacity: Float,
                                                       foregroundBlendType: C7Blend.BlendType?,
                                                       foregroundBlendOpacity: Float) throws -> LocalEffectRecipe {
        try LocalEffectRecipe(
            filters: filters,
            maskSource: mask,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }
}
