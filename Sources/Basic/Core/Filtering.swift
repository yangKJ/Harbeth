//
//  Filtering.swift
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

public enum Modifier {
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
    case mps(performance: MPSUnaryImageKernel)
}

public protocol C7FilterProtocol: Mirrorable {
    
    /// Encoder type and corresponding function name
    ///
    /// Compute requires the corresponding `kernel` function name
    /// Render requires a `vertex` shader function name and a `fragment` shader function name
    var modifier: Modifier { get }
    
    /// 最多只能支持16个参数，超过请使用`setupSpecialFactors`传值
    /// The MakeBuffer supports a maximum of 16 parameters.
    /// Set modify parameter factor, you need to convert to `Float`.
    var factors: [Float] { get }
    
    /// Multiple input source extensions
    /// An array containing the `MTLTexture`
    var otherInputTextures: C7InputTextures { get }
    
    /// Change the size of the output image
    func resize(input size: C7Size) -> C7Size
}

extension C7FilterProtocol {
    public var factors: [Float] { [] }
    public var otherInputTextures: C7InputTextures { [] }
    public func resize(input size: C7Size) -> C7Size { size }
}


public protocol ComputeFiltering {
    /// 特殊类型参数因子，例如4x4矩阵
    /// 这些参数是在`factors`之后传递进入
    /// 如果参数因子能够转成`Float`并且个数小于16建议直接使用`factors`传递
    /// 情非得已还是别用这个函数
    ///
    /// Special type of parameter factor, such as 4x4 matrix
    /// These parameters are passed in after `factors`
    /// If the parameters can be converted to `Float` and the number is less than 16.
    /// It is recommended to pass the parameters directly.
    /// don't use this function if you have to.
    ///
    /// - Parameters:
    ///   - encoder: 编码器，可以是并行计算编码器，也可以是渲染 3D 编码器
    ///   - index: 当前参数因子，后序使用请直接累加，请参考`C7ColorMatrix4x4`滤镜
    ///
    ///   - encoder: encoder, can be parallel computation encoder, can also be render 3D encoder
    ///   - index: Current parameter factor, after use please directly add, Please refer to the `C7ColorMatrix4x4`
    func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int)
}

public protocol CoreImageFiltering {
    /// CoreImage 滤镜专属方案
    ///
    /// - Parameters:
    ///   - filter: `CIFilter`
    ///   - ciImage: Input source
    /// - Returns: Output source
    func coreImageApply(filter: CIFilter?, input ciImage: CIImage) -> CIImage
}

public protocol RenderFiltering {
    /// Setup the vertex shader parameters.
    /// - Parameter device: MTLDevice
    /// - Returns: Vertex uniform buffer.
    func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer?
}
