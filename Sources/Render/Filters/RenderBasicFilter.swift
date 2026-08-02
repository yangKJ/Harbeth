//
//  RenderBasicFilter.swift
//  Harbeth
//
//  Created by Condy on 2024/3/23.
//

import Foundation
import MetalKit

/// 基本渲染滤镜
public struct RenderBasicFilter: RenderProtocol {
    public var factors: [Float] = []
    
    public var modifier: ModifierEnum {
        return .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .runtimeBound
    }
    
    public init() { }
    
    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        return nil
    }
}
