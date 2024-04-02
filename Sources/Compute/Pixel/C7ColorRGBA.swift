//
//  C7ColorRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7ColorRGBA: C7FilterProtocol {
    
    /// Specifies the intensity of the operation.
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    /// Transparent colors are not processed, Will directly modify the overall color scheme
    public var color: C7Color = .white
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorRGBA")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector4.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index + 1)
    }
    
    public init(color: C7Color = .white) {
        self.color = color
    }
}
