//
//  MaskSource.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation

enum MaskSource {
    case descriptor(MaskDescriptor)
    case recipe(AnyMaskRecipe)

    var resolvedMask: MaskDescriptor {
        switch self {
        case .descriptor(let descriptor):
            return descriptor
        case .recipe:
            preconditionFailure("Recipe-backed mask source requires explicit materialization parameters.")
        }
    }

    func materializedDescriptor(component: MaskComponent,
                                blendMode: MaskBlendMode,
                                invert: Bool,
                                featherPolicy: MaskFeatherPolicy,
                                opacity: Float) throws -> MaskDescriptor {
        switch self {
        case .descriptor(let descriptor):
            return descriptor
        case .recipe(let recipe):
            return try recipe.makeMaskDescriptor(
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            )
        }
    }

    func graphDescriptor(component: MaskComponent,
                         blendMode: MaskBlendMode,
                         invert: Bool,
                         featherPolicy: MaskFeatherPolicy,
                         opacity: Float) -> MaskGraphDescriptor {
        switch self {
        case .descriptor(let descriptor):
            return descriptor.graphDescriptor
        case .recipe(let recipe):
            return recipe.graphDescriptor(
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            )
        }
    }

    func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> MaskSource? {
        switch self {
        case .descriptor:
            return nil
        case .recipe(let recipe):
            guard let rebased = try recipe.rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            ) else {
                return nil
            }
            return .recipe(rebased)
        }
    }

    var fingerprintLabel: String {
        switch self {
        case .descriptor(let descriptor):
            return [
                "component=\(descriptor.component.rawValue)",
                "blend=\(descriptor.blendMode.rawValue)",
                "invert=\(descriptor.invert ? 1 : 0)",
                "opacity=\(String(format: "%.4f", descriptor.opacity))",
                "feather=\(descriptor.featherPolicy.amount)"
            ].joined(separator: ",")
        case .recipe(let recipe):
            switch recipe.graphDescriptor.kind {
            case "maskGradientRecipe":
                return "gradient{\(recipe.fingerprint)}"
            case "maskShapeRecipe":
                return "shape{\(recipe.fingerprint)}"
            case "maskPathRecipe":
                return "path{\(recipe.fingerprint)}"
            default:
                return "recipe{\(recipe.fingerprint)}"
            }
        }
    }
}

struct AnyMaskRecipe {
    let profile: RenderProfile
    let fingerprint: String
    let graphDescriptor: MaskGraphDescriptor

    private let graphBuilder: (MaskComponent, MaskBlendMode, Bool, MaskFeatherPolicy, Float) -> MaskGraphDescriptor
    private let descriptorBuilder: (MaskComponent, MaskBlendMode, Bool, MaskFeatherPolicy, Float) throws -> MaskDescriptor
    private let rebasedBuilder: (CGRect, C7Size, C7Size) throws -> AnyMaskRecipe?

    init<R: MaskRecipe>(_ recipe: R) {
        profile = recipe.profile
        fingerprint = recipe.fingerprint
        graphDescriptor = recipe.graphDescriptor
        graphBuilder = { component, blendMode, invert, featherPolicy, opacity in
            recipe.graphDescriptor(
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            )
        }
        descriptorBuilder = { component, blendMode, invert, featherPolicy, opacity in
            try recipe.makeMaskDescriptor(
                component: component,
                blendMode: blendMode,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            )
        }
        rebasedBuilder = { sourceRect, logicalSize, tileInputSize in
            guard let rebasable = recipe as? any MaskRebasableRecipe else {
                return nil
            }
            return try rebasable.rebasedRecipe(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            )
        }
    }

    func graphDescriptor(component: MaskComponent,
                         blendMode: MaskBlendMode,
                         invert: Bool,
                         featherPolicy: MaskFeatherPolicy,
                         opacity: Float) -> MaskGraphDescriptor {
        graphBuilder(component, blendMode, invert, featherPolicy, opacity)
    }

    func makeMaskDescriptor(component: MaskComponent,
                            blendMode: MaskBlendMode,
                            invert: Bool,
                            featherPolicy: MaskFeatherPolicy,
                            opacity: Float) throws -> MaskDescriptor {
        try descriptorBuilder(component, blendMode, invert, featherPolicy, opacity)
    }

    func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe? {
        try rebasedBuilder(sourceRect, logicalSize, tileInputSize)
    }
}
