import Foundation

/// XOR混合滤镜，用于实现奇显偶不显效果
/// XOR hybrid filter is used to achieve the effect of odd and even.
public struct C7XORBlendWithMask: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7XORBlendWithMask")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return [foregroundTexture, maskTexture]
    }
    
    private let foregroundTexture: MTLTexture
    private let maskTexture: MTLTexture
    
    public init(foregroundTexture: MTLTexture, maskTexture: MTLTexture) {
        self.foregroundTexture = foregroundTexture
        self.maskTexture = maskTexture
    }
    
    public mutating func updateIntensity(_ value: Float) {
        self.intensity = value
    }
}
