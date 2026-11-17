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
    private var storedMask: MaskDescriptor
    private var initialMask: InitialMaskDescriptor?
    public var mask: MaskDescriptor {
        get {
            // 暴露纹理后不能再假设初始化产物未被宿主写入。
            initialMask?.invalidate()
            return storedMask
        }
        set { initialMask?.invalidate(); initialMask = nil; storedMask = newValue }
    }
    public var maskRecipe: MaskCompositeRecipe?
    var maskSource: AnyMaskRecipe?
    public var foregroundBlendType: C7Blend.BlendType?
    public var foregroundBlendOpacity: Float

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.storedMask = mask
        self.maskRecipe = nil
        self.maskSource = nil
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol], maskRecipe: MaskCompositeRecipe, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.storedMask = maskRecipe.baseMask
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
        self.storedMask = try source.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.maskRecipe = recipe as? MaskCompositeRecipe
        self.maskSource = source
        self.initialMask = source.canReuseInitialDescriptor ? InitialMaskDescriptor(storedMask) : nil
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
        if let prepared = initialMask?.take() { return prepared }
        if let maskSource {
            return try maskSource.makeMaskDescriptor(
                component: storedMask.component,
                blendMode: storedMask.blendMode,
                invert: storedMask.invert,
                featherPolicy: storedMask.featherPolicy,
                opacity: storedMask.opacity
            )
        }
        return storedMask
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
                component: storedMask.component,
                blendMode: storedMask.blendMode,
                invert: storedMask.invert,
                featherPolicy: storedMask.featherPolicy,
                opacity: storedMask.opacity
            )
        }
        if let maskRecipe {
            return maskRecipe.graphDescriptor
        }
        return storedMask.graphDescriptor
    }
}

// 只把构造阶段已完成的结果交给首次执行；结构体副本共享一次性领取，后续执行仍重新物化。
private final class InitialMaskDescriptor {
    private let lock = NSLock()
    private var value: MaskDescriptor?
    init(_ value: MaskDescriptor) { self.value = value }
    func take() -> MaskDescriptor? {
        lock.withLock { let result = value; value = nil; return result }
    }
    func invalidate() { lock.withLock { value = nil } }
}
