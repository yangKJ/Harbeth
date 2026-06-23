//
//  LensProfile.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

/// 光学校正 profile 承载底座。
///
/// 当前先承载 Harbeth 已有的基础 optics 参数：
/// - geometric distortion
/// - chromatic aberration
/// - vignette compensation
///
/// 后续可以继续扩展 metadata、焦段区间、机身适配和序列化。
public struct LensProfile: Codable, Equatable {

    public struct CorrectionStrength: Codable, Equatable {
        public var distortion: Float
        public var chromaticAberration: Float
        public var vignette: Float
        public var diffraction: Float

        public init(distortion: Float = 1, chromaticAberration: Float = 1, vignette: Float = 1, diffraction: Float = 1) {
            self.distortion = distortion
            self.chromaticAberration = chromaticAberration
            self.vignette = vignette
            self.diffraction = diffraction
        }

        public static let unity = CorrectionStrength()
    }

    public struct DistortionCorrection: Codable, Equatable {
        public var center: C7Point2D
        public var distortion: Float
        public var cubicDistortion: Float
        public var scale: Float

        public init(center: C7Point2D = .center, distortion: Float = 0, cubicDistortion: Float = 0, scale: Float = 1) {
            self.center = center
            self.distortion = distortion
            self.cubicDistortion = cubicDistortion
            self.scale = scale
        }
    }

    public struct ChromaticAberrationCorrection: Codable, Equatable {
        public var center: C7Point2D
        public var redCyanShift: Float
        public var blueYellowShift: Float

        public init(center: C7Point2D = .center, redCyanShift: Float = 0, blueYellowShift: Float = 0) {
            self.center = center
            self.redCyanShift = redCyanShift
            self.blueYellowShift = blueYellowShift
        }
    }

    public struct VignetteCorrection: Codable, Equatable {
        public var center: C7Point2D
        public var amount: Float
        public var start: Float
        public var end: Float

        public init(center: C7Point2D = .center, amount: Float = 0, start: Float = 0.35, end: Float = 1.0) {
            self.center = center
            self.amount = amount
            self.start = start
            self.end = end
        }
    }

    public struct DiffractionCorrection: Codable, Equatable {
        public var amount: Float
        public var radius: Float
        public var edgeThreshold: Float

        public init(amount: Float = 0, radius: Float = 1, edgeThreshold: Float = 0.08) {
            self.amount = amount
            self.radius = radius
            self.edgeThreshold = edgeThreshold
        }
    }

    public var make: String
    public var model: String
    public var profileName: String
    public var distortionCorrection: DistortionCorrection?
    public var chromaticAberrationCorrection: ChromaticAberrationCorrection?
    public var vignetteCorrection: VignetteCorrection?
    public var diffractionCorrection: DiffractionCorrection?

    public init(make: String,
                model: String,
                profileName: String,
                distortionCorrection: DistortionCorrection? = nil,
                chromaticAberrationCorrection: ChromaticAberrationCorrection? = nil,
                vignetteCorrection: VignetteCorrection? = nil,
                diffractionCorrection: DiffractionCorrection? = nil) {
        self.make = make
        self.model = model
        self.profileName = profileName
        self.distortionCorrection = distortionCorrection
        self.chromaticAberrationCorrection = chromaticAberrationCorrection
        self.vignetteCorrection = vignetteCorrection
        self.diffractionCorrection = diffractionCorrection
    }

    public func makeDistortionFilter(samplingMode: SpatialSamplingMode = .adaptive,
                                     edgeMode: SpatialEdgeMode = .transparent,
                                     strength: Float = 1) -> C7LensDistortionCorrection? {
        guard let correction = distortionCorrection else { return nil }
        let clampedStrength = max(0, strength)
        return C7LensDistortionCorrection(
            center: correction.center,
            distortion: correction.distortion * clampedStrength,
            cubicDistortion: correction.cubicDistortion * clampedStrength,
            scale: 1 + (correction.scale - 1) * clampedStrength,
            samplingMode: samplingMode,
            edgeMode: edgeMode
        )
    }

    public func makeChromaticAberrationFilter(samplingMode: SpatialSamplingMode = .adaptive,
                                              edgeMode: SpatialEdgeMode = .transparent,
                                              strength: Float = 1) -> C7ChromaticAberrationCorrection? {
        guard let correction = chromaticAberrationCorrection else { return nil }
        let clampedStrength = max(0, strength)
        return C7ChromaticAberrationCorrection(
            center: correction.center,
            redCyanShift: correction.redCyanShift * clampedStrength,
            blueYellowShift: correction.blueYellowShift * clampedStrength,
            samplingMode: samplingMode,
            edgeMode: edgeMode
        )
    }

    public func makeVignetteFilter(strength: Float = 1) -> C7LensVignetteCorrection? {
        guard let correction = vignetteCorrection else { return nil }
        let clampedStrength = max(0, strength)
        return C7LensVignetteCorrection(
            center: correction.center,
            amount: correction.amount * clampedStrength,
            start: correction.start,
            end: correction.end
        )
    }

    public func makeDiffractionFilter(strength: Float = 1) -> C7DiffractionCorrection? {
        guard let correction = diffractionCorrection else { return nil }
        let clampedStrength = max(0, strength)
        return C7DiffractionCorrection(
            amount: correction.amount * clampedStrength,
            radius: correction.radius,
            edgeThreshold: correction.edgeThreshold
        )
    }

    /// 以当前 profile 产出完整 optics 校正链。
    ///
    /// 默认顺序：
    /// 1. distortion
    /// 2. chromatic aberration
    /// 3. vignette compensation
    /// 4. diffraction correction
    ///
    /// 这样能先把几何与色边坐标对齐，再做边缘亮度补偿，
    /// 最后进行 capture sharpening。
    public func makeCorrectionFilters(samplingMode: SpatialSamplingMode = .adaptive,
                                      edgeMode: SpatialEdgeMode = .transparent,
                                      strength: CorrectionStrength = .unity) -> [C7FilterProtocol] {
        var filters: [C7FilterProtocol] = []
        if let distortion = makeDistortionFilter(samplingMode: samplingMode, edgeMode: edgeMode, strength: strength.distortion) {
            filters.append(distortion)
        }
        if let chromaticAberration = makeChromaticAberrationFilter(samplingMode: samplingMode, edgeMode: edgeMode, strength: strength.chromaticAberration) {
            filters.append(chromaticAberration)
        }
        if let vignette = makeVignetteFilter(strength: strength.vignette) {
            filters.append(vignette)
        }
        if let diffraction = makeDiffractionFilter(strength: strength.diffraction) {
            filters.append(diffraction)
        }
        return filters
    }
}
