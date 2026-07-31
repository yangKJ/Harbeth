//
//  LayerCompositeFilter.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import CoreGraphics
import Metal

struct LayerComposite: C7FilterProtocol {
    let layerTexture: MTLTexture
    let mask: MaskDescriptor?
    let compositingMask: MaskDescriptor?
    let normalizedFrame: CGRect
    let contentRegion: CGRect
    let opacity: Float
    let blendMode: LayerBlendMode
    let cornerRadius: Float
    let cornerCurve: LayerCornerCurve
    let tintColor: SIMD4<Float>?

    init(layerTexture: MTLTexture,
         mask: MaskDescriptor? = nil,
         compositingMask: MaskDescriptor? = nil,
         normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
         contentRegion: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
         opacity: Float = 1,
         blendMode: LayerBlendMode = .sourceOver,
         cornerRadius: Float = 0,
         cornerCurve: LayerCornerCurve = .circular,
         tintColor: SIMD4<Float>? = nil) {
        self.layerTexture = layerTexture
        self.mask = mask
        self.compositingMask = compositingMask
        self.normalizedFrame = normalizedFrame.standardized
        self.contentRegion = contentRegion.standardized
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.cornerRadius = max(cornerRadius, 0)
        self.cornerCurve = cornerCurve
        self.tintColor = tintColor
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerLayerComposite")
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        let frame = SIMD4<Float>(
            Float(normalizedFrame.origin.x), Float(normalizedFrame.origin.y),
            Float(normalizedFrame.size.width), Float(normalizedFrame.size.height)
        )
        let region = SIMD4<Float>(
            Float(contentRegion.origin.x), Float(contentRegion.origin.y),
            Float(contentRegion.size.width), Float(contentRegion.size.height)
        )
        let maskOptions = SIMD4<Float>(
            mask == nil ? 0 : 1,
            Float(mask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            Float(mask?.blendMode.rawValue ?? MaskBlendMode.mix.rawValue),
            mask?.invert == true ? 1 : 0
        )
        let compositingMaskOptions = SIMD4<Float>(
            compositingMask == nil ? 0 : 1,
            Float(compositingMask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            Float(compositingMask?.blendMode.rawValue ?? MaskBlendMode.mix.rawValue),
            compositingMask?.invert == true ? 1 : 0
        )
        return [
            KernelParameterBinding(name: "normalizedFrame", index: 0, stage: .compute, value: .float4(frame)),
            KernelParameterBinding(name: "contentRegion", index: 1, stage: .compute, value: .float4(region)),
            KernelParameterBinding(
                name: "layerOptions",
                index: 2,
                stage: .compute,
                value: .float4(SIMD4<Float>(opacity, Float(blendMode.rawValue), cornerRadius, cornerCurve == .continuous ? 1 : 0))
            ),
            KernelParameterBinding(name: "maskOptions", index: 3, stage: .compute, value: .float4(maskOptions)),
            KernelParameterBinding(
                name: "maskCoverage",
                index: 4,
                stage: .compute,
                value: .float2(SIMD2<Float>(mask?.opacity ?? 1, mask?.featherPolicy.amount ?? 0))
            ),
            KernelParameterBinding(
                name: "compositingMaskOptions",
                index: 5,
                stage: .compute,
                value: .float4(compositingMaskOptions)
            ),
            KernelParameterBinding(
                name: "compositingMaskCoverage",
                index: 6,
                stage: .compute,
                value: .float2(SIMD2<Float>(compositingMask?.opacity ?? 1, compositingMask?.featherPolicy.amount ?? 0))
            ),
            KernelParameterBinding(name: "tintColor", index: 7, stage: .compute, value: .float4(tintColor ?? .zero)),
            KernelParameterBinding(name: "hasTint", index: 8, stage: .compute, value: .bool(tintColor != nil))
        ]
    }

    var otherInputTextures: C7InputTextures {
        [
            layerTexture,
            mask?.texture ?? layerTexture,
            compositingMask?.texture ?? layerTexture
        ]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}
