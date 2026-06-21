//
//  OpticsSettings.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

/// Harbeth optics 聚合入口。
///
/// 目标是把当前和后续的镜头/光学校正能力收进统一配置层，
/// 而不是让上层自己手动拼装多个零散滤镜。
public struct OpticsSettings: Codable, Equatable {

    public var profile: LensProfile?
    public var profileStrength: LensProfile.CorrectionStrength
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public var defringe: Defringe?
    public var sharpnessFalloff: SharpnessFalloff?

    public init(profile: LensProfile? = nil,
                profileStrength: LensProfile.CorrectionStrength = .unity,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent,
                defringe: Defringe? = nil,
                sharpnessFalloff: SharpnessFalloff? = nil) {
        self.profile = profile
        self.profileStrength = profileStrength
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.defringe = defringe
        self.sharpnessFalloff = sharpnessFalloff
    }

    public struct Defringe: Codable, Equatable {
        public var purpleAmount: Float
        public var purpleHueStart: Float
        public var purpleHueEnd: Float
        public var greenAmount: Float
        public var greenHueStart: Float
        public var greenHueEnd: Float
        public var edgeThreshold: Float
        public var saturationThreshold: Float

        public init(purpleAmount: Float = 0,
                    purpleHueStart: Float = 250,
                    purpleHueEnd: Float = 320,
                    greenAmount: Float = 0,
                    greenHueStart: Float = 90,
                    greenHueEnd: Float = 170,
                    edgeThreshold: Float = 0.08,
                    saturationThreshold: Float = 0.15) {
            self.purpleAmount = purpleAmount
            self.purpleHueStart = purpleHueStart
            self.purpleHueEnd = purpleHueEnd
            self.greenAmount = greenAmount
            self.greenHueStart = greenHueStart
            self.greenHueEnd = greenHueEnd
            self.edgeThreshold = edgeThreshold
            self.saturationThreshold = saturationThreshold
        }

        public var isIdentity: Bool {
            purpleAmount == 0 && greenAmount == 0
        }

        public func makeFilter() -> C7DefringeCorrection {
            C7DefringeCorrection(
                purpleAmount: purpleAmount,
                purpleHueStart: purpleHueStart,
                purpleHueEnd: purpleHueEnd,
                greenAmount: greenAmount,
                greenHueStart: greenHueStart,
                greenHueEnd: greenHueEnd,
                edgeThreshold: edgeThreshold,
                saturationThreshold: saturationThreshold
            )
        }
    }

    public struct SharpnessFalloff: Codable, Equatable {
        public var center: C7Point2D
        public var amount: Float
        public var start: Float
        public var end: Float
        public var edgeThreshold: Float

        public init(center: C7Point2D = .center,
                    amount: Float = 0,
                    start: Float = 0.45,
                    end: Float = 1.0,
                    edgeThreshold: Float = 0.2) {
            self.center = center
            self.amount = amount
            self.start = start
            self.end = end
            self.edgeThreshold = edgeThreshold
        }

        public var isIdentity: Bool {
            amount == 0
        }

        public func makeFilter() -> C7SharpnessFalloffCorrection {
            C7SharpnessFalloffCorrection(
                center: center,
                amount: amount,
                start: start,
                end: end,
                edgeThreshold: edgeThreshold
            )
        }
    }

    public func makeFilters() -> [C7FilterProtocol] {
        var filters: [C7FilterProtocol] = []
        if let profile {
            filters.append(contentsOf: profile.makeCorrectionFilters(samplingMode: samplingMode, edgeMode: edgeMode, strength: profileStrength))
        }
        if let defringe, !defringe.isIdentity {
            filters.append(defringe.makeFilter())
        }
        if let sharpnessFalloff, !sharpnessFalloff.isIdentity {
            filters.append(sharpnessFalloff.makeFilter())
        }
        return filters
    }
}
