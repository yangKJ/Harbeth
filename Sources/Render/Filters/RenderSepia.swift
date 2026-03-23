//
//  RenderSepia.swift
//  Harbeth
//
//  Created by Condy on 2026/3/23.
//

import Foundation
import MetalKit

/// 棕褐色渲染滤镜
public struct RenderSepia: RenderProtocol {
    
    public var modifier: ModifierEnum {
        return .render(vertex: "basicVertex", fragment: "sepiaFragment")
    }
    
    public init() { }
    
    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        return nil
    }
}
