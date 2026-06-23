//
//  ImageNode+Mask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation

extension ImageNode {
    public func applying(mask: MaskDescriptor, filter: C7FilterProtocol, mode: EditRecipeMode = .preview) -> ImageNode {
        applying(mask: mask, filters: [filter], mode: mode)
    }

    public func applying(mask: MaskDescriptor, filters: [C7FilterProtocol], mode: EditRecipeMode = .preview) -> ImageNode {
        applying(localEffect: Self.makeLocalEffect(filters: filters, mask: mask), mode: mode)
    }

    public func applying(mask: MaskCompositeRecipe, filter: C7FilterProtocol, mode: EditRecipeMode = .preview) -> ImageNode {
        applying(mask: mask, filters: [filter], mode: mode)
    }

    public func applying(mask: MaskCompositeRecipe, filters: [C7FilterProtocol], mode: EditRecipeMode = .preview) -> ImageNode {
        applying(localEffect: Self.makeLocalEffect(filters: filters, mask: mask), mode: mode)
    }

    public func applying(mask: MaskGradientRecipe,
                         filter: C7FilterProtocol,
                         component: MaskComponent = .red,
                         blendMode: MaskBlendMode = .mix,
                         invert: Bool = false,
                         featherPolicy: MaskFeatherPolicy = .none,
                         opacity: Float = 1.0,
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
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
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
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
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
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
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
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
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            mask: mask,
            filters: [filter],
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
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
                         mode: EditRecipeMode = .preview) throws -> ImageNode {
        try applying(
            localEffect: Self.makeLocalEffect(
                filters: filters,
                mask: mask,
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            mode: mode
        )
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol], mask: MaskDescriptor) -> LocalEffectRecipe {
        LocalEffectRecipe(filters: filters, mask: mask)
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol], mask: MaskCompositeRecipe) -> LocalEffectRecipe {
        LocalEffectRecipe(filters: filters, maskRecipe: mask)
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol],
                                        mask: MaskGradientRecipe,
                                        component: MaskComponent,
                                        blendMode: MaskBlendMode,
                                        invert: Bool,
                                        featherPolicy: MaskFeatherPolicy,
                                        opacity: Float) throws -> LocalEffectRecipe {
        try LocalEffectRecipe(
            filters: filters,
            maskGradientRecipe: mask,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol],
                                        mask: MaskShapeRecipe,
                                        component: MaskComponent,
                                        blendMode: MaskBlendMode,
                                        invert: Bool,
                                        featherPolicy: MaskFeatherPolicy,
                                        opacity: Float) throws -> LocalEffectRecipe {
        try LocalEffectRecipe(
            filters: filters,
            maskShapeRecipe: mask,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    private static func makeLocalEffect(filters: [C7FilterProtocol],
                                        mask: MaskPathRecipe,
                                        component: MaskComponent,
                                        blendMode: MaskBlendMode,
                                        invert: Bool,
                                        featherPolicy: MaskFeatherPolicy,
                                        opacity: Float) throws -> LocalEffectRecipe {
        try LocalEffectRecipe(
            filters: filters,
            maskPathRecipe: mask,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}
