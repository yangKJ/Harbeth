//
//  LocalEffectRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import Metal

public struct LocalEffectRecipe {
    public var filters: [C7FilterProtocol]
    public var mask: MaskDescriptor
    public var maskRecipe: MaskCompositeRecipe?
    var maskSource: AnyMaskRecipe?
    public var foregroundBlendType: C7Blend.BlendType?
    public var foregroundBlendOpacity: Float

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = mask
        self.maskRecipe = nil
        self.maskSource = nil
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol], maskRecipe: MaskCompositeRecipe, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = maskRecipe.baseMask
        self.maskRecipe = maskRecipe
        self.maskSource = AnyMaskRecipe(maskRecipe)
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    init<R: MaskRecipe>(filters: [C7FilterProtocol],
                        maskSource recipe: R,
                        component: MaskComponent = .red,
                        blendMode: MaskBlendMode = .mix,
                        invert: Bool = false,
                        featherPolicy: MaskFeatherPolicy = .none,
                        opacity: Float = 1.0,
                        foregroundBlendType: C7Blend.BlendType? = nil,
                        foregroundBlendOpacity: Float = 1.0) throws {
        let source = AnyMaskRecipe(recipe)
        self.filters = filters
        self.mask = try source.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.maskRecipe = recipe as? MaskCompositeRecipe
        self.maskSource = source
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init<R: MaskRecipe>(filters: [C7FilterProtocol],
                               mask recipe: R,
                               component: MaskComponent = .red,
                               blendMode: MaskBlendMode = .mix,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1.0,
                               foregroundBlendType: C7Blend.BlendType? = nil,
                               foregroundBlendOpacity: Float = 1.0) throws {
        try self.init(
            filters: filters,
            maskSource: recipe,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            foregroundBlendType: foregroundBlendType,
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }

    func resolvedMaskDescriptor() throws -> MaskDescriptor {
        if let maskRecipe {
            return try maskRecipe.makeMaskDescriptor()
        }
        if let maskSource {
            return try maskSource.makeMaskDescriptor(
                component: mask.component,
                blendMode: mask.blendMode,
                invert: mask.invert,
                featherPolicy: mask.featherPolicy,
                opacity: mask.opacity
            )
        }
        return mask
    }

    var recipeDescriptor: LocalEffectRecipeDescriptor {
        LocalEffectRecipeDescriptor(
            filters: filters.map(\.recipeDescriptor),
            mask: maskGraphDescriptor,
            foregroundBlendMode: foregroundBlendType.map(String.init(describing:)),
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }

    private var maskGraphDescriptor: MaskGraphDescriptor {
        if let maskSource {
            return maskSource.graphDescriptor(
                component: mask.component,
                blendMode: mask.blendMode,
                invert: mask.invert,
                featherPolicy: mask.featherPolicy,
                opacity: mask.opacity
            )
        }
        if let maskRecipe {
            return maskRecipe.graphDescriptor
        }
        return mask.graphDescriptor
    }
}
