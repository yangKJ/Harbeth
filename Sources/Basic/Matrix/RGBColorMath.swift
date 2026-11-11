//
//  RGBColorMath.swift
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

import Foundation

/// The transfer function and primaries used by scalar RGB/OKLab conversions.
public enum RGBColorSpace: Int, CaseIterable, Codable, Sendable {
    case sRGB, displayP3, linearSRGB, linearDisplayP3
}

/// Pure colorimetric transforms. No gamut clipping, tone mapping, or matching policy is applied.
public enum RGBColorMath {
    public static func oklab(_ rgb: SIMD3<Float>, space: RGBColorSpace) -> SIMD3<Float> {
        var v = rgb
        if space == .sRGB || space == .displayP3 { v = SIMD3(decode(v.x), decode(v.y), decode(v.z)) }
        if space == .displayP3 || space == .linearDisplayP3 {
            v = SIMD3(
                1.224745 * v.x - 0.224904 * v.y,
                -0.042058 * v.x + 1.042081 * v.y,
                -0.019642 * v.x - 0.078655 * v.y + 1.098537 * v.z
            )
        }
        let l = cbrtf(0.4122214708 * v.x + 0.5363325363 * v.y + 0.0514459929 * v.z)
        let m = cbrtf(0.2119034982 * v.x + 0.6806995451 * v.y + 0.1073969566 * v.z)
        let s = cbrtf(0.0883024619 * v.x + 0.2817188376 * v.y + 0.6299787005 * v.z)
        return SIMD3(
            0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
        )
    }

    public static func rgb(fromOKLab lab: SIMD3<Float>, space: RGBColorSpace) -> SIMD3<Float> {
        let l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z
        let m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z
        let s = lab.x - 0.0894841775 * lab.y - 1.291485548 * lab.z
        var v = SIMD3(
            4.0767416621 * l * l * l - 3.3077115913 * m * m * m + 0.2309699292 * s * s * s,
            -1.2684380046 * l * l * l + 2.6097574011 * m * m * m - 0.3413193965 * s * s * s,
            -0.0041960863 * l * l * l - 0.7034186147 * m * m * m + 1.707614701 * s * s * s
        )
        if space == .displayP3 || space == .linearDisplayP3 {
            v = SIMD3(
                0.822593 * v.x + 0.177534 * v.y,
                0.033200 * v.x + 0.966783 * v.y,
                0.017085 * v.x + 0.072396 * v.y + 0.910302 * v.z
            )
        }
        if space == .sRGB || space == .displayP3 { v = SIMD3(encode(v.x), encode(v.y), encode(v.z)) }
        return v
    }

    private static func decode(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func encode(_ v: Float) -> Float { v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055 }
}
