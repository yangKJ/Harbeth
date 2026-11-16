//
//  C7TiltShift.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 移轴滤镜
/// Tilt Shift filter
public struct C7TiltShift: C7FilterPipelineProtocol {
    
    public enum TiltShiftMode {
        case linear
        case radial
    }
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.2)
    
    /// 模糊半径，0.0 到 1.0，默认 0.2
    @Clamping(range.min...range.max) public var blurRadius: Float = range.value
    
    /// 清晰区域中心，0.0 到 1.0，默认 0.5
    @ZeroOneRange public var center: Float = 0.5
    
    /// 清晰区域大小，0.0 到 1.0，默认 0.3
    @ZeroOneRange public var size: Float = 0.3
    
    /// 过渡区域大小，0.0 到 1.0，默认 0.1
    @ZeroOneRange public var transition: Float = 0.1
    
    /// 移轴模式，线性或径向
    public var mode: TiltShiftMode = .linear
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7TiltShiftComposite")
    }
    
    public var factors: [Float] {
        return [blurRadius, center, size, transition, mode == .linear ? 1.0 : 0.0]
    }

    public var pipelineFilters: [C7FilterProtocol] {
        [TiltShiftPass(radius: blurRadius, horizontal: true), TiltShiftPass(radius: blurRadius, horizontal: false)]
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(modifier: .compute(kernel: "C7TiltShiftComposite"), factors: factors,
                           otherInputTextures: otherInputTextures ?? [])
    }
    
    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float16, dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(radius: Int(ceil((blurRadius.isFinite ? blurRadius : 0) * 100))), coordinateDependency: .fullImage, fusionPolicy: .disabled)
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(blurRadius: Float = range.value, center: Float = 0.5, size: Float = 0.3, transition: Float = 0.1, mode: TiltShiftMode = .linear) {
        self.blurRadius = blurRadius
        self.center = center
        self.size = size
        self.transition = transition
        self.mode = mode
    }
}

private struct TiltShiftPass: C7FilterProtocol {
    let radius: Float
    let horizontal: Bool
    var modifier: ModifierEnum { .compute(kernel: "C7TiltShiftPass") }
    var kernelOutputContract: RenderOutputContract {
        RenderOutputContract(pixelFormat: PixelFormatContract(pixelFormat: .rgba16Float, preservesInput: false))
    }
    var factors: [Float] { [radius, horizontal ? 1 : 0] }
    var kernelParameterBindings: [KernelParameterBinding] {
        let safe = radius.isFinite ? min(max(radius, 0), 1) : 0
        let r = max(0, Int(ceil(safe * 100)))
        let sigma = max(safe * 10, 0.0001)
        let raw = (-r...r).map { exp(-Float($0 * $0) / (2 * sigma * sigma)) }
        let sum = raw.reduce(0, +)
        return [KernelParameterBinding(name: "radius", index: 0, stage: .compute, value: .float(radius)),
                KernelParameterBinding(name: "horizontal", index: 1, stage: .compute, value: .float(horizontal ? 1 : 0)),
                KernelParameterBinding(name: "weights", index: 2, stage: .compute,
                                       value: .floatArray(raw.map { $0 / sum }))]
    }
}
