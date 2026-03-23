//
//  RenderGrayscale.swift
//  Harbeth
//
//  Created by Condy on 2026/3/23.
//

import Foundation
import MetalKit

/// 灰度渲染滤镜
public struct RenderGrayscale: RenderProtocol {
    
    public var modifier: ModifierEnum {
        return .render(vertex: "basicVertex", fragment: "grayscaleFragment")
    }
    
    public init() { }
    
    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        return nil
    }
}
