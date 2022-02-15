//
//  C7FilterProtocol.swift
//  Pods
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit

public typealias MTQInputTextures = [MTLTexture]
public typealias MTQSize = (width: Int, height: Int)

public enum Modifier {
    /// 基于并行计算编码器，可直接生成图片
    /// Based on parallel computing encoder, Pictures can be generated directly.
    case compute(kernel: String)
    /// 基于渲染 3D 编码器，需配合`MTKView`方能显示
    /// Render based 3D encoder, Need to cooperate with MTKView to display.
    case render(vertex: String, fragment: String)
}

public protocol C7FilterProtocol {
    
    /// Encoder type and corresponding function name
    ///
    /// Compute requires the corresponding `kernel` function name
    /// Render requires a `vertex` shader function name and a `fragment` shader function name
    var modifier: Modifier { get }
    
    /// MakeBuffer
    /// Set modify parameter factor, you need to convert to `Float`.
    var factors: [Float] { get }
    
    /// Multiple input source extensions
    /// An array containing the `MTLTexture`
    var otherInputTextures: MTQInputTextures { get }
    
    /// Change the size of the output image
    func outputSize(input size: MTQSize) -> MTQSize
}

extension C7FilterProtocol {
    public var factors: [Float] {
        return []
    }
    public var otherInputTextures: MTQInputTextures {
        return []
    }
    public func outputSize(input size: MTQSize) -> MTQSize {
        return size
    }
}
