//
//  MaskGradientRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import Metal

/// 参数化渐变遮罩。
///
/// 这层能力只负责把常见局部渐变选择沉成普通 texture：
/// - 线性渐变：`startPoint` 为 0 coverage，`endPoint` 为 1 coverage
/// - 径向渐变：`startRadius` 内为 1 coverage，`endRadius` 外为 0 coverage
/// - 输出仍是普通 `MaskDescriptor`，不引入重型 editor state
public struct MaskGradientRecipe {
    public var size: C7Size
    public var kind: MaskGradientKind
    public var profile: RenderProfile

    public init(size: C7Size, kind: MaskGradientKind, profile: RenderProfile = .stablePreview) {
        self.size = size
        self.kind = kind
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            kind.fingerprint,
            "profile=\(profile.rawValue)"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        graphDescriptor()
    }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskGradientRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: gradientDescriptor,
            shape: nil,
            path: nil
        )
    }

    public var gradientDescriptor: MaskGradientDescriptor {
        switch kind {
        case .linear(let startPoint, let endPoint):
            return MaskGradientDescriptor(
                kind: "linear",
                fingerprint: fingerprint,
                parameterValues: [
                    "startX=\(Self.stableFloatDescription(Float(startPoint.x)))",
                    "startY=\(Self.stableFloatDescription(Float(startPoint.y)))",
                    "endX=\(Self.stableFloatDescription(Float(endPoint.x)))",
                    "endY=\(Self.stableFloatDescription(Float(endPoint.y)))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .radial(let center, let startRadius, let endRadius):
            return MaskGradientDescriptor(
                kind: "radial",
                fingerprint: fingerprint,
                parameterValues: [
                    "centerX=\(Self.stableFloatDescription(Float(center.x)))",
                    "centerY=\(Self.stableFloatDescription(Float(center.y)))",
                    "startRadius=\(Self.stableFloatDescription(startRadius))",
                    "endRadius=\(Self.stableFloatDescription(endRadius))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        }
    }

    public func makeTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        let seed = try TextureLoader.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            options: [TextureLoader.Option.texturePixelFormat: pixelFormat],
            identifier: "MaskGradientRecipe"
        )
        return try HarbethIO(
            element: seed,
            filter: GradientMask(kind: kind)
        )
        .configured(for: profile)
        .output()
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0) throws -> MaskDescriptor {
        try makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: .rgba8Unorm
        )
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0,
                                   pixelFormat: MTLPixelFormat) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(pixelFormat: pixelFormat),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    static func stableFloatDescription(_ value: Float) -> String {
        GradientMask.stableFloatDescription(value)
    }
}
