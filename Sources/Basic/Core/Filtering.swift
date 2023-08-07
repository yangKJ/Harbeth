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
    case mps(performance: MPSKernel)
}

public protocol C7FilterProtocol: Mirrorable {
    
    /// Encoder type and corresponding function name.
    var modifier: Modifier { get }
    
    /// The supports a maximum of 16 `Float` parameters.
    var factors: [Float] { get }
    
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    var otherInputTextures: C7InputTextures { get }
    
    /// The resize of the output texture.
    func resize(input size: C7Size) -> C7Size
}

extension C7FilterProtocol {
    /// The supports a maximum of 16 `Float` parameters.
    public var factors: [Float] { [] }
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    public var otherInputTextures: C7InputTextures { [] }
    /// The resize of the output texture.
    public func resize(input size: C7Size) -> C7Size { size }
}

// MARK: - compute filter protocol
public protocol ComputeProtocol {
    /// Special type of parameter factor, such as 4x4 matrix
    /// It is recommended to pass the parameters directly. Don't use this function if you have to.
    ///
    /// - Parameters:
    ///   - encoder: encoder, can be parallel computation encoder, can also be render 3D encoder
    ///   - index: Current parameter factor, after use please directly add, Please refer to the `C7ColorMatrix4x4`
    func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int)
}

// MARK: - coreimage filter protocol
public protocol CoreImageProtocol {
    /// Compatible with CoreImage.
    /// - Parameters:
    ///   - filter: CoreImage CIFilter.
    ///   - ciImage: Input source
    /// - Returns: Output source
    func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage
}

// MARK: - render filter protocol
public protocol RenderProtocol {
    /// Setup the vertex shader parameters.
    /// - Parameter device: MTLDevice
    /// - Returns: Vertex uniform buffer.
    func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer?
}

// MARK: - msp filter protocol
public protocol MPSKernelProtocol {
    /// Encode a MPSKernel into a command buffer. The operation shall proceed out-of-place.
    /// - Parameters:
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    ///   - textures: Texture array, The first is the output texture, the second is the input texture, and other input textures.
    /// - Returns: Return output metal texture.
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) -> MTLTexture
}
