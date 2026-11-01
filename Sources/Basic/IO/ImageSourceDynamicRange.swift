//
//  ImageSourceDynamicRange.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import CoreImage

/// Decoding intent for an encoded original. SDR editing prefers its native SDR representation.
/// Gain maps are not expanded and recompressed; the system maps standalone PQ/HLG sources to SDR.
/// Soft-proofing an edited HDR master uses output mapping, not these source decoding options.
public enum ImageSourceDynamicRange: Sendable {
    case standard
    case preserve

    public var decodingOptions: [CIImageOption: Any] {
        var options: [CIImageOption: Any] = [
            .applyOrientationProperty: true,
            .cacheImmediately: false,
            .toneMapHDRtoSDR: self == .standard
        ]
        if #available(iOS 17, macOS 14, tvOS 17, *) {
            options[.expandToHDR] = self == .preserve
        }
        return options
    }
}
