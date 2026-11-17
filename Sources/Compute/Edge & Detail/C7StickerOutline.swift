import Foundation

/// 贴纸轮廓效果滤镜
/// Sticker outline effect filter
public struct C7StickerOutline: C7FilterProtocol {
    
    /// 轮廓颜色，默认为黑色
    public var outlineColor: C7Color = C7Color.black
    
    /// 轮廓厚度，范围0.0-0.1
    @Clamping(0.0...0.1) public var outlineThickness: Float = 0.02
    
    /// 轮廓模糊度，范围0.0-1.0
    @ZeroOneRange public var outlineBlur: Float = 0.1
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7StickerOutline")
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied, precision: .float32, samplingFootprint: .dynamic)
    }
    public var kernelOutputContract: RenderOutputContract { .init(alpha: .premultiplied) }

    private var premultipliedColor: SIMD4<Float> {
        var value = outlineColor.c7.toSIMD4()
        value.x *= value.w; value.y *= value.w; value.z *= value.w
        return value
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "outlineThickness", index: 0, stage: .compute, value: .float(outlineThickness.isFinite ? outlineThickness : 0)),
            KernelParameterBinding(name: "outlineBlur", index: 1, stage: .compute, value: .float(outlineBlur.isFinite ? outlineBlur : 0)),
            KernelParameterBinding(name: "outlineColor", index: 2, stage: .compute, value: .float4(premultipliedColor))
        ]
    }
    
    public init(outlineColor: C7Color = C7Color.black, outlineThickness: Float = 0.02, outlineBlur: Float = 0.1) {
        self.outlineColor = outlineColor
        self.outlineThickness = outlineThickness
        self.outlineBlur = outlineBlur
    }
}
