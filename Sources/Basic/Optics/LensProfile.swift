//
//  LensProfile.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 光学校正 profile 数据模型。
///
/// 这里只承载镜头数据，不负责编译和执行。实际的 optics 入口由 `OpticsRecipe` 提供。
public struct LensProfile: Codable, Equatable, Hashable {

    public struct Distortion: Codable, Equatable, Hashable {
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

        var isIdentity: Bool {
            sanitizedFinite(distortion, fallback: 0) == 0
            && sanitizedFinite(cubicDistortion, fallback: 0) == 0
            && sanitizedFinite(scale, fallback: 1) == 1
        }

        func normalized() -> Distortion {
            Distortion(
                center: center.normalized(),
                distortion: sanitizedFinite(distortion, fallback: 0),
                cubicDistortion: sanitizedFinite(cubicDistortion, fallback: 0),
                scale: sanitizedFinite(scale, fallback: 1)
            )
        }

        func makeFilter(samplingMode: SpatialSamplingMode, edgeMode: SpatialEdgeMode, strength: Float) -> C7LensDistortionCorrection {
            C7LensDistortionCorrection(
                center: center.normalized(),
                distortion: sanitizedFinite(distortion, fallback: 0) * strength,
                cubicDistortion: sanitizedFinite(cubicDistortion, fallback: 0) * strength,
                scale: 1 + (sanitizedFinite(scale, fallback: 1) - 1) * strength,
                samplingMode: samplingMode,
                edgeMode: edgeMode
            )
        }

        var fingerprint: String {
            [
                "center=\(center.normalized().fingerprint)",
                "distortion=\(stableFloatDescription(distortion))",
                "cubic=\(stableFloatDescription(cubicDistortion))",
                "scale=\(stableFloatDescription(scale))"
            ].joined(separator: ",")
        }
    }

    public struct ChromaticAberration: Codable, Equatable, Hashable {
        public var center: C7Point2D
        public var redCyanShift: Float
        public var blueYellowShift: Float

        public init(center: C7Point2D = .center, redCyanShift: Float = 0, blueYellowShift: Float = 0) {
            self.center = center
            self.redCyanShift = redCyanShift
            self.blueYellowShift = blueYellowShift
        }

        var isIdentity: Bool {
            sanitizedFinite(redCyanShift, fallback: 0) == 0
            && sanitizedFinite(blueYellowShift, fallback: 0) == 0
        }

        func normalized() -> ChromaticAberration {
            ChromaticAberration(
                center: center.normalized(),
                redCyanShift: sanitizedFinite(redCyanShift, fallback: 0),
                blueYellowShift: sanitizedFinite(blueYellowShift, fallback: 0)
            )
        }

        func makeFilter(samplingMode: SpatialSamplingMode, edgeMode: SpatialEdgeMode, strength: Float) -> C7ChromaticAberrationCorrection {
            C7ChromaticAberrationCorrection(
                center: center.normalized(),
                redCyanShift: sanitizedFinite(redCyanShift, fallback: 0) * strength,
                blueYellowShift: sanitizedFinite(blueYellowShift, fallback: 0) * strength,
                samplingMode: samplingMode,
                edgeMode: edgeMode
            )
        }

        var fingerprint: String {
            [
                "center=\(center.normalized().fingerprint)",
                "redCyan=\(stableFloatDescription(redCyanShift))",
                "blueYellow=\(stableFloatDescription(blueYellowShift))"
            ].joined(separator: ",")
        }
    }

    public struct Vignette: Codable, Equatable, Hashable {
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

        var isIdentity: Bool {
            sanitizedFinite(amount, fallback: 0) == 0
        }

        func normalized() -> Vignette {
            Vignette(
                center: center.normalized(),
                amount: sanitizedNonNegative(amount, fallback: 0),
                start: sanitizedNonNegative(start, fallback: 0.35),
                end: sanitizedNonNegative(end, fallback: 1.0)
            )
        }

        func makeFilter(strength: Float) -> C7LensVignetteCorrection {
            C7LensVignetteCorrection(
                center: center.normalized(),
                amount: sanitizedFinite(amount, fallback: 0) * strength,
                start: sanitizedNonNegative(start, fallback: 0.35),
                end: sanitizedNonNegative(end, fallback: 1.0)
            )
        }

        var fingerprint: String {
            [
                "center=\(center.normalized().fingerprint)",
                "amount=\(stableFloatDescription(amount))",
                "start=\(stableFloatDescription(start))",
                "end=\(stableFloatDescription(end))"
            ].joined(separator: ",")
        }
    }

    public struct Diffraction: Codable, Equatable, Hashable {
        public var amount: Float
        public var radius: Float
        public var edgeThreshold: Float

        public init(amount: Float = 0, radius: Float = 1, edgeThreshold: Float = 0.08) {
            self.amount = amount
            self.radius = radius
            self.edgeThreshold = edgeThreshold
        }

        var isIdentity: Bool {
            sanitizedFinite(amount, fallback: 0) == 0
        }

        func normalized() -> Diffraction {
            Diffraction(
                amount: sanitizedNonNegative(amount, fallback: 0),
                radius: sanitizedNonNegative(radius, fallback: 1),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.08)
            )
        }

        func makeFilter(strength: Float) -> C7DiffractionCorrection {
            C7DiffractionCorrection(
                amount: sanitizedFinite(amount, fallback: 0) * strength,
                radius: sanitizedNonNegative(radius, fallback: 1),
                edgeThreshold: sanitizedNonNegative(edgeThreshold, fallback: 0.08)
            )
        }

        var fingerprint: String {
            [
                "amount=\(stableFloatDescription(amount))",
                "radius=\(stableFloatDescription(radius))",
                "edge=\(stableFloatDescription(edgeThreshold))"
            ].joined(separator: ",")
        }
    }

    public var make: String
    public var model: String
    public var profileName: String
    public var distortion: Distortion?
    public var chromaticAberration: ChromaticAberration?
    public var vignette: Vignette?
    public var diffraction: Diffraction?

    internal var metadata: LensProfileMetadata?

    public init(make: String,
                model: String,
                profileName: String,
                distortion: Distortion? = nil,
                chromaticAberration: ChromaticAberration? = nil,
                vignette: Vignette? = nil,
                diffraction: Diffraction? = nil) {
        self.make = make
        self.model = model
        self.profileName = profileName
        self.distortion = distortion
        self.chromaticAberration = chromaticAberration
        self.vignette = vignette
        self.diffraction = diffraction
        self.metadata = nil
    }

    internal var isIdentity: Bool {
        (distortion?.isIdentity ?? true)
        && (chromaticAberration?.isIdentity ?? true)
        && (vignette?.isIdentity ?? true)
        && (diffraction?.isIdentity ?? true)
    }

    internal var fingerprint: String {
        [
            "make=\(make)",
            "model=\(model)",
            "profile=\(profileName)",
            "distortion=\(distortion?.fingerprint ?? "none")",
            "chromatic=\(chromaticAberration?.fingerprint ?? "none")",
            "vignette=\(vignette?.fingerprint ?? "none")",
            "diffraction=\(diffraction?.fingerprint ?? "none")",
            "metadata=\(metadata?.fingerprint ?? "none")"
        ].joined(separator: "|")
    }

    internal func normalized() -> LensProfile {
        LensProfile(
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            profileName: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
            distortion: distortion?.normalized(),
            chromaticAberration: chromaticAberration?.normalized(),
            vignette: vignette?.normalized(),
            diffraction: diffraction?.normalized()
        )
    }

    internal func isApplicable(to metadata: LensProfileMetadata?) -> Bool {
        guard let metadata else { return true }
        if metadata.sourceIdentifier.isEmpty == false {
            let sourceIdentifier = [make, model, profileName].joined(separator: " ").lowercased()
            if sourceIdentifier.contains(metadata.sourceIdentifier.lowercased()) == false {
                return false
            }
        }
        if let focalLengthRange = metadata.focalLengthRange, focalLengthRange.isEmpty {
            return false
        }
        if let apertureRange = metadata.apertureRange, apertureRange.isEmpty {
            return false
        }
        if let cropFactorRange = metadata.cropFactorRange, cropFactorRange.isEmpty {
            return false
        }
        return true
    }

    internal func makeCorrectionFilters(samplingMode: SpatialSamplingMode, edgeMode: SpatialEdgeMode, strength: Float) -> [C7FilterProtocol] {
        let normalizedStrength = max(0, sanitizedFinite(strength, fallback: 1))
        guard normalizedStrength > 0, isIdentity == false else { return [] }

        var filters: [C7FilterProtocol] = []
        if let distortion {
            filters.append(distortion.makeFilter(samplingMode: samplingMode, edgeMode: edgeMode, strength: normalizedStrength))
        }
        if let chromaticAberration {
            filters.append(chromaticAberration.makeFilter(samplingMode: samplingMode, edgeMode: edgeMode, strength: normalizedStrength))
        }
        if let vignette {
            filters.append(vignette.makeFilter(strength: normalizedStrength))
        }
        if let diffraction {
            filters.append(diffraction.makeFilter(strength: normalizedStrength))
        }
        return filters
    }
}

internal struct LensProfileMetadata: Codable, Equatable, Hashable {
    var profileVersion: String
    var sourceIdentifier: String
    var focalLengthRange: ClosedRange<Float>?
    var apertureRange: ClosedRange<Float>?
    var sensorFormat: String?
    var cropFactorRange: ClosedRange<Float>?
    var confidence: LensProfileConfidence

    var fingerprint: String {
        [
            "version=\(profileVersion)",
            "source=\(sourceIdentifier)",
            "focal=\(focalLengthRange?.fingerprint ?? "none")",
            "aperture=\(apertureRange?.fingerprint ?? "none")",
            "sensor=\(sensorFormat ?? "none")",
            "crop=\(cropFactorRange?.fingerprint ?? "none")",
            "confidence=\(confidence.rawValue)"
        ].joined(separator: "|")
    }
}

internal enum LensProfileConfidence: String, Codable, Hashable {
    case low
    case medium
    case high
}

private extension ClosedRange where Bound == Float {
    var isEmpty: Bool {
        lowerBound > upperBound
    }

    var fingerprint: String {
        "\(stableFloatDescription(lowerBound))...\(stableFloatDescription(upperBound))"
    }
}

private func sanitizedFinite(_ value: Float, fallback: Float) -> Float {
    value.isFinite ? value : fallback
}

private func sanitizedNonNegative(_ value: Float, fallback: Float) -> Float {
    max(0, sanitizedFinite(value, fallback: fallback))
}

private func stableFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), sanitizedFinite(value, fallback: 0))
}
