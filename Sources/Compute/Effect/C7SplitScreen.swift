//
//  C7SplitScreen.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

public struct C7SplitScreen: C7FilterProtocol {

    public enum SSType: Int {
        case two = 2
        case three = 3
    }
    
    public var type: SSType = .two
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SplitScreen")
    }
    
    public var factors: [Float] {
        return [Float(type.rawValue)]
    }
    
    public init(type: C7SplitScreen.SSType = .two) {
        self.type = type
    }
}
