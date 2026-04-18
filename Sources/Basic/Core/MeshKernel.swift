//
//  MeshKernel.swift
//  Harbeth
//
//  Created by Condy on 2026/4/18.
//

import Foundation
import MetalKit

// MARK: - MeshKernelProtocol Default Implementation
extension MeshKernelProtocol {
    
    /// Default encode implementation using Compute Shader pipeline.
    /// Subclasses only need to provide the kernel name via modifier and factors array.
    ///
    /// This default implementation:
    /// 1. Validates texture count
    /// 2. Creates or retrieves cached pipeline state
    /// 3. Sets up textures and parameters
    /// 4. Dispatches threadgroups
    ///
    /// For true Metal 3 Mesh Shader support, override this method and use
    /// MTLRenderPipelineDescriptor with object/mesh functions instead.
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard textures.count >= 2 else {
            throw HarbethError.filterParameterInvalid("textures count must be >= 2")
        }
        let outputTexture = textures[0]
        let inputTexture  = textures[1]
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        
        // Extract kernel name from modifier
        let kernelName = extractKernelName(from: modifier)
        
        // Get or create pipeline state
        let pipelineState = try pipelineState(for: kernelName)
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)
        
        // Set up custom mesh parameters
        setupMeshParameters(for: encoder, textures: textures)
        
        // Set factor parameters
        let filterFactors = self.factors
        for (index, factor) in filterFactors.enumerated() {
            var f = factor
            encoder.setBytes(&f, length: MemoryLayout<Float>.size, index: index)
        }
        
        // Calculate optimal threadgroup size
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (outputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (outputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        return outputTexture
    }
    
    /// Default setup implementation - empty.
    /// Override in subclass if custom parameter setup is needed.
    public func setupMeshParameters(for encoder: MTLCommandEncoder, textures: [MTLTexture]) {
        // Override in subclass for custom setup
    }
    
    // MARK: - Private Helpers
    
    /// Extract kernel name from modifier
    private func extractKernelName(from modifier: ModifierEnum) -> String {
        switch modifier {
        case .mesh(let function):
            return function
        case .compute(let kernel):
            return kernel
        default:
            return "UnknownKernel"
        }
    }
    
    /// Get or create compute pipeline state with caching
    private func pipelineState(for kernelName: String) throws -> MTLComputePipelineState {
        guard let device = Shared.shared.device else {
            throw HarbethError.deviceNotAvailable
        }
        
        // Check cache first
        if let cached = device.pipelineState(for: kernelName) {
            return cached
        }
        
        // Create new pipeline
        let function = try Device.readMTLFunction(kernelName)
        let pipeline = try device.device.makeComputePipelineState(function: function)
        
        device.setPipelineState(pipeline, for: kernelName)
        return pipeline
    }
}
