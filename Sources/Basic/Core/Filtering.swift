//
//  Filtering.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit
import CoreImage

public protocol C7FilterProtocol: Mirrorable {
    
    var identifier: String { get }
    
    /// Encoder type and corresponding function name.
    var modifier: ModifierEnum { get }
    
    /// The supports a maximum of 16 `Float` parameters.
    var factors: [Float] { get }
    
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    var otherInputTextures: C7InputTextures { get }
    
    /// Do you need the total number of pixels factor,
    /// before the special factor and after the factors.
    var hasCount: Bool { get }
    
    /// The resize of the output texture.
    func resize(input size: C7Size) -> C7Size
    
    /// Special type of parameter factor, such as 4x4 matrix
    /// It is recommended to pass the parameters directly. Don't use this function if you have to.
    ///
    /// - Parameters:
    ///   - encoder: encoder, can be parallel computation encoder, can also be render 3D encoder
    ///   - index: Current parameter factor, after use please directly add, Please refer to the `C7ColorMatrix4x4`
    func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int)
    
    /// If you need to replace the subsequent input source texture, return to a new texture with copied to dest.
    /// - Parameters:
    ///   - buffer: A valid MTLCommandBuffer to receive the encoded filter.
    ///   - texture: Original input texture.
    ///   - texture2: The final output texture, This parameter is mainly provided for copied new textures to use.
    /// - Returns: A new texture with copied to dest.
    func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture
    
    /// Combination output metal texture, support `compute`, `render` and `mps` type.
    /// - Parameters:
    ///   - buffer: A valid MTLCommandBuffer to receive the encoded filter.
    ///   - texture: The output metal texture of the first filter.
    ///   - texture2: Original input texture.
    /// - Returns: Metal texture after combined filter treatment.
    func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture
}

extension C7FilterProtocol {
    public var identifier: String {
        let typeName = String(describing: type(of: self))
        let factorsDes = factors.map { String(format: "%.4f", $0) }.joined(separator: ",")
        return "\(typeName)-\(factorsDes)-\(otherInputTextures.count)"
    }
    /// The supports a maximum of 16 `Float` parameters.
    public var factors: [Float] { [] }
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    public var otherInputTextures: C7InputTextures { [] }
    /// Do you need the total number of pixels factor.
    public var hasCount: Bool { false }
    /// The resize of the output texture.
    public func resize(input size: C7Size) -> C7Size { size }
    /// Special type of parameter factor, such as 4x4 matrix.
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) { }
    /// If you need to replace the subsequent input source texture, return to a new texture with copied to dest.
    public func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        return texture
    }
    /// Combination output metal texture, support `compute`, `render` and `mps` type.
    public func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture {
        return texture
    }
    /// Add the filter into the output texture with compute, render and mps filter.
    public func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        try apply(form: texture, to: destTexture, for: buffer, complete: nil)
    }
}

extension C7FilterProtocol {
    @discardableResult
    func apply(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer, complete: C7TextureResultBlock?) throws -> MTLTexture {
        /// Asynchronous apply at texture.
        if let complete = complete {
            switch self.modifier {
            case .compute(let kernel):
                let textures = [destTexture, texture] + self.otherInputTextures
                drawing(with: kernel, commandBuffer: buffer, textures: textures, complete: complete)
            case .render(let vertex, let fragment):
                let pipelineState = try Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
                Rendering.drawingProcess(pipelineState, commandBuffer: buffer, texture: texture, filter: self)
                complete(.success(destTexture))
            case .blit where self is BlitProtocol:
                let textures = [destTexture, texture] + self.otherInputTextures
                let blitTexture = try (self as! BlitProtocol).encode(commandBuffer: buffer, textures: textures)
                complete(.success(blitTexture))
            case .mps where self is MPSKernelProtocol:
                let textures = [destTexture, texture] + self.otherInputTextures
                let mpsTexture = try (self as! MPSKernelProtocol).encode(commandBuffer: buffer, textures: textures)
                complete(.success(mpsTexture))
            default:
                complete(.success(texture))
            }
            return destTexture
        }
        
        /// Sync apply at texture.
        switch self.modifier {
        case .compute(let kernel):
            let textures = [destTexture, texture] + self.otherInputTextures
            return try drawing(with: kernel, commandBuffer: buffer, textures: textures)
        case .render(let vertex, let fragment):
            let pipelineState = try Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
            Rendering.drawingProcess(pipelineState, commandBuffer: buffer, texture: texture, filter: self)
        case .blit where self is BlitProtocol:
            let textures = [destTexture, texture] + self.otherInputTextures
            return try (self as! BlitProtocol).encode(commandBuffer: buffer, textures: textures)
        case .mps where self is MPSKernelProtocol:
            let textures = [destTexture, texture] + self.otherInputTextures
            return try (self as! MPSKernelProtocol).encode(commandBuffer: buffer, textures: textures)
        default:
            break
        }
        return destTexture
    }
}

// MARK: - coreimage filter protocol
public protocol CoreImageProtocol: C7FilterProtocol {
    /// Put out the CIFilter instance in advance to avoid repeated generation
    /// when the filter is applied, which will affect the efficiency.
    var inputCIFilter: CIFilter? { get }
    
    /// Return a new image cropped to a rectangle.
    var croppedOutputImage: Bool { get }
    
    /// Series connection other filters and finally output to the main filter.
    /// - Parameters:
    ///   - filter: CoreImage CIFilter.
    ///   - ciImage: Input source
    /// - Returns: Output source
    func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage
}

extension CoreImageProtocol {
    
    public var inputCIFilter: CIFilter? { nil }
    
    public var croppedOutputImage: Bool { false }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        return ciImage
    }
}

// MARK: - render filter protocol
public protocol RenderProtocol: C7FilterProtocol {
    /// Setup the vertex shader parameters.
    /// - Parameter device: MTLDevice
    /// - Returns: Vertex uniform buffer.
    func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer?
}

// MARK: - mps filter protocol
public protocol MPSKernelProtocol: C7FilterProtocol {
    /// Encode a MPSKernel into a command buffer. The operation shall proceed out-of-place.
    /// - Parameters:
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    ///   - textures: Texture array, The first is the output texture, the second is the input texture, and other input textures.
    /// - Returns: Return output metal texture.
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture
}

// MARK: - blit filter protocol
public protocol BlitProtocol: C7FilterProtocol {
    /// Encode a blit operation into a command buffer.
    /// - Parameters:
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    ///   - sourceTexture: Input source texture.
    ///   - destTexture: Output destination texture.
    /// - Returns: Return output metal texture.
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture
}
