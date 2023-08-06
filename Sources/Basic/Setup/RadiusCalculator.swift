//
//  RadiusCalculator.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation

public enum RadiusCalculator {
    
    public static func radius(_ value: Float, max: Float, rect: CGRect) -> Float {
        let base = Float(sqrt(pow(rect.width, 2) + pow(rect.height, 2)))
        return base / 20 * value / max
    }
}
