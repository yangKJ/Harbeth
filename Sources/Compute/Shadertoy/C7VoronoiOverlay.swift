//
//  C7VoronoiOverlay.swift
//  Harbeth
//
//  Created by Condy on 2022/3/1.
//

import Foundation

/// 泰森多边形法叠加效果
/// 改变`Voronoi`模式中的距离度量以获得不同的形状
public struct C7VoronoiOverlay: C7FilterProtocol {
    
    public var time: Float = 0.5
    public var alpha: Float = 0.05
    public var iResolution: C7Point2D = C7Point2D.center
    
    public var modifier: Modifier {
        return .compute(kernel: "C7VoronoiOverlay")
    }
    
    public var factors: [Float] {
        return [time, alpha, iResolution.x, iResolution.y]
    }
    
    public init(time: Float = 0.5, alpha: Float = 0.05) {
        self.time = time
        self.alpha = alpha
    }
}
