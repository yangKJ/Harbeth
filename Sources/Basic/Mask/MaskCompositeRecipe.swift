//
//  MaskCompositeRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import Metal

public struct MaskCompositeRecipe {
    public var baseMask: MaskDescriptor
    public var steps: [MaskCompositeStep]
    public var profile: RenderProfile
    var baseSource: MaskSource?

    public init(baseMask: MaskDescriptor, masks: [MaskDescriptor] = [], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.steps = masks.enumerated().map { index, mask in
            MaskCompositeStep(name: "mask\(index)", mask: mask)
        }
        self.profile = profile
        self.baseSource = nil
    }

    public init(baseMask: MaskDescriptor, steps: [MaskCompositeStep], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.steps = steps
        self.profile = profile
        self.baseSource = nil
    }

    public init<R: MaskRecipe>(baseRecipe: R,
                               component: MaskComponent = .red,
                               blendMode: MaskBlendMode = .mix,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1.0,
                               steps: [MaskCompositeStep] = []) throws {
        let source = AnyMaskRecipe(baseRecipe)
        self.baseMask = try source.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.steps = steps
        self.profile = baseRecipe.profile
        self.baseSource = .recipe(source)
    }

    public var maskCount: Int {
        1 + steps.count
    }

    public var masks: [MaskDescriptor] {
        steps.map(\.mask)
    }

    public var baseGraphOverride: MaskGraphDescriptor? {
        baseSource?.graphDescriptor(
            component: baseMask.component,
            blendMode: baseMask.blendMode,
            invert: baseMask.invert,
            featherPolicy: baseMask.featherPolicy,
            opacity: baseMask.opacity
        )
    }

    public func adding(_ mask: MaskDescriptor, name: String = "add") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.add(mask, name: name))
        return copy
    }

    public func intersecting(_ mask: MaskDescriptor, name: String = "intersect") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.intersect(mask, name: name))
        return copy
    }

    public func subtracting(_ mask: MaskDescriptor, name: String = "subtract") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.subtract(mask, name: name))
        return copy
    }

    public func excluding(_ mask: MaskDescriptor, name: String = "exclude") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.exclude(mask, name: name))
        return copy
    }

    public func adding<R: MaskRecipe>(_ recipe: R,
                                      component: MaskComponent = .red,
                                      invert: Bool = false,
                                      featherPolicy: MaskFeatherPolicy = .none,
                                      opacity: Float = 1.0,
                                      name: String = "add") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .add(
                recipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func intersecting<R: MaskRecipe>(_ recipe: R,
                                            component: MaskComponent = .red,
                                            invert: Bool = false,
                                            featherPolicy: MaskFeatherPolicy = .none,
                                            opacity: Float = 1.0,
                                            name: String = "intersect") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .intersect(
                recipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func subtracting<R: MaskRecipe>(_ recipe: R,
                                           component: MaskComponent = .red,
                                           invert: Bool = false,
                                           featherPolicy: MaskFeatherPolicy = .none,
                                           opacity: Float = 1.0,
                                           name: String = "subtract") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .subtract(
                recipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func excluding<R: MaskRecipe>(_ recipe: R,
                                         component: MaskComponent = .red,
                                         invert: Bool = false,
                                         featherPolicy: MaskFeatherPolicy = .none,
                                         opacity: Float = 1.0,
                                         name: String = "exclude") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .exclude(
                recipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public var fingerprint: String {
        let baseSegment = [
            "base=1",
            "component=\(baseMask.component.rawValue)",
            "blend=\(baseMask.blendMode.rawValue)",
            "invert=\(baseMask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", baseMask.opacity))",
            "feather=\(baseMask.featherPolicy.amount)"
        ].joined(separator: ",")
        return [
            "profile=\(profile)",
            "base={\(baseSegment)}",
            "baseSource=\(baseGraphOverride?.fingerprint ?? "none")",
            "steps=\(steps.isEmpty ? "none" : steps.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        graphDescriptor(
            component: baseMask.component,
            blendMode: baseMask.blendMode,
            invert: baseMask.invert,
            featherPolicy: baseMask.featherPolicy,
            opacity: baseMask.opacity
        )
    }

    public func graphDescriptor(component: MaskComponent,
                                blendMode: MaskBlendMode,
                                invert: Bool,
                                featherPolicy: MaskFeatherPolicy,
                                opacity: Float) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskCompositeRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: opacity,
            featherAmount: featherPolicy.amount,
            stepCount: steps.count,
            steps: steps.map(\.descriptor),
            gradient: baseGraphOverride?.gradient,
            shape: baseGraphOverride?.shape,
            path: baseGraphOverride?.path
        )
    }

    public func makeTexture() throws -> MTLTexture {
        var current = try HarbethIO(
            element: baseMask.texture,
            filter: MaskCoverageExtract(mask: baseMask)
        )
        .configured(for: profile)
        .output()

        for step in steps {
            current = try HarbethIO(
                element: current,
                filter: MaskCoverageBlend(baseComponent: .red, mask: step.mask)
            )
            .configured(for: profile)
            .output()
        }
        return current
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    func rebasedSource(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe? {
        guard let rebased = try rebased(
            sourceRect: sourceRect,
            logicalSize: logicalSize,
            tileInputSize: tileInputSize
        ) else {
            return nil
        }
        return AnyMaskRecipe(rebased)
    }

    public func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> MaskCompositeRecipe? {
        guard let rebasedBaseSource = try baseSource?.rebased(
            sourceRect: sourceRect,
            logicalSize: logicalSize,
            tileInputSize: tileInputSize
        ) else {
            return nil
        }
        guard case .recipe(let baseRecipe) = rebasedBaseSource else {
            return nil
        }
        var rebasedRecipe = try MaskCompositeRecipe(
            baseRecipe: baseRecipe,
            component: baseMask.component,
            blendMode: baseMask.blendMode,
            invert: baseMask.invert,
            featherPolicy: baseMask.featherPolicy,
            opacity: baseMask.opacity,
            steps: []
        )
        for step in steps {
            guard let rebasedStep = try step.rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            ) else {
                return nil
            }
            rebasedRecipe.steps.append(rebasedStep)
        }
        return rebasedRecipe
    }
}
