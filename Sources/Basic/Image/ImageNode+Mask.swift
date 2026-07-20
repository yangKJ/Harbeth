//
//  ImageNode+Mask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
import Metal

extension ImageNode {
    /// Uses the local-effect pipeline's pixel-exact semantics to composite an
    /// effect texture onto the current node. Advanced hosts such as tiled image
    /// renderers can use this narrow entry point without layer resampling.
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
