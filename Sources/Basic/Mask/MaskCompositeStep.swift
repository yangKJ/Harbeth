//
//  MaskCompositeStep.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

private enum MaskCompositeOperation {
    case add
    case intersect
    case subtract
    case exclude

    var name: String {
        switch self {
        case .add: return "add"
        case .intersect: return "intersect"
        case .subtract: return "subtract"
        case .exclude: return "exclude"
        }
    }

    var blendMode: MaskBlendMode {
        switch self {
        case .add: return .add
        case .intersect: return .multiply
        case .subtract: return .subtract
        case .exclude: return .exclude
        }
    }

    static func from(blendMode: MaskBlendMode) -> MaskCompositeOperation? {
        switch blendMode {
        case .add: return .add
        case .multiply: return .intersect
        case .subtract: return .subtract
        case .exclude: return .exclude
        case .mix, .replace: return nil
        }
    }
}

public struct MaskCompositeStep {
    public var name: String
    public var mask: MaskDescriptor
    var source: MaskSource?

    public init(name: String = "mask", mask: MaskDescriptor) {
        self.name = name
        self.mask = mask
        self.source = .descriptor(mask)
    }

    init(name: String, mask: MaskDescriptor, source: MaskSource?) {
        self.name = name
        self.mask = mask
        self.source = source
    }

    public var fingerprint: String {
        descriptor.fingerprint
    }

    public var descriptor: MaskCompositeStepDescriptor {
        let graphDescriptor = source?.graphDescriptor(
            component: mask.component,
            blendMode: mask.blendMode,
            invert: mask.invert,
            featherPolicy: mask.featherPolicy,
            opacity: mask.opacity
        )
        return MaskCompositeStepDescriptor(
            name: name,
            component: mask.component,
            blendMode: mask.blendMode,
            invert: mask.invert,
            opacity: mask.opacity,
            featherAmount: mask.featherPolicy.amount,
            gradient: graphDescriptor?.gradient,
            shape: graphDescriptor?.shape,
            path: graphDescriptor?.path
        )
    }

    public static func add(_ mask: MaskDescriptor, name: String = "add") -> MaskCompositeStep {
        step(for: .add, mask: mask, name: name)
    }

    public static func intersect(_ mask: MaskDescriptor, name: String = "intersect") -> MaskCompositeStep {
        step(for: .intersect, mask: mask, name: name)
    }

    public static func subtract(_ mask: MaskDescriptor, name: String = "subtract") -> MaskCompositeStep {
        step(for: .subtract, mask: mask, name: name)
    }

    public static func exclude(_ mask: MaskDescriptor, name: String = "exclude") -> MaskCompositeStep {
        step(for: .exclude, mask: mask, name: name)
    }

    public static func add<R: MaskRecipe>(_ recipe: R,
                                          component: MaskComponent = .red,
                                          invert: Bool = false,
                                          featherPolicy: MaskFeatherPolicy = .none,
                                          opacity: Float = 1.0,
                                          name: String = "add") throws -> MaskCompositeStep {
        try step(
            for: .add,
            recipe: recipe,
            component: component,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            name: name
        )
    }

    public static func intersect<R: MaskRecipe>(_ recipe: R,
                                                component: MaskComponent = .red,
                                                invert: Bool = false,
                                                featherPolicy: MaskFeatherPolicy = .none,
                                                opacity: Float = 1.0,
                                                name: String = "intersect") throws -> MaskCompositeStep {
        try step(
            for: .intersect,
            recipe: recipe,
            component: component,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            name: name
        )
    }

    public static func subtract<R: MaskRecipe>(_ recipe: R,
                                               component: MaskComponent = .red,
                                               invert: Bool = false,
                                               featherPolicy: MaskFeatherPolicy = .none,
                                               opacity: Float = 1.0,
                                               name: String = "subtract") throws -> MaskCompositeStep {
        try step(
            for: .subtract,
            recipe: recipe,
            component: component,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            name: name
        )
    }

    public static func exclude<R: MaskRecipe>(_ recipe: R,
                                              component: MaskComponent = .red,
                                              invert: Bool = false,
                                              featherPolicy: MaskFeatherPolicy = .none,
                                              opacity: Float = 1.0,
                                              name: String = "exclude") throws -> MaskCompositeStep {
        try step(
            for: .exclude,
            recipe: recipe,
            component: component,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            name: name
        )
    }

    private static func step(for operation: MaskCompositeOperation, mask: MaskDescriptor, name: String) -> MaskCompositeStep {
        var descriptor = mask
        descriptor.blendMode = operation.blendMode
        return MaskCompositeStep(name: name, mask: descriptor, source: .descriptor(descriptor))
    }

    private static func step<R: MaskRecipe>(for operation: MaskCompositeOperation,
                                            recipe: R,
                                            component: MaskComponent,
                                            invert: Bool,
                                            featherPolicy: MaskFeatherPolicy,
                                            opacity: Float,
                                            name: String) throws -> MaskCompositeStep {
        let source = AnyMaskRecipe(recipe)
        let mask = try source.makeMaskDescriptor(
            component: component,
            blendMode: operation.blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        return MaskCompositeStep(name: name, mask: mask, source: .recipe(source))
    }

    func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> MaskCompositeStep? {
        guard let operation = MaskCompositeOperation.from(blendMode: mask.blendMode),
              let rebasedSource = try source?.rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
              ) else {
            return nil
        }
        switch rebasedSource {
        case .descriptor(let descriptor):
            return Self.step(for: operation, mask: descriptor, name: name)
        case .recipe(let recipe):
            let rebasedMask = try recipe.makeMaskDescriptor(
                component: mask.component,
                blendMode: operation.blendMode,
                invert: mask.invert,
                featherPolicy: mask.featherPolicy,
                opacity: mask.opacity
            )
            return MaskCompositeStep(name: name, mask: rebasedMask, source: .recipe(recipe))
        }
    }
}
