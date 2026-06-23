//
//  TextureAnalysisScope.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public enum TextureToneBand: String, Sendable, Codable, Equatable, Hashable {
    case shadows
    case midtones
    case highlights
}

public struct TextureComponentRange: Sendable, Equatable, Hashable {
    public let minimum: Float
    public let maximum: Float
    public let wrapsAroundUnit: Bool

    public init(minimum: Float, maximum: Float, wrapsAroundUnit: Bool = false) {
        let clampedMinimum = min(max(minimum, 0), 1)
        let clampedMaximum = min(max(maximum, 0), 1)
        self.minimum = clampedMinimum
        self.maximum = clampedMaximum
        self.wrapsAroundUnit = wrapsAroundUnit
    }

    public func contains(_ value: Float) -> Bool {
        let clampedValue = min(max(value, 0), 1)
        if wrapsAroundUnit {
            return clampedValue >= minimum || clampedValue <= maximum
        }
        return clampedValue >= min(minimum, maximum) && clampedValue <= max(minimum, maximum)
    }

    public var fingerprint: String {
        "min=\(String(format: "%.4f", minimum))|max=\(String(format: "%.4f", maximum))|wrap=\(wrapsAroundUnit ? 1 : 0)"
    }
}

public struct TextureColorRange: Sendable, Equatable, Hashable {
    public let hue: TextureComponentRange?
    public let saturation: TextureComponentRange?
    public let lightness: TextureComponentRange?

    public init(hue: TextureComponentRange? = nil, saturation: TextureComponentRange? = nil, lightness: TextureComponentRange? = nil) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    public func contains(red: Float, green: Float, blue: Float) -> Bool {
        let hsl = TextureHSLColor(red: red, green: green, blue: blue)
        if let hue, hue.contains(hsl.hue) == false {
            return false
        }
        if let saturation, saturation.contains(hsl.saturation) == false {
            return false
        }
        if let lightness, lightness.contains(hsl.lightness) == false {
            return false
        }
        return true
    }

    public var fingerprint: String {
        [
            "hue=\(hue?.fingerprint ?? "none")",
            "saturation=\(saturation?.fingerprint ?? "none")",
            "lightness=\(lightness?.fingerprint ?? "none")"
        ].joined(separator: "|")
    }
}

public struct TextureLuminanceRange: Sendable, Equatable, Hashable {
    public let minimum: Float
    public let maximum: Float

    public init(minimum: Float, maximum: Float) {
        let clampedMinimum = min(max(minimum, 0), 1)
        let clampedMaximum = min(max(maximum, 0), 1)
        self.minimum = min(clampedMinimum, clampedMaximum)
        self.maximum = max(clampedMinimum, clampedMaximum)
    }

    public func contains(_ luminance: Float) -> Bool {
        luminance >= minimum && luminance <= maximum
    }

    public static func toneBand(_ band: TextureToneBand) -> TextureLuminanceRange {
        switch band {
        case .shadows:
            return TextureLuminanceRange(minimum: 0.0, maximum: 0.33)
        case .midtones:
            return TextureLuminanceRange(minimum: 0.2, maximum: 0.8)
        case .highlights:
            return TextureLuminanceRange(minimum: 0.66, maximum: 1.0)
        }
    }

    public var fingerprint: String {
        "min=\(String(format: "%.4f", minimum))|max=\(String(format: "%.4f", maximum))"
    }
}

public struct TextureAnalysisScope: @unchecked Sendable, Equatable {
    public let region: MTLRegion?
    public let mask: MaskDescriptor?
    public let luminanceRange: TextureLuminanceRange?
    public let colorRange: TextureColorRange?
    public let coverageThreshold: Float

    public init(region: MTLRegion? = nil,
                mask: MaskDescriptor? = nil,
                luminanceRange: TextureLuminanceRange? = nil,
                colorRange: TextureColorRange? = nil,
                coverageThreshold: Float = 0.5) {
        self.region = region
        self.mask = mask
        self.luminanceRange = luminanceRange
        self.colorRange = colorRange
        self.coverageThreshold = min(max(coverageThreshold, 0), 1)
    }

    public static func region(_ region: MTLRegion) -> TextureAnalysisScope {
        TextureAnalysisScope(region: region)
    }

    public static func mask(_ mask: MaskDescriptor, coverageThreshold: Float = 0.5) -> TextureAnalysisScope {
        TextureAnalysisScope(mask: mask, coverageThreshold: coverageThreshold)
    }

    public static func luminanceRange(_ range: TextureLuminanceRange) -> TextureAnalysisScope {
        TextureAnalysisScope(luminanceRange: range)
    }

    public static func colorRange(_ range: TextureColorRange) -> TextureAnalysisScope {
        TextureAnalysisScope(colorRange: range)
    }

    public static func toneBand(_ band: TextureToneBand) -> TextureAnalysisScope {
        TextureAnalysisScope(luminanceRange: .toneBand(band))
    }

    public var fingerprint: String {
        [
            "region=\(regionFingerprint ?? "none")",
            "mask=\(maskFingerprint ?? "none")",
            "luminance=\(luminanceRange?.fingerprint ?? "none")",
            "color=\(colorRange?.fingerprint ?? "none")",
            "threshold=\(String(format: "%.4f", coverageThreshold))"
        ].joined(separator: "|")
    }

    public static func == (lhs: TextureAnalysisScope, rhs: TextureAnalysisScope) -> Bool {
        lhs.fingerprint == rhs.fingerprint
    }

    private var regionFingerprint: String? {
        guard let region else { return nil }
        return [
            String(region.origin.x),
            String(region.origin.y),
            String(region.origin.z),
            String(region.size.width),
            String(region.size.height),
            String(region.size.depth)
        ].joined(separator: ",")
    }

    private var maskFingerprint: String? {
        guard let mask else { return nil }
        return [
            "texture=\(ObjectIdentifier(mask.texture).hashValue)",
            "component=\(mask.component.rawValue)",
            "blend=\(mask.blendMode.rawValue)",
            "invert=\(mask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", mask.opacity))",
            "feather=\(mask.featherPolicy.amount)"
        ].joined(separator: ",")
    }
}

internal struct TextureHSLColor {
    let hue: Float
    let saturation: Float
    let lightness: Float

    init(red: Float, green: Float, blue: Float) {
        let maximum = max(red, max(green, blue))
        let minimum = min(red, min(green, blue))
        let delta = maximum - minimum
        let lightness = (maximum + minimum) * 0.5

        let saturation: Float
        if delta == 0 {
            saturation = 0
        } else {
            saturation = delta / max(0.000001, 1 - abs(2 * lightness - 1))
        }

        let hueDegrees: Float
        if delta == 0 {
            hueDegrees = 0
        } else if maximum == red {
            hueDegrees = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        } else if maximum == green {
            hueDegrees = 60 * (((blue - red) / delta) + 2)
        } else {
            hueDegrees = 60 * (((red - green) / delta) + 4)
        }

        let normalizedHue = (hueDegrees < 0 ? hueDegrees + 360 : hueDegrees) / 360
        self.hue = min(max(normalizedHue, 0), 1)
        self.saturation = min(max(saturation, 0), 1)
        self.lightness = min(max(lightness, 0), 1)
    }
}
