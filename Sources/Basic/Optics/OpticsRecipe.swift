//
//  OpticsRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/9.
//

import Foundation

public struct OpticsRecipe: Codable, Equatable, Hashable {

    public enum Correction: Codable, Equatable, Hashable {
        case profile(LensProfile, strength: Float)
        case defringe(Defringe)
        case sharpnessFalloff(SharpnessFalloff)

        var sortPriority: Int {
            switch self {
            case .profile:
                return 0
            case .defringe:
                return 1
            case .sharpnessFalloff:
                return 2
            }
        }

        var isIdentity: Bool {
            switch self {
            case .profile(let profile, let strength):
                return profile.isIdentity || Self.sanitizedStrength(strength) == 0
            case .defringe(let defringe):
                return defringe.isIdentity
            case .sharpnessFalloff(let sharpnessFalloff):
                return sharpnessFalloff.isIdentity
            }
        }

        func normalized() -> Correction {
            switch self {
            case .profile(let profile, let strength):
                return .profile(profile.normalized(), strength: Self.sanitizedStrength(strength))
            case .defringe(let defringe):
                return .defringe(defringe.normalized())
            case .sharpnessFalloff(let sharpnessFalloff):
                return .sharpnessFalloff(sharpnessFalloff.normalized())
            }
        }

        func makeFilters(samplingMode: SpatialSamplingMode, edgeMode: SpatialEdgeMode) -> [C7FilterProtocol] {
            switch self {
            case .profile(let profile, let strength):
                return profile.makeCorrectionFilters(samplingMode: samplingMode, edgeMode: edgeMode, strength: Self.sanitizedStrength(strength))
            case .defringe(let defringe):
                return defringe.isIdentity ? [] : [defringe.makeFilter()]
            case .sharpnessFalloff(let sharpnessFalloff):
                return sharpnessFalloff.isIdentity ? [] : [sharpnessFalloff.makeFilter()]
            }
        }

        var fingerprint: String {
            switch self {
            case .profile(let profile, let strength):
                return "profile(\(profile.fingerprint)):strength=\(stableFloatDescription(Self.sanitizedStrength(strength)))"
            case .defringe(let defringe):
                return "defringe(\(defringe.fingerprint))"
            case .sharpnessFalloff(let sharpnessFalloff):
                return "sharpnessFalloff(\(sharpnessFalloff.fingerprint))"
            }
        }

        private static func sanitizedStrength(_ strength: Float) -> Float {
            max(0, strength.isFinite ? strength : 1)
        }
    }

    public struct Defringe: Codable, Equatable, Hashable {
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

        var isIdentity: Bool {
            sanitizedAmount(purpleAmount) == 0 && sanitizedAmount(greenAmount) == 0
        }

        func normalized() -> Defringe {
            Defringe(
                purpleAmount: sanitizedAmount(purpleAmount),
                purpleHueStart: sanitizedFinite(purpleHueStart, fallback: 250),
                purpleHueEnd: sanitizedFinite(purpleHueEnd, fallback: 320),
                greenAmount: sanitizedAmount(greenAmount),
                greenHueStart: sanitizedFinite(greenHueStart, fallback: 90),
                greenHueEnd: sanitizedFinite(greenHueEnd, fallback: 170),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.08),
                saturationThreshold: sanitizedNonNegative(saturationThreshold, fallback: 0.15)
            )
        }

        func makeFilter() -> C7DefringeCorrection {
            C7DefringeCorrection(
                purpleAmount: sanitizedAmount(purpleAmount),
                purpleHueStart: sanitizedFinite(purpleHueStart, fallback: 250),
                purpleHueEnd: sanitizedFinite(purpleHueEnd, fallback: 320),
                greenAmount: sanitizedAmount(greenAmount),
                greenHueStart: sanitizedFinite(greenHueStart, fallback: 90),
                greenHueEnd: sanitizedFinite(greenHueEnd, fallback: 170),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.08),
                saturationThreshold: sanitizedNonNegative(saturationThreshold, fallback: 0.15)
            )
        }

        var fingerprint: String {
            [
                "purpleAmount=\(stableFloatDescription(sanitizedAmount(purpleAmount)))",
                "purpleHue=\(stableFloatDescription(sanitizedFinite(purpleHueStart, fallback: 250)))-\(stableFloatDescription(sanitizedFinite(purpleHueEnd, fallback: 320)))",
                "greenAmount=\(stableFloatDescription(sanitizedAmount(greenAmount)))",
                "greenHue=\(stableFloatDescription(sanitizedFinite(greenHueStart, fallback: 90)))-\(stableFloatDescription(sanitizedFinite(greenHueEnd, fallback: 170)))",
                "edge=\(stableFloatDescription(sanitizedNonNegative(edgeThreshold, fallback: 0.08)))",
                "sat=\(stableFloatDescription(sanitizedNonNegative(saturationThreshold, fallback: 0.15)))"
            ].joined(separator: ",")
        }
    }

    public struct SharpnessFalloff: Codable, Equatable, Hashable {
        public var center: C7Point2D
        public var amount: Float
        public var start: Float
        public var end: Float
        public var edgeThreshold: Float

        public init(center: C7Point2D = .center, amount: Float = 0, start: Float = 0.45, end: Float = 1.0, edgeThreshold: Float = 0.2) {
            self.center = center
            self.amount = amount
            self.start = start
            self.end = end
            self.edgeThreshold = edgeThreshold
        }

        var isIdentity: Bool {
            sanitizedAmount(amount) == 0
        }

        func normalized() -> SharpnessFalloff {
            SharpnessFalloff(
                center: center.normalized(),
                amount: sanitizedAmount(amount),
                start: sanitizedNonNegative(start, fallback: 0.45),
                end: sanitizedNonNegative(end, fallback: 1.0),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.2)
            )
        }

        func makeFilter() -> C7SharpnessFalloffCorrection {
            C7SharpnessFalloffCorrection(
                center: center.normalized(),
                amount: sanitizedAmount(amount),
                start: sanitizedNonNegative(start, fallback: 0.45),
                end: sanitizedNonNegative(end, fallback: 1.0),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.2)
            )
        }

        var fingerprint: String {
            [
                "center=\(center.normalized().fingerprint)",
                "amount=\(stableFloatDescription(sanitizedAmount(amount)))",
                "start=\(stableFloatDescription(sanitizedNonNegative(start, fallback: 0.45)))",
                "end=\(stableFloatDescription(sanitizedNonNegative(end, fallback: 1.0)))",
                "edge=\(stableFloatDescription(sanitizedNonNegative(edgeThreshold, fallback: 0.2)))"
            ].joined(separator: ",")
        }
    }

    public var corrections: [Correction]
    public var samplingMode: SpatialSamplingMode
    public var edgeMode: SpatialEdgeMode

    public init(corrections: [Correction] = [],
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent) {
        self.corrections = corrections
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
    }

    public static func profile(_ profile: LensProfile,
                               strength: Float = 1,
                               samplingMode: SpatialSamplingMode = .adaptive,
                               edgeMode: SpatialEdgeMode = .transparent) -> OpticsRecipe {
        OpticsRecipe(corrections: [.profile(profile, strength: strength)], samplingMode: samplingMode, edgeMode: edgeMode)
    }

    public static func defringe(_ defringe: Defringe,
                                samplingMode: SpatialSamplingMode = .adaptive,
                                edgeMode: SpatialEdgeMode = .transparent) -> OpticsRecipe {
        OpticsRecipe(corrections: [.defringe(defringe)], samplingMode: samplingMode, edgeMode: edgeMode)
    }

    public static func sharpnessFalloff(_ sharpnessFalloff: SharpnessFalloff,
                                        samplingMode: SpatialSamplingMode = .adaptive,
                                        edgeMode: SpatialEdgeMode = .transparent) -> OpticsRecipe {
        OpticsRecipe(corrections: [.sharpnessFalloff(sharpnessFalloff)], samplingMode: samplingMode, edgeMode: edgeMode)
    }

    public func adding(_ correction: Correction) -> OpticsRecipe {
        var copy = self
        copy.corrections.append(correction)
        return copy
    }

    public func adding(_ corrections: [Correction]) -> OpticsRecipe {
        var copy = self
        copy.corrections.append(contentsOf: corrections)
        return copy
    }

    internal var isIdentity: Bool {
        compile().isIdentity
    }

    internal var fingerprint: String {
        compile().fingerprint
    }

    internal func normalized() -> OpticsRecipe {
        let compiled = compile()
        return OpticsRecipe(corrections: compiled.corrections, samplingMode: samplingMode, edgeMode: edgeMode)
    }

    internal func makeFilters() -> [C7FilterProtocol] {
        compile().filters
    }

    internal func compile() -> CompiledOpticsRecipe {
        let normalizedCorrections = corrections
            .enumerated()
            .map { index, correction in (index: index, correction: correction.normalized()) }
            .filter { !$0.correction.isIdentity }
            .sorted {
                if $0.correction.sortPriority == $1.correction.sortPriority {
                    return $0.index < $1.index
                }
                return $0.correction.sortPriority < $1.correction.sortPriority
            }

        let compiledCorrections = normalizedCorrections.map(\.correction)
        let filters = compiledCorrections.flatMap { $0.makeFilters(samplingMode: samplingMode, edgeMode: edgeMode) }
        let fingerprint = [
            "sampling=\(samplingMode.rawValue)",
            "edge=\(edgeMode.rawValue)",
            compiledCorrections.isEmpty ? "none" : compiledCorrections.map(\.fingerprint).joined(separator: "||")
        ].joined(separator: "|")
        return CompiledOpticsRecipe(corrections: compiledCorrections, filters: filters, fingerprint: fingerprint)
    }
}

internal struct CompiledOpticsRecipe {
    let corrections: [OpticsRecipe.Correction]
    let filters: [C7FilterProtocol]
    let fingerprint: String

    var isIdentity: Bool {
        filters.isEmpty
    }
}

private func sanitizedFinite(_ value: Float, fallback: Float) -> Float {
    value.isFinite ? value : fallback
}

private func sanitizedAmount(_ value: Float) -> Float {
    max(0, sanitizedFinite(value, fallback: 0))
}

private func sanitizedNonNegative(_ value: Float, fallback: Float) -> Float {
    max(0, sanitizedFinite(value, fallback: fallback))
}

private func stableFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), sanitizedFinite(value, fallback: 0))
}
