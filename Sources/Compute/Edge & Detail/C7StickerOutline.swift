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
    
    public var factors: [Float] {
        return [outlineThickness, outlineBlur]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector4.init(color: outlineColor).to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index)
    }
    
    public init(outlineColor: C7Color = C7Color.black, outlineThickness: Float = 0.02, outlineBlur: Float = 0.1) {
        self.outlineColor = outlineColor
        self.outlineThickness = outlineThickness
        self.outlineBlur = outlineBlur
    }
}
