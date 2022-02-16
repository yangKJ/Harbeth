//
//  C7Color2.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

public enum C7Color2Type: String, CaseIterable {
    case colorInvert = "C7ColorInvert" // 1-rgb
    case color2Gray = "C7Color2Gray"
    case color2BGRA = "C7Color2BGRA"
    case color2BRGA = "C7Color2BRGA"
    case color2GBRA = "C7Color2GBRA"
    case color2GRBA = "C7Color2GRBA"
    case color2RBGA = "C7Color2RBGA"
}

public struct C7Color2: C7FilterProtocol {
    
    private let type: C7Color2Type
    
    public var modifier: Modifier {
        return .compute(kernel: type.rawValue)
    }
    
    public init(with type: C7Color2Type) {
        self.type = type
    }
}
