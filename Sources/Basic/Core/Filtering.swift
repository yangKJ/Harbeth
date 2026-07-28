//
//  Filtering.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit

/// Memory access pattern for compute shaders
public enum MemoryAccessPattern {
    case point         // Point access (e.g., Brightness)
    case neighborhood  // Neighborhood access (e.g., GaussianBlur)
    case dualTexture   // Dual texture access (e.g., Blend)
    case multiTexture  // Multi-texture access (e.g., Combination)
    case auto          // Auto detection
}

public protocol C7FilterProtocol: Mirrorable {
    
    var identifier: String { get }
    
    /// Encoder type and corresponding function name.
    var modifier: ModifierEnum { get }
    
    /// Lightweight Float-only parameter route.
    ///
    /// Filters that expose `kernelParameterBindings` use those bindings for
    /// encoding and descriptor fingerprints. Keep `factors` available for
    /// lightweight filters and source compatibility.
    var factors: [Float] { get }
    
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    var otherInputTextures: C7InputTextures { get }

    /// Explicit shader parameter bindings for compute/render encoders.
    var kernelParameterBindings: [KernelParameterBinding] { get }
    
    /// Memory access pattern for threadgroup optimization
    var memoryAccessPattern: MemoryAccessPattern { get }

    /// Kernel's pixel, dynamic range and area execution contract.
    var kernelPixelContract: KernelPixelContract { get }

    /// Execution identity for immutable lookup textures or other external resources.
    var kernelResourceIdentity: String? { get }
    
    /// The resize of the output texture.
    func resize(input size: C7Size) -> C7Size
    
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
        if let pipelineFilter = self as? C7FilterPipelineProtocol {
            let typeName = String(describing: type(of: self))
            return "\(typeName)-pipeline-\(pipelineFilter.recipeDescriptor.fingerprint)"
        }
        let typeName = String(describing: type(of: self))
        return "\(typeName)-\(kernelParameterFingerprint)-\(kernelResourceIdentity ?? "inputs=\(otherInputTextures.count)")"
    }
    /// Lightweight Float-only parameter route.
    public var factors: [Float] { [] }
    /// Multiple input source extensions, an array containing the `MTLTexture`.
    public var otherInputTextures: C7InputTextures { [] }
    public var kernelResourceIdentity: String? {
        guard otherInputTextures.isEmpty == false else { return nil }
        return otherInputTextures.map { texture in
            "texture=\(ObjectIdentifier(texture).hashValue)|\(texture.width)x\(texture.height)x\(texture.depth)|\(texture.pixelFormat.rawValue)"
        }.joined(separator: "||")
    }
    /// Explicit shader parameter bindings for compute/render encoders.
    public var kernelParameterBindings: [KernelParameterBinding] { [] }
    /// Memory access pattern for threadgroup optimization
    public var memoryAccessPattern: MemoryAccessPattern { .auto }
    /// The resize of the output texture.
    public func resize(input size: C7Size) -> C7Size { size }
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
    var kernelParameterFingerprint: String {
        if let pipelineFilter = self as? C7FilterPipelineProtocol {
            return pipelineFilter.recipeDescriptor.fingerprint
        }
        let bindings = kernelParameterBindings
        if bindings.isEmpty {
            return factors.map { String(format: "%.4f", $0) }.joined(separator: ",")
        }
        return bindings.sorted { lhs, rhs in
            if lhs.index == rhs.index {
                if lhs.stage == rhs.stage {
                    return lhs.name < rhs.name
                }
                return lhs.stage.rawValue < rhs.stage.rawValue
            }
            return lhs.index < rhs.index
        }.map(\.fingerprint).joined(separator: "||")
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
                Compute.drawing(with: kernel, commandBuffer: buffer, textures: textures, filter: self, complete: complete)
            case .render(let vertex, let fragment):
                let pipelineState = try Rendering.makeRenderPipelineState(
                    with: vertex,
                    fragment: fragment,
                    pixelFormat: destTexture.pixelFormat
                )
                try Rendering.drawing(
                    pipelineState,
                    commandBuffer: buffer,
                    texture: texture,
                    destTexture: destTexture,
                    filter: self
                )
                complete(.success(destTexture))
            case .blit:
                let textures = [destTexture, texture] + self.otherInputTextures
                guard let filter = self as? BlitProtocol else {
                    throw HarbethError.filterError(
                        name: String(describing: type(of: self)),
                        reason: "Blit modifier requires BlitProtocol."
                    )
                }
                let blitTexture = try filter.encode(commandBuffer: buffer, textures: textures)
                complete(.success(blitTexture))
            case .mps:
                let textures = [destTexture, texture] + self.otherInputTextures
                guard let filter = self as? MPSKernelProtocol else {
                    throw HarbethError.filterError(
                        name: String(describing: type(of: self)),
                        reason: "MPS modifier requires MPSKernelProtocol."
                    )
                }
                let mpsTexture = try filter.encode(commandBuffer: buffer, textures: textures)
                complete(.success(mpsTexture))
            case .advancedMetal:
                let textures = [destTexture, texture] + self.otherInputTextures
                guard let filter = self as? C7AdvancedMetalKernelProtocol else {
                    throw HarbethError.filterError(
                        name: String(describing: type(of: self)),
                        reason: "Advanced Metal modifier requires C7AdvancedMetalKernelProtocol."
                    )
                }
                let advancedTexture = try filter.encode(commandBuffer: buffer, textures: textures)
                complete(.success(advancedTexture))
            }
            return destTexture
        }
        /// Sync apply at texture.
        switch self.modifier {
        case .compute(let kernel):
            let textures = [destTexture, texture] + self.otherInputTextures
            return try Compute.drawing(with: kernel, commandBuffer: buffer, textures: textures, filter: self)
        case .render(let vertex, let fragment):
            let pipelineState = try Rendering.makeRenderPipelineState(
                with: vertex,
                fragment: fragment,
                pixelFormat: destTexture.pixelFormat
            )
            try Rendering.drawing(
                pipelineState,
                commandBuffer: buffer,
                texture: texture,
                destTexture: destTexture,
                filter: self
            )
        case .blit:
            let textures = [destTexture, texture] + self.otherInputTextures
            guard let filter = self as? BlitProtocol else {
                throw HarbethError.filterError(
                    name: String(describing: type(of: self)),
                    reason: "Blit modifier requires BlitProtocol."
                )
            }
            return try filter.encode(commandBuffer: buffer, textures: textures)
        case .mps:
            let textures = [destTexture, texture] + self.otherInputTextures
            guard let filter = self as? MPSKernelProtocol else {
                throw HarbethError.filterError(
                    name: String(describing: type(of: self)),
                    reason: "MPS modifier requires MPSKernelProtocol."
                )
            }
            return try filter.encode(commandBuffer: buffer, textures: textures)
        case .advancedMetal:
            let textures = [destTexture, texture] + self.otherInputTextures
            guard let filter = self as? C7AdvancedMetalKernelProtocol else {
                throw HarbethError.filterError(
                    name: String(describing: type(of: self)),
                    reason: "Advanced Metal modifier requires C7AdvancedMetalKernelProtocol."
                )
            }
            return try filter.encode(commandBuffer: buffer, textures: textures)
        }
        return destTexture
    }
}

// MARK: - render filter protocol
public protocol RenderProtocol: C7FilterProtocol {
    /// Setup the vertex shader parameters.
    /// - Parameter device: MTLDevice
    /// - Returns: Vertex uniform buffer.
    func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer?

    /// Setup the fragment shader parameters that depend on the input size.
    /// - Parameters:
    ///   - device: MTLDevice
    ///   - inputSize: Input texture size.
    /// - Returns: Fragment uniform buffer.
    func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer?

    /// Override the default fullscreen quad when a render filter needs
    /// custom geometry, e.g. 3D/projective transforms.
    func setupVertices(inputSize: C7Size) -> [Float]?

    /// Number of floats for each vertex in the custom vertex buffer.
    var renderVertexStride: Int { get }

    /// Render-target quality contract for the primary and auxiliary color attachments.
    var renderOutputContract: RenderOutputContract { get }

    /// Optional runtime sampler override for render-based filters.
    ///
    /// Most historical filters continue to use their own inline sampling rules.
    /// Node-level sampler overrides can bridge through this property on the
    /// render paths that actually bind a Metal sampler state.
    var renderSamplerDescriptor: ImageSamplerDescriptor { get }
}

extension RenderProtocol {
    public func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? { nil }
    public func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? { nil }
    public func setupVertices(inputSize: C7Size) -> [Float]? { nil }
    public var renderVertexStride: Int { 4 }
    public var renderOutputContract: RenderOutputContract { .preserveInput }
    public var renderSamplerDescriptor: ImageSamplerDescriptor { .default }
}

/// Narrow sampler bridge for filters that can translate an image sampler
/// descriptor into their own execution parameters.
public protocol SamplerAdaptableFilter: C7FilterProtocol {
    func samplerAdaptation(for descriptor: ImageSamplerDescriptor) -> SamplerAdaptation
}

/// Result of attempting to apply a sampler descriptor to a filter.
public enum SamplerAdaptation {
    case covered(any C7FilterProtocol)
    case metadataOnly
    case notApplicable
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
    ///   - textures: Texture array. The first texture is the output and the second is the input.
    /// - Returns: Return output metal texture.
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture
}
