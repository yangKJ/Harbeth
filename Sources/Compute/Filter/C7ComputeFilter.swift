//
//  C7ComputeFilter.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

public enum ComputeFilterType: String {
    ///` rgba -> bgra
    case colorSwizzle = "ColorSwizzle"
    ///` 1 - rgb
    case colorInvert = "ColorInvert"
}

public struct C7ComputeFilter: C7FilterProtocol {
    
    private let filterType: ComputeFilterType
    
    public var modifier: Modifier {
        return .compute(kernel: filterType.rawValue)
    }
    
    public init(with type: ComputeFilterType) {
        self.filterType = type
    }
}
