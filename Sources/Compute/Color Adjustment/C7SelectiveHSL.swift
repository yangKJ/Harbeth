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

    /// 在摄影中性色响应内，对指定色相和色度附加局部色彩调整。
    public struct NeutralColorWindow: Equatable, Sendable {
        public let hueWindow: HueWindow
        public let saturationDelta: Float
        /// HSL 饱和度从此区间逐渐退出局部校正。
        public let saturationFadeRange: SIMD2<Float>?
        public let lightnessDelta: Float
        /// 前两项为亮度渐入边界，第三项为附加饱和度偏移。
        public let lightnessSaturationAdjustment: SIMD3<Float>?

        public init?(
            hueWindow: HueWindow,
            saturationDelta: Float,
            saturationFadeRange: SIMD2<Float>? = nil,
            lightnessDelta: Float = 0,
            lightnessSaturationAdjustment: SIMD3<Float>? = nil
        ) {
            guard (-1...1).contains(saturationDelta), (-1...1).contains(lightnessDelta) else { return nil }
            if let saturationFadeRange {
                guard saturationFadeRange.x >= 0, saturationFadeRange.x < saturationFadeRange.y,
                      saturationFadeRange.y <= 1 else { return nil }
            }
            if let adjustment = lightnessSaturationAdjustment {
                guard adjustment.x >= 0, adjustment.x < adjustment.y, adjustment.y <= 1,
                      (-1...1).contains(adjustment.z) else { return nil }
            }
            self.hueWindow = hueWindow
            self.saturationDelta = saturationDelta
            self.saturationFadeRange = saturationFadeRange
            self.lightnessDelta = lightnessDelta
            self.lightnessSaturationAdjustment = lightnessSaturationAdjustment
        }
    }

    /// 对显示色域内指定的色相与色度区间，分别校正 Lab 明度、色度和色相。
    public struct LabColorCorrection: Codable, Hashable, Sendable {
        public static let maximumCount = 12

        public let hueEdges: SIMD4<Float>
        public let chromaEdges: SIMD2<Float>
        public let lightnessEdges: SIMD2<Float>
        /// 可选的低明度起点和全强度点。未指定时维持原有暗部权重。
        public let minimumLightnessEdges: SIMD2<Float>?
        /// 可选的高色度渐退区间。未指定时，色度超过渐入区间后保持全强度。
        public let chromaFadeEdges: SIMD2<Float>?
        /// 校正触及正色域上限的高光颜色，同时保留已扩展的 RGB 通道。
        public let mapsHighlightsAtGamutBoundary: Bool?
        /// L* 增量、色度增量、色相角度增量。
        public let delta: SIMD3<Float>

        public init?(
            hueEdges: SIMD4<Float>,
            chromaEdges: SIMD2<Float>,
            lightnessEdges: SIMD2<Float>,
            delta: SIMD3<Float>,
            minimumLightnessEdges: SIMD2<Float>? = nil,
            chromaFadeEdges: SIMD2<Float>? = nil,
            mapsHighlightsAtGamutBoundary: Bool? = nil
        ) {
            self.hueEdges = hueEdges
            self.chromaEdges = chromaEdges
            self.lightnessEdges = lightnessEdges
            self.minimumLightnessEdges = minimumLightnessEdges
            self.chromaFadeEdges = chromaFadeEdges
            self.mapsHighlightsAtGamutBoundary = mapsHighlightsAtGamutBoundary
            self.delta = delta
            guard isValid else { return nil }
        }

        public var isValid: Bool {
            if let minimumLightnessEdges,
               !(minimumLightnessEdges.x >= 0 && minimumLightnessEdges.x < minimumLightnessEdges.y
                 && minimumLightnessEdges.y <= lightnessEdges.x) { return false }
            if let chromaFadeEdges,
               !(chromaFadeEdges.x >= chromaEdges.y && chromaFadeEdges.x < chromaFadeEdges.y
                 && chromaFadeEdges.y <= 128) { return false }

            return hueEdges.x >= 0 && hueEdges.x < hueEdges.y && hueEdges.y <= hueEdges.z
                && hueEdges.z < hueEdges.w && hueEdges.w <= 360
                && chromaEdges.x > 0 && chromaEdges.x < chromaEdges.y && chromaEdges.y <= 128
                && lightnessEdges.x >= 0 && lightnessEdges.x < lightnessEdges.y && lightnessEdges.y <= 100
                && (-20...20).contains(delta.x) && (-40...40).contains(delta.y) && (-45...45).contains(delta.z)
        }

        fileprivate var parameterValues: [Float] {
            let minimum = minimumLightnessEdges ?? .zero
            let fade = chromaFadeEdges ?? .zero
            return [hueEdges.x, hueEdges.y, hueEdges.z, hueEdges.w,
                    chromaEdges.x, chromaEdges.y, lightnessEdges.x, lightnessEdges.y,
                    delta.x, delta.y, delta.z, minimum.x, minimum.y, fade.x, fade.y,
                    mapsHighlightsAtGamutBoundary == true ? 1 : 0]
        }
    }

    /// 在 sRGB 编码的摄影中性色响应中，按 Lab 明度与色度调节指定色相。
    public struct LabColorWindow: Equatable, Sendable {
        public let hueEdges: SIMD4<Float>
        public let chromaEdges: SIMD2<Float>
        public let highlightEdges: SIMD2<Float>
        /// 明度 L*、径向色度增量和沿色相切向的 Lab 增量。
        public let low: SIMD3<Float>
        public let high: SIMD3<Float>
        public let corrections: [LabColorCorrection]

        public init?(
            hueEdges: SIMD4<Float>,
            chromaEdges: SIMD2<Float>,
            highlightEdges: SIMD2<Float>,
            low: SIMD3<Float>,
            high: SIMD3<Float>,
            corrections: [LabColorCorrection] = []
        ) {
            guard hueEdges.x >= 0, hueEdges.x < hueEdges.y, hueEdges.y <= hueEdges.z,
                  hueEdges.z < hueEdges.w, hueEdges.w <= 360,
                  chromaEdges.x >= 0, chromaEdges.x < chromaEdges.y, chromaEdges.y.isFinite,
                  highlightEdges.x >= 0, highlightEdges.x < highlightEdges.y, highlightEdges.y <= 100,
                  low.x >= 0, low.x < high.x, high.x <= 100,
                  [low.y, low.z, high.y, high.z].allSatisfy({ (-128...128).contains($0) }),
                  corrections.count <= LabColorCorrection.maximumCount, corrections.allSatisfy(\.isValid) else { return nil }
            self.hueEdges = hueEdges
            self.chromaEdges = chromaEdges
            self.highlightEdges = highlightEdges
            self.low = low
            self.high = high
            self.corrections = corrections
        }
    }

    /// 提升高亮冷色中的较低通道。各边界以编码 RGB 为单位。
    public struct HighlightNeutralization: Equatable, Sendable {
        public let amount: Float
        public let greenEdges: SIMD2<Float>
        public let blueEdges: SIMD2<Float>
        public let chromaEdges: SIMD4<Float>
        public let cyanEdges: SIMD2<Float>
        /// 在较低亮度收紧色度渐退边界，达到完整亮度时回到原边界。
        public let lowerToneChromaScale: Float
        public let upperToneExpansion: UpperToneExpansion?

        /// 在更亮的区域扩展色度渐退，单独控制新增绿通道增益。
        public struct UpperToneExpansion: Equatable, Sendable {
            public let greenEdges: SIMD2<Float>
            public let chromaFadeOffsets: SIMD2<Float>
            public let greenAmount: Float
            /// 前两项为蓝通道渐入边界，后两项为附加色度渐退偏移。
            public let blueClipExpansion: SIMD4<Float>?

            public init?(
                greenEdges: SIMD2<Float>,
                chromaFadeOffsets: SIMD2<Float>,
                greenAmount: Float,
                blueClipExpansion: SIMD4<Float>? = nil
            ) {
                guard greenEdges.x >= 0, greenEdges.x < greenEdges.y, greenEdges.y <= 1,
                      chromaFadeOffsets.x >= 0, chromaFadeOffsets.x <= chromaFadeOffsets.y,
                      chromaFadeOffsets.y <= 1, (0...1).contains(greenAmount) else { return nil }
                if let clip = blueClipExpansion {
                    guard clip.x >= 0, clip.x < clip.y, clip.y <= 1,
                          clip.z >= 0, clip.z <= clip.w, clip.w <= 1 else { return nil }
                }
                self.greenEdges = greenEdges
                self.chromaFadeOffsets = chromaFadeOffsets
                self.greenAmount = greenAmount
                self.blueClipExpansion = blueClipExpansion
            }
        }

        public init?(
            amount: Float,
            greenEdges: SIMD2<Float>,
            blueEdges: SIMD2<Float>,
            chromaEdges: SIMD4<Float>,
            cyanEdges: SIMD2<Float>,
            lowerToneChromaScale: Float = 1,
            upperToneExpansion: UpperToneExpansion? = nil
        ) {
            let pairedEdges = [greenEdges, blueEdges, cyanEdges]
            guard (0...1).contains(amount),
                  pairedEdges.allSatisfy({ $0.x >= 0 && $0.x < $0.y && $0.y <= 1 }),
                  chromaEdges.x > 0, chromaEdges.x < chromaEdges.y,
                  chromaEdges.y <= chromaEdges.z, chromaEdges.z < chromaEdges.w, chromaEdges.w <= 1,
                  lowerToneChromaScale > 0, lowerToneChromaScale <= 1,
                  chromaEdges.y <= chromaEdges.z * lowerToneChromaScale,
                  chromaEdges.w + (upperToneExpansion?.chromaFadeOffsets.y ?? 0)
                    + (upperToneExpansion?.blueClipExpansion?.w ?? 0) <= 1 else {
                return nil
            }
            self.amount = amount
            self.greenEdges = greenEdges
            self.blueEdges = blueEdges
            self.chromaEdges = chromaEdges
            self.cyanEdges = cyanEdges
            self.lowerToneChromaScale = lowerToneChromaScale
            self.upperToneExpansion = upperToneExpansion
        }
    }

    public static let channelCount = 8
    public var adjustments: [SIMD3<Float>]
    public var response: Response
    /// 仅在 photographicNeutral 下生效，按 RGB 分量在 -0.1...0.1 范围内偏移。
    public var neutralShadows: SIMD3<Float>
    public var neutralHighlights: SIMD3<Float>
    public private(set) var neutralColorWindow: NeutralColorWindow?
    public private(set) var labColorWindow: LabColorWindow?
    public private(set) var highlightNeutralization: HighlightNeutralization?
    public private(set) var hueWindow = HueWindow(
        hueEdges: SIMD4<Float>(0, 1, 359, 360),
        chromaEdges: SIMD2<Float>(0, 1),
        rotation: 0
    )!

    public var modifier: ModifierEnum {
        switch response {
        case .additive: return .compute(kernel: "C7SelectiveHSL")
        case .photographic: return .compute(kernel: "C7SelectiveHSLPhotographic")
        case .photographicNeutral:
            if highlightNeutralization != nil { return .compute(kernel: "C7SelectiveHSLPhotographicHighlights") }
            if let lab = labColorWindow {
                return .compute(kernel: lab.corrections.isEmpty ? "C7SelectiveHSLPhotographicLabColorWindow"
                    : "C7SelectiveHSLPhotographicLabColorWindowRefined")
            }
            return .compute(kernel: neutralColorWindow == nil
                ? "C7SelectiveHSLPhotographicNeutral"
                : "C7SelectiveHSLPhotographicNeutralColorWindow")
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
            if neutralColorWindow != nil || labColorWindow != nil || highlightNeutralization != nil {
                let window = neutralColorWindow
                let hue = window?.hueWindow
                let chroma = hue?.chromaEdges ?? SIMD2<Float>(0, 1)
                bindings.append(KernelParameterBinding(
                    name: "hueEdges", index: 3, stage: .compute, value: .float4(hue?.hueEdges ?? .zero)
                ))
                bindings.append(KernelParameterBinding(
                    name: "colorAdjustment",
                    index: 4,
                    stage: .compute,
                    value: .float4(SIMD4(chroma.x, chroma.y, hue?.rotation ?? 0, window?.saturationDelta ?? 0))
                ))
                let fade = window?.saturationFadeRange ?? SIMD2<Float>(repeating: 1)
                bindings.append(KernelParameterBinding(
                    name: "windowTone",
                    index: 5,
                    stage: .compute,
                    value: .float3(SIMD3(fade.x, fade.y, window?.lightnessDelta ?? 0))
                ))
                bindings.append(.init(
                    name: "windowLightnessSaturation",
                    index: 12,
                    stage: .compute,
                    value: .float3(window?.lightnessSaturationAdjustment ?? .zero)
                ))
            }
        }
        if response == .photographicNeutral, let highlight = highlightNeutralization {
            let tone = SIMD4(highlight.greenEdges.x, highlight.greenEdges.y, highlight.blueEdges.x, highlight.blueEdges.y)
            let strength = SIMD4(
                highlight.cyanEdges.x, highlight.cyanEdges.y, highlight.amount, highlight.lowerToneChromaScale
            )
            let upper = highlight.upperToneExpansion
            let expansion = SIMD4(
                upper?.greenEdges.x ?? 0, upper?.greenEdges.y ?? 0,
                upper?.chromaFadeOffsets.x ?? 0, upper?.chromaFadeOffsets.y ?? 0
            )
            bindings += [
                .init(name: "highlightToneEdges", index: 6, stage: .compute, value: .float4(tone)),
                .init(name: "highlightChromaEdges", index: 7, stage: .compute, value: .float4(highlight.chromaEdges)),
                .init(name: "highlightCyanAndAmount", index: 8, stage: .compute, value: .float4(strength)),
                .init(name: "highlightUpperTone", index: 9, stage: .compute, value: .float4(expansion)),
                .init(name: "highlightUpperGreenAmount", index: 10, stage: .compute, value: .float(upper?.greenAmount ?? 1)),
                .init(name: "highlightBlueClip", index: 11, stage: .compute, value: .float4(upper?.blueClipExpansion ?? .zero)),
            ]
        }
        if response == .photographicNeutral, let lab = labColorWindow {
            let edges = SIMD4(lab.chromaEdges.x, lab.chromaEdges.y, lab.highlightEdges.x, lab.highlightEdges.y)
            bindings += [
                .init(name: "labHueEdges", index: 6, stage: .compute, value: .float4(lab.hueEdges)),
                .init(name: "labChromaAndHighlightEdges", index: 7, stage: .compute, value: .float4(edges)),
                .init(name: "labLow", index: 8, stage: .compute, value: .float3(lab.low)),
                .init(name: "labHigh", index: 9, stage: .compute, value: .float3(lab.high)),
            ]
            if !lab.corrections.isEmpty {
                let mapsHighlights = lab.corrections.contains { $0.mapsHighlightsAtGamutBoundary == true }
                let header: [Float] = [Float(lab.corrections.count), mapsHighlights ? 1 : 0]
                bindings.append(.init(name: "labCorrections", index: 10, stage: .compute,
                    value: .floatArray(header + lab.corrections.flatMap(\.parameterValues))))
            }
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
        neutralHighlights: SIMD3<Float> = .zero,
        neutralColorWindow: NeutralColorWindow? = nil,
        labColorWindow: LabColorWindow? = nil
    ) {
        self.response = response
        self.neutralShadows = neutralShadows
        self.neutralHighlights = neutralHighlights
        self.neutralColorWindow = neutralColorWindow
        self.labColorWindow = labColorWindow
        let values = Array(adjustments.prefix(Self.channelCount))
        self.adjustments = values + Array(repeating: .zero, count: Self.channelCount - values.count)
    }

    public init(
        adjustments: [SIMD3<Float>] = [],
        neutralShadows: SIMD3<Float> = .zero,
        neutralHighlights: SIMD3<Float> = .zero,
        neutralColorWindow: NeutralColorWindow? = nil,
        highlightNeutralization: HighlightNeutralization
    ) {
        self.init(
            adjustments: adjustments, response: .photographicNeutral,
            neutralShadows: neutralShadows, neutralHighlights: neutralHighlights,
            neutralColorWindow: neutralColorWindow
        )
        if highlightNeutralization.amount > 0 {
            self.highlightNeutralization = highlightNeutralization
        }
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
