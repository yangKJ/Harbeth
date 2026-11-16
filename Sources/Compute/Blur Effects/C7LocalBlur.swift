//
//  C7LocalBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation
import Metal

/// 局部模糊滤镜
/// Local blur filter
public struct C7LocalBlur: C7MetalCommandEncodingProtocol {
    private var safeRadius: Float { radius.isFinite ? min(max(radius, 0), 100) : 0 }
    
    /// Blur radius, from 0.0 to 100.0, default 10.0
    public var radius: Float = 10.0
    
    /// Blur center, normalized coordinates (0.0-1.0), default center
    public var center: C7Point2D = C7Point2D.center
    
    /// Blur size, normalized (0.0-1.0), default 0.5
    @ZeroOneRange public var size: Float = 0.5
    
    /// Blur softness, from 0.0 to 1.0, default 0.3
    @ZeroOneRange public var softness: Float = 0.3
    
    public var modifier: ModifierEnum {
        return usesSeparable ? .metalCommand(label: "C7LocalBlurSeparable") : .compute(kernel: "C7LocalBlurDirect")
    }
    
    public var factors: [Float] {
        return [safeRadius, center.x, center.y, size, softness]
    }

    // 小作用区的额外全图 pass 和 CPU 编码成本超过节省的采样量，保留直接路径。
    private var usesSeparable: Bool {
        let estimatedArea = min(1, Float.pi * size * size * 0.25)
        return safeRadius > 10 && estimatedArea * (2 * ceil(safeRadius) + 1) > 8
    }

    var pipelineFilters: [C7FilterProtocol] {
        usesSeparable ? [LocalBlurPass(radius: safeRadius, horizontal: true), LocalBlurPass(radius: safeRadius, horizontal: false)] : []
    }

    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        let parameters = [safeRadius, center.x, center.y, size, softness]
        if usesSeparable {
            return PipelineLeafFilter(modifier: .compute(kernel: "C7LocalBlurComposite"), factors: parameters,
                                      otherInputTextures: otherInputTextures ?? [])
        }
        return PipelineLeafFilter(modifier: .compute(kernel: "C7LocalBlurDirect"), factors: parameters)
    }
    
    public var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(aliasingPolicy: .requiredDistinct)
    }

    public func metalCommandExecutionRoute(in environment: MetalCommandEnvironment) -> MetalCommandExecutionRoute { .preferred }

    public func encodeMetalCommands(context: MetalCommandEncodingContext, route: MetalCommandExecutionRoute) throws -> MTLTexture {
        try FilterPipelineExecutor.apply(filter: LocalBlurPipeline(base: self), source: context.sourceTexture,
            destination: context.destinationTexture, commandBuffer: context.commandBuffer)
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float16, dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(radius: Int(ceil(safeRadius))), coordinateDependency: .fullImage, fusionPolicy: .disabled)
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(radius: Float = 10.0, center: C7Point2D = C7Point2D.center, size: Float = 0.5, softness: Float = 0.3) {
        self.radius = radius
        self.center = center
        self.size = size
        self.softness = softness
    }
}

private struct LocalBlurPipeline: C7FilterPipelineProtocol {
    let base: C7LocalBlur
    var pipelineFilters: [C7FilterProtocol] { base.pipelineFilters }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        base.makeFinalFilter(otherInputTextures: otherInputTextures)
    }
}

private struct LocalBlurPass: C7FilterProtocol {
    let radius: Float
    let horizontal: Bool
    var modifier: ModifierEnum { .compute(kernel: "C7LocalBlurPass") }
    var kernelOutputContract: RenderOutputContract {
        RenderOutputContract(pixelFormat: PixelFormatContract(pixelFormat: .rgba16Float, preservesInput: false))
    }
    var factors: [Float] { [radius, horizontal ? 1 : 0] }
    var kernelParameterBindings: [KernelParameterBinding] {
        let safe = radius.isFinite ? min(max(radius, 0), 100) : 0
        let r = max(0, Int(ceil(safe)))
        let sigma = max(safe / 3, 0.0001)
        let raw = (-r...r).map { exp(-Float($0 * $0) / (2 * sigma * sigma)) }
        let sum = raw.reduce(0, +)
        return [KernelParameterBinding(name: "radius", index: 0, stage: .compute, value: .float(radius)),
                KernelParameterBinding(name: "horizontal", index: 1, stage: .compute, value: .float(horizontal ? 1 : 0)),
                KernelParameterBinding(name: "weights", index: 2, stage: .compute,
                                       value: .floatArray(raw.map { $0 / sum }))]
    }
}
