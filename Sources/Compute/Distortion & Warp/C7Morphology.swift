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
    
    public static let range: ParameterRange<Float, Self> = .init(min: 1, max: 10, value: 3)
    
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
        return [operationValue, kernelSize]
    }
    
    public init(operation: OperationType, kernelSize: Float = range.value) {
        self.operation = operation
        self.kernelSize = kernelSize
    }
}
