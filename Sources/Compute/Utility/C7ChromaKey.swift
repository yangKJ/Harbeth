//
//  C7ChromaKey.swift
//  Harbeth
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 祛除某种色系，有点类似绿幕抠图，被祛除的像素会变透明
/// Remove the background that has the specified a color. A bit like green screen matting, The removed pixels become transparent.
public struct C7ChromaKey: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.1)
    
    /// How close a color match needs to exist to the target color to be replaced, default of 0.4
    @ZeroOneRange public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match, default of 0.1
    @ZeroOneRange public var smoothing: Float = range.value
    /// Remove the background that has the specified a color. Remove green by default.
    public var chroma: C7Color = .green
    /// The color to be replaced in chroma color, subtract a color scheme and replace it later.
    /// If the alpha is 0, it will not be replaced.
    public var replace: C7Color = .zero
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ChromaKey")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    private var premultipliedReplacement: SIMD4<Float> {
        var value = replace.c7.toSIMD4()
        value.x *= value.w; value.y *= value.w; value.z *= value.w
        return value
    }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied, precision: .float32, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorOutput }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "thresholdSensitivity", index: 0, stage: .compute, value: .float(thresholdSensitivity.isFinite ? thresholdSensitivity : 0.4)),
            KernelParameterBinding(name: "smoothing", index: 1, stage: .compute, value: .float(smoothing.isFinite ? smoothing : 0.1)),
            KernelParameterBinding(name: "chroma", index: 2, stage: .compute, value: .float3(chroma.c7.toSIMD3())),
            KernelParameterBinding(name: "replace", index: 3, stage: .compute, value: .float4(premultipliedReplacement))
        ]
    }
    
    public init(thresholdSensitivity: Float = 0.4,
                smoothing: Float = range.value,
                chroma: C7Color = .green,
                replace: C7Color = .zero) {
        self.thresholdSensitivity = thresholdSensitivity
        self.smoothing = smoothing
        self.chroma = chroma
        self.replace = replace
    }
}
