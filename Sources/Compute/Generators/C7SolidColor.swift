//
//  C7SolidColor.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

/// 纯色滤镜
public struct C7SolidColor: C7FilterProtocol {
    
    /// There is no need to create a new output texture, just use the input texture.
    public var needCreateDestTexture: Bool = false

    public var destinationTextureContract: FilterDestinationTextureContract {
        .init(aliasingPolicy: .inPlaceAllowed)
    }
    
    public var color: C7Color = .white
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7SolidColor")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "color", index: 0, stage: .compute, value: .float4(premultipliedColor))
        ]
    }
    
    private var premultipliedColor: SIMD4<Float> {
        var value = color.c7.toSIMD4()
        value.x *= value.w; value.y *= value.w; value.z *= value.w
        return value
    }
    public var kernelPixelContract: KernelPixelContract {
        .init(outputAlpha: .premultiplied, precision: .float32, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .init(alpha: .premultiplied) }

    public init(color: C7Color = .white) {
        self.color = color
    }
}
