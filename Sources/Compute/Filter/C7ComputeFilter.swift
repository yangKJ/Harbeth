//
//  C7ComputeFilter.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

public enum ComputeFilterType: String, CaseIterable {
    ///` rgba -> bgra
    case colorSwizzle = "C7ColorSwizzle"
    ///` 1 - rgb
    case colorInvert = "C7ColorInvert"
    case colorToGray = "C7ColorToGray"
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
