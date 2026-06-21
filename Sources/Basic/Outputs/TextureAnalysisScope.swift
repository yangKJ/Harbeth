//
//  TextureAnalysisScope.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public struct TextureAnalysisScope: @unchecked Sendable, Equatable {
    public let region: MTLRegion?
    public let mask: MaskDescriptor?
    public let coverageThreshold: Float

    public init(region: MTLRegion? = nil,
                mask: MaskDescriptor? = nil,
                coverageThreshold: Float = 0.5) {
        self.region = region
        self.mask = mask
        self.coverageThreshold = min(max(coverageThreshold, 0), 1)
    }

    public static func region(_ region: MTLRegion) -> TextureAnalysisScope {
        TextureAnalysisScope(region: region)
    }

    public static func mask(_ mask: MaskDescriptor,
                            coverageThreshold: Float = 0.5) -> TextureAnalysisScope {
        TextureAnalysisScope(mask: mask, coverageThreshold: coverageThreshold)
    }

    public var fingerprint: String {
        [
            "region=\(regionFingerprint ?? "none")",
            "mask=\(maskFingerprint ?? "none")",
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
