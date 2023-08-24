//
//  C7SplitScreen.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

public struct C7SplitScreen: C7FilterProtocol {

    public enum ScreenType: Int {
        case two = 2
        case three = 3
    }
    
    public enum DirectionType: Int {
        case horizontal
        case vertical
    }
    
    public var type: ScreenType = .two
    
    public var direction: DirectionType = .vertical
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SplitScreen")
    }
    
    public var factors: [Float] {
        return [Float(type.rawValue), Float(direction.rawValue)]
    }
    
    public init(type: ScreenType = .two, direction: DirectionType = .vertical) {
        self.type = type
        self.direction = direction
    }
}
