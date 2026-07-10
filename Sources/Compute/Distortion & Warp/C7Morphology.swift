//
//  C7Morphology.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation

/// 形态学操作滤镜（腐蚀和膨胀）
/// Morphological operation filter (corrosion and expansion)
public struct C7Morphology: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 1, max: 9, value: 3)
    
    public enum OperationType {
        case erosion, dilation
    }
    
    public let operation: OperationType
    
    /// The size of structural elements.
    @Clamping(range.min...range.max) public var kernelSize: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Morphology")
    }
    
    public var factors: [Float] {
        let operationValue: Float = operation == .erosion ? 0.0 : 1.0
        return [operationValue, Float(normalizedKernelSize)]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: normalizedKernelSize / 2)
    }

    /// 形态学 kernel 统一为 1...9 的奇数；偶数向上取整到下一个奇数。
    /// 例如 0、1、2、4、10 分别归一化为 1、1、3、5、9。
    public var normalizedKernelSize: Int {
        let rounded = Int(kernelSize.rounded())
        let clamped = min(max(rounded, 1), 9)
        if clamped.isMultiple(of: 2) {
            return min(clamped + 1, 9)
        }
        return clamped
    }
    
    public init(operation: OperationType, kernelSize: Float = range.value) {
        self.operation = operation
        self.kernelSize = kernelSize
    }
}
