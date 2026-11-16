//
//  C7DetailEnhancer.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import Metal

/// 使用非锐化掩模技术增强图像细节，比普通锐化更自然
/// Use non-sharpening mask technology to enhance image details,
/// which is more natural than ordinary sharpening.
public struct C7DetailEnhancer: C7FilterProtocol {
    
    @Clamping(0...2.0) public var amount: Float = 0.0
    
    @Clamping(0.0...0.5) public var detailThreshold: Float = 0.05
    
    public var modifier: ModifierEnum {
        if #available(macOS 11.0, iOS 14.0, tvOS 16.0, *), HarbethContext.shared.device.supports32BitFloatFiltering {
            return .compute(kernel: "C7DetailEnhancerPacked")
        }
        return .compute(kernel: "C7DetailEnhancer")
    }
    
    public var factors: [Float] {
        return [amount, detailThreshold]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(amount: Float = 0.0, detailThreshold: Float = 0.05) {
        self.amount = amount
        self.detailThreshold = detailThreshold
    }
}
