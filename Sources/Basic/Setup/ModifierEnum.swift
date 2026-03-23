//
//  ModifierEnum.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

///`Metal`官网文档
/// https://developer.apple.com/documentation/metal
/// MPSCnn See: https://developer.apple.com/documentation/metalperformanceshaders/mpscnnconvolution
///

import Foundation
import MetalKit
import CoreImage
import MetalPerformanceShaders

@available(*, deprecated, message: "Typo. Use `ModifierEnum` instead", renamed: "ModifierEnum")
public typealias Modifier = ModifierEnum

public enum ModifierEnum: Equatable, Hashable {
    /// 基于`MTLComputeCommandEncoder`并行计算编码器，可直接生成图片
    /// Based on parallel computing encoder, Pictures can be generated directly.
    case compute(kernel: String)
    /// 基于`MTLRenderCommandEncoder`渲染 3D 编码器，需配合`MTKView`方能显示
    /// Render based 3D encoder, Need to cooperate with MTKView to display.
    case render(vertex: String, fragment: String)
    /// 基于`MTLBlitCommandEncoder`位图复制编码器，拷贝纹理同时也能生成贴图
    /// Based on bitmap copy encoder, copy buffer textures and generate mipmap.
    case blit
    /// 基于`CoreImage`，直接生成图片
    /// Based on CoreImage, directly generate images
    /// - Parameter CIName: CoreImage CIFilter Name.
    case coreimage(CIName: String)
    /// 基于`MetalPerformanceShaders`着色器
    /// Based on the MetalPerformanceShaders shader.
    case mps(performance: MPSKernel)
    /// 基于`Metal`网格着色器
    /// Based on the Metal mesh shader.
    case mesh(function: String)
    
    public static func ==(lhs: ModifierEnum, rhs: ModifierEnum) -> Bool {
        switch (lhs, rhs) {
        case (.compute(let lhsKernel), .compute(let rhsKernel)):
            return lhsKernel == rhsKernel
        case (.render(let lhsVertex, let lhsFragment), .render(let rhsVertex, let rhsFragment)):
            return lhsVertex == rhsVertex && lhsFragment == rhsFragment
        case (.blit, .blit):
            return true
        case (.coreimage(let lhsName), .coreimage(let rhsName)):
            return lhsName == rhsName
        case (.mps(let lhsKernel), .mps(let rhsKernel)):
            return lhsKernel === rhsKernel
        case (.mesh(let lhsFunction), .mesh(let rhsFunction)):
            return lhsFunction == rhsFunction
        default:
            return false
        }
    }
    
    var isCoreImage: Bool {
        switch self {
        case .compute:
            return false
        case .render:
            return false
        case .blit:
            return false
        case .coreimage:
            return true
        case .mps:
            return false
        case .mesh:
            return false
        }
    }
    
    var name: String {
        switch self {
        case .compute(let kernel):
            return kernel
        case .render(let vertex, let fragment):
            return vertex + "_" + fragment
        case .blit:
            return UUID().uuidString
        case .coreimage(let CIName):
            return CIName
        case .mps(let performance):
            return performance.label ?? UUID().uuidString
        case .mesh(let function):
            return function
        }
    }
}
