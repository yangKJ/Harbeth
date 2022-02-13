//
//  C7FilterProtocol.swift
//  Pods
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import UIKit

public typealias MTQImage = UIImage
public typealias MTQInputTextures = [MTLTexture]

public enum Modifier {
    /// 基于并行计算编码器，可直接生成图片
    /// Based on parallel computing encoder, Pictures can be generated directly.
    case compute(kernel: String)
    /// 基于渲染 3D 编码器，需配合`MTKView`方能显示
    /// Render based 3D encoder, Need to cooperate with MTKView to display.
    case render(vertex: String, fragment: String)
}

public protocol C7FilterProtocol {
    
    var modifier: Modifier { get }
    
    var factors: [Float] { get }
    
    var otherInputTextures: MTQInputTextures { get }
}

extension C7FilterProtocol {
    public var factors: [Float] {
        return []
    }
    public var otherInputTextures: MTQInputTextures {
        return []
    }
}
