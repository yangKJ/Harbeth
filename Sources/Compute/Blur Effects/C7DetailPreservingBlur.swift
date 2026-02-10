//
//  C7DetailPreservingBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 在降噪的同时尽可能保留细节，避免传统模糊导致的细节丢失
/// Keep the details as much as possible
/// while reducing noise to avoid the loss of details caused by traditional blur.
public struct C7DetailPreservingBlur: C7FilterProtocol {
    
    @ZeroOneRange public var strength: Float
    
    @ZeroOneRange public var detailPreservation: Float = 0.7
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7DetailPreservingBlur")
    }
    
    public var factors: [Float] {
        return [strength, detailPreservation]
    }
    
    public init(strength: Float, detailPreservation: Float = 0.7) {
        self.strength = strength
        self.detailPreservation = detailPreservation
    }
}
