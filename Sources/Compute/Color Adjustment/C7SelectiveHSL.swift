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

    /// 摄影响应降低近黑色的色相选择，并平滑收敛明度调整。
    public enum Response: String, Sendable {
        case additive
        case photographic
        /// 保留摄影响应，并在同一 pass 内调整低色度的亮部和暗部。
        case photographicNeutral
        /// 在一个带柔和边缘的色相窗口内旋转色相，同时保护低色度和近黑像素。
        case photographicHueWindow
    }

    public struct HueWindow: Equatable, Sendable {
        /// 色相的进入、全权重起点、全权重终点与退出边缘，单位为度。
        public let hueEdges: SIMD4<Float>
        /// 编码 RGB 最大与最小通道差的起始和全权重阈值。
        public let chromaEdges: SIMD2<Float>
        public let rotation: Float

        public init?(hueEdges: SIMD4<Float>, chromaEdges: SIMD2<Float>, rotation: Float) {
            guard hueEdges.x >= 0, hueEdges.x < hueEdges.y, hueEdges.y <= hueEdges.z,
                  hueEdges.z < hueEdges.w, hueEdges.w <= 360,
                  chromaEdges.x >= 0, chromaEdges.x < chromaEdges.y, chromaEdges.y <= 1,
                  (-60...60).contains(rotation) else { return nil }
            self.hueEdges = hueEdges
            self.chromaEdges = chromaEdges
            self.rotation = rotation
        }
    }

    public static let channelCount = 8
    public var adjustments: [SIMD3<Float>]
    public var response: Response
    /// 仅在 photographicNeutral 下生效，按 RGB 分量在 -0.1...0.1 范围内偏移。
    public var neutralShadows: SIMD3<Float>
    public var neutralHighlights: SIMD3<Float>
    public private(set) var hueWindow = HueWindow(
        hueEdges: SIMD4<Float>(0, 1, 359, 360),
        chromaEdges: SIMD2<Float>(0, 1),
        rotation: 0
    )!

    public var modifier: ModifierEnum {
        switch response {
        case .additive: return .compute(kernel: "C7SelectiveHSL")
        case .photographic: return .compute(kernel: "C7SelectiveHSLPhotographic")
        case .photographicNeutral: return .compute(kernel: "C7SelectiveHSLPhotographicNeutral")
        case .photographicHueWindow: return .compute(kernel: "C7SelectiveHSLPhotographicHueWindow")
        }
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        if response == .photographicHueWindow {
            let chroma = hueWindow.chromaEdges
            return [
                KernelParameterBinding(name: "hueEdges", index: 0, stage: .compute, value: .float4(hueWindow.hueEdges)),
                KernelParameterBinding(
                    name: "chromaAndRotation",
                    index: 1,
                    stage: .compute,
                    value: .float3(SIMD3<Float>(chroma.x, chroma.y, hueWindow.rotation))
                )
            ]
        }
        var bindings = [
            KernelParameterBinding(
                name: "adjustments",
                index: 0,
                stage: .compute,
                value: .floatArray(normalizedAdjustments.flatMap { [$0.x, $0.y, $0.z] })
            )
        ]
        if response == .photographicNeutral {
            bindings.append(KernelParameterBinding(
                name: "neutralShadows", index: 1, stage: .compute, value: .float3(neutralShadows)
            ))
            bindings.append(KernelParameterBinding(
                name: "neutralHighlights", index: 2, stage: .compute, value: .float3(neutralHighlights)
            ))
        }
        return bindings
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelPixelContract: KernelPixelContract {
        guard response == .photographicNeutral || response == .photographicHueWindow else {
            return .conservative(samplingFootprint: samplingFootprint)
        }
        return KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            precision: .float32,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    public init(
        adjustments: [SIMD3<Float>] = [],
        response: Response = .additive,
        neutralShadows: SIMD3<Float> = .zero,
        neutralHighlights: SIMD3<Float> = .zero
    ) {
        self.response = response
        self.neutralShadows = neutralShadows
        self.neutralHighlights = neutralHighlights
        let values = Array(adjustments.prefix(Self.channelCount))
        self.adjustments = values + Array(repeating: .zero, count: Self.channelCount - values.count)
    }

    public init(hueWindow: HueWindow) {
        self.init(response: .photographicHueWindow)
        self.hueWindow = hueWindow
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
