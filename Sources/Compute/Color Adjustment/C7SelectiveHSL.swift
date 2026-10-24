//
//  C7SelectiveHSL.swift
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

import Foundation

/// 八分色色相、饱和度与明度调整。
///
/// 每个通道依次对应红、橙、黄、绿、青、蓝、紫、洋红；三个分量均使用 -1...1。
public struct C7SelectiveHSL: C7FilterProtocol {

    /// 加法响应用于直接调整；摄影响应降低近黑色选择并保持明度端点。
    public enum Response: String, Sendable {
        case additive
        case photographic
    }

    public static let channelCount = 8
    public var adjustments: [SIMD3<Float>]
    public var response: Response

    public var modifier: ModifierEnum {
        .compute(kernel: response == .additive ? "C7SelectiveHSL" : "C7SelectiveHSLPhotographic")
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "adjustments",
                index: 0,
                stage: .compute,
                value: .floatArray(normalizedAdjustments.flatMap { [$0.x, $0.y, $0.z] })
            )
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(adjustments: [SIMD3<Float>] = [], response: Response = .additive) {
        self.response = response
        let values = Array(adjustments.prefix(Self.channelCount))
        self.adjustments = values + Array(repeating: .zero, count: Self.channelCount - values.count)
    }

    private var normalizedAdjustments: [SIMD3<Float>] {
        let values = Array(adjustments.prefix(Self.channelCount)).map { value in
            SIMD3<Float>(
                min(1, max(-1, value.x)),
                min(1, max(-1, value.y)),
                min(1, max(-1, value.z))
            )
        }
        return values + Array(repeating: .zero, count: Self.channelCount - values.count)
    }
}
