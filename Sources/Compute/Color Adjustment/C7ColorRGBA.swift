//
//  C7ColorRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7ColorRGBA: C7FilterProtocol {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Transparent colors are not processed, Will directly modify the overall color scheme
    public var color: C7Color = .white
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorRGBA")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector4.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index)
    }
    
    public init(color: C7Color = .white, intensity: Float = 1.0) {
        self.color = color
        self.intensity = intensity
    }
    
    public init(hex: Int, alpha: CGFloat = 1.0, intensity: Float = 1.0) {
        self.init(color: C7Color(hex: hex, alpha: alpha), intensity: intensity)
    }
    
    public init(hexString: String, intensity: Float = 1.0) {
        self.init(color: C7Color(hex: hexString), intensity: intensity)
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
}
