//
//  Compute.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

/// 文档
/// https://colin19941.gitbooks.io/metal-programming-guide-zh/content/Data-Parallel_Compute_Processing_Compute_Command_Encoder.html

import Foundation
@preconcurrency import MetalKit

struct Compute {
    /// Create a parallel computation pipeline.
    /// Performance intensive operations should not be invoked frequently
    /// - parameter kernel: Specifies the name of the data parallel computing coloring function
    /// - Returns: MTLComputePipelineState
    @inlinable
    static func makeComputePipelineState(with kernel: String) throws -> MTLComputePipelineState {
        let context = HarbethContext.shared
        /// 先读取缓存管线
        if let pipelineState = context.computePipelineState(for: kernel) {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: true)
            return pipelineState
        }
        /// 同步阻塞编译计算程序来创建管道状态
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: kernel)
        guard let pipeline = try? context.makeComputePipelineState(identity: identity) else {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: false)
            throw HarbethError.computePipelineState(kernel)
        }
        context.setComputePipelineState(pipeline, for: kernel)
        HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: false)
        return pipeline
    }

    static func makeComputePipelineState(with identity: KernelFunctionIdentity) throws -> MTLComputePipelineState {
        let context = HarbethContext.shared
        if let pipelineState = context.computePipelineState(for: identity) {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: true)
            return pipelineState
        }
        guard let pipeline = try? context.makeComputePipelineState(identity: identity) else {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: false)
            throw HarbethError.computePipelineState(identity.primaryName)
        }
        context.setComputePipelineState(pipeline, for: identity)
        HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: false)
        return pipeline
    }
    
    @inlinable
    static func makeComputePipelineState(
        with kernel: String,
        complete: @escaping @Sendable (Result<MTLComputePipelineState, HarbethError>) -> Void
    ) {
        let context = HarbethContext.shared
        /// 先读取缓存管线
        if let pipelineState = context.computePipelineState(for: kernel) {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: true)
            complete(.success(pipelineState))
            return
        }
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: kernel)
        let operation = BlockOperation {
            do {
                let pipeline = try context.makeComputePipelineState(identity: identity)
                context.setComputePipelineState(pipeline, for: kernel)
                HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: false)
                complete(.success(pipeline))
            } catch {
                HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute", hit: false)
                complete(.failure(HarbethError.computePipelineState(kernel)))
            }
        }
        HarbethContext.shared.renderOperationQueue.addOperation(operation)
    }

    static func makeComputePipelineState(
        with identity: KernelFunctionIdentity,
        complete: @escaping @Sendable (Result<MTLComputePipelineState, HarbethError>) -> Void
    ) {
        let context = HarbethContext.shared
        if let pipelineState = context.computePipelineState(for: identity) {
            HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: true)
            complete(.success(pipelineState))
            return
        }
        let operation = BlockOperation {
            do {
                let pipeline = try context.makeComputePipelineState(identity: identity)
                context.setComputePipelineState(pipeline, for: identity)
                HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: false)
                complete(.success(pipeline))
            } catch {
                HarbethContext.shared.performanceMonitor.recordPipelineCacheLookup("compute.identity", hit: false)
                complete(.failure(HarbethError.computePipelineState(identity.primaryName)))
            }
        }
        HarbethContext.shared.renderOperationQueue.addOperation(operation)
    }
    
    static func drawing(
        with kernel: String,
        commandBuffer: MTLCommandBuffer,
        textures: [MTLTexture],
        filter: C7FilterProtocol
    ) throws -> MTLTexture {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        let identity = filter.kernelDescriptor().functionIdentity
        let pipelineState = identity.primaryName == kernel
        ? try makeComputePipelineState(with: identity)
        : try makeComputePipelineState(with: kernel)
        return encoding(
            commandBuffer: commandBuffer,
            computeEncoder: computeEncoder,
            pipelineState: pipelineState,
            textures: textures,
            filter: filter
        )
    }
    
    static func drawing(
        with kernel: String,
        commandBuffer: MTLCommandBuffer,
        textures: [MTLTexture],
        filter: C7FilterProtocol,
        complete: @escaping @Sendable (Result<MTLTexture, HarbethError>) -> Void
    ) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            complete(.failure(HarbethError.makeComputeCommandEncoder))
            return
        }
        let identity = filter.kernelDescriptor().functionIdentity
        let makePipeline: (@escaping @Sendable (Result<MTLComputePipelineState, HarbethError>) -> Void) -> Void = {
            callback in
            if identity.primaryName == kernel {
                makeComputePipelineState(with: identity, complete: callback)
            } else {
                makeComputePipelineState(with: kernel, complete: callback)
            }
        }
        let execution = HarbethUncheckedTransfer(value: (commandBuffer, computeEncoder, textures, filter))
        makePipeline { res in
            switch res {
            case .success(let pipelineState):
                let destTexture = encoding(
                    commandBuffer: execution.value.0,
                    computeEncoder: execution.value.1,
                    pipelineState: pipelineState,
                    textures: execution.value.2,
                    filter: execution.value.3
                )
                complete(.success(destTexture))
            case .failure(let error): complete(.failure(error))
            }
        }
    }
    
    private static func calculateBaseSize(pattern: MemoryAccessPattern, pipelineState: MTLComputePipelineState) -> MTLSize {
        let maxThreads = pipelineState.maxTotalThreadsPerThreadgroup
        let architecture = Device.detectGPUArchitecture()
        switch (pattern, architecture) {
        case (.point, .appleSilicon):
            let size = min(32, Int(sqrt(Float(maxThreads))))
            return MTLSize(width: size, height: size, depth: 1)
        case (.point, .intel):
            let size = min(16, Int(sqrt(Float(maxThreads))))
            return MTLSize(width: size, height: size, depth: 1)
        case (.neighborhood, _):
            return MTLSize(width: 8, height: 8, depth: 1)
        case (.dualTexture, .appleSilicon):
            let size = min(24, Int(sqrt(Float(maxThreads))))
            return MTLSize(width: size, height: size, depth: 1)
        case (.dualTexture, .intel):
            return MTLSize(width: 16, height: 16, depth: 1)
        case (.multiTexture, _):
            return MTLSize(width: 16, height: 16, depth: 1)
        default:
            return MTLSize(width: 16, height: 16, depth: 1)
        }
    }
    
    private static func adjustForAspectRatio(_ size: MTLSize, texture: MTLTexture) -> MTLSize {
        let aspectRatio = Float(texture.width) / Float(texture.height)
        if aspectRatio > 2.0 {
            let newWidth = size.width * 2
            let newHeight = max(size.height / 2, 1)
            return MTLSize(width: newWidth, height: newHeight, depth: 1)
        } else if aspectRatio < 0.5 {
            let newHeight = size.height * 2
            let newWidth = max(size.width / 2, 1)
            return MTLSize(width: newWidth, height: newHeight, depth: 1)
        } else {
            return size
        }
    }
    
    private static func calculateOptimalThreadgroupSize(
        for pipelineState: MTLComputePipelineState,
        texture: MTLTexture,
        filter: C7FilterProtocol
    ) -> MTLSize {
        let pattern = filter.memoryAccessPattern
        let baseSize = calculateBaseSize(pattern: pattern, pipelineState: pipelineState)
        return adjustForAspectRatio(baseSize, texture: texture)
    }
    
    private static func encoding(
        commandBuffer: MTLCommandBuffer,
        computeEncoder: MTLComputeCommandEncoder,
        pipelineState: MTLComputePipelineState,
        textures: [MTLTexture],
        filter: C7FilterProtocol
    ) -> MTLTexture {
        if case .compute(let kernel) = filter.modifier {
            computeEncoder.label = kernel + " encoder"
        }
        computeEncoder.setComputePipelineState(pipelineState)
        let destTexture = textures[0]
        for (index, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: index)
        }

        // Canonical kernels may opt into the shared region ABI at buffer(30).
        // Normal rendering receives the complete texture as its logical canvas;
        // region renderers can override this binding through kernelParameterBindings.
        let inputWidth = textures.count > 1 ? textures[1].width : destTexture.width
        let inputHeight = textures.count > 1 ? textures[1].height : destTexture.height
        let defaultRegionContext: [Float] = [
            0, 0, Float(inputWidth), Float(inputHeight),
            0, 0, Float(destTexture.width), Float(destTexture.height)
        ]
        defaultRegionContext.withUnsafeBytes {
            computeEncoder.setBytes($0.baseAddress!, length: $0.count, index: 30)
        }

        let parameterBindings = filter.kernelParameterBindings
        if parameterBindings.isEmpty {
            let size = MemoryLayout<Float>.size
            for i in 0..<filter.factors.count {
                var factor = filter.factors[i]
                computeEncoder.setBytes(&factor, length: size, index: i)
            }
        } else {
            KernelBindingEncoder.encode(parameterBindings, stage: .compute, on: computeEncoder)
        }
        // Calculate optimal threadgroup size based on memory access pattern and GPU architecture
        let threadgroupSize = calculateOptimalThreadgroupSize(for: pipelineState, texture: destTexture, filter: filter)
        // -1 pixel to solve the problem that the edges of images are not drawn.
        // Minimum 1 pixel, solve the problem of zero without drawing.
        let width = max(Int((destTexture.width + threadgroupSize.width - 1) / threadgroupSize.width), 1)
        let height = max(Int((destTexture.height + threadgroupSize.height - 1) / threadgroupSize.height), 1)
        //let threadGroups = MTLSizeMake(width, height, destTexture.arrayLength)
        let threadgroupCount = MTLSize(width: width, height: height, depth: 1)
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        #if targetEnvironment(macCatalyst)
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.synchronize(resource: destTexture)
        blitEncoder?.endEncoding()
        #endif
        return destTexture
    }
}
