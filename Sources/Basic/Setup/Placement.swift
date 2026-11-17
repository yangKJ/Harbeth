//
//  Placement.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

public enum Placement: String, Codable, Sendable, Equatable, Hashable {
    /// Not scale the content.
    case fixed
    /// True to change image size to fit image size.
    case fit
    //case full
    //case stretch
}

extension Placement {
    
    public func rotate(angle: Float, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            guard angle.isFinite else { return size }
            let coefficients = Self.rotationCoefficients(angle)
            let c = abs(Double(coefficients.x)), s = abs(Double(coefficients.y))
            let w = Self.safeDimension(ceil(s * Double(size.height) + c * Double(size.width)), fallback: size.width)
            let h = Self.safeDimension(ceil(s * Double(size.width) + c * Double(size.height)), fallback: size.height)
            return C7Size(width: w, height: h)
        }
    }
    
    public func resize(width: Float, height: Float, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            let w = Self.safeDimension(Double(width), fallback: size.width)
            let h = Self.safeDimension(Double(height), fallback: size.height)
            return C7Size(width: w, height: h)
        }
    }
    
    static func rotationCoefficients(_ angle: Float) -> SIMD2<Float> {
        guard angle.isFinite else { return SIMD2(1, 0) }
        let turns = angle / (.pi / 2)
        if abs(turns - turns.rounded()) <= turns.ulp {
            let radians = Double(turns.rounded()) * .pi / 2
            return SIMD2(Float(cos(radians).rounded()), Float(sin(radians).rounded()))
        }
        return SIMD2(cos(angle), sin(angle))
    }

    static func validDimension(_ value: Double) -> Bool {
        value.isFinite && value >= 1 && value < Double(Int.max)
    }
    static func safeDimension(_ value: Double, fallback: Int) -> Int {
        guard validDimension(value) else { return fallback }
        return Int(value)
    }

    public func transform(_ transform: CGAffineTransform, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            guard [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].allSatisfy(\.isFinite) else { return size }
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)
            return C7Size(width: Self.safeDimension(Double(rect.width), fallback: size.width),
                          height: Self.safeDimension(Double(rect.height), fallback: size.height))
        }
    }
}

// 非抛错的尺寸查询保持安全，真正执行时由统一编码边界报告非法几何参数。
protocol GeometryParameterValidating {
    func validateGeometryParameters() throws
    func validateGeometryParameters(inputSize: C7Size) throws
}
extension GeometryParameterValidating {
    func validateGeometryParameters(inputSize: C7Size) throws { try validateGeometryParameters() }
}

func validateResizeDimensions(_ width: Float, _ height: Float) throws {
    for value in [width, height] where value > 0 {
        guard value.isFinite, value >= 1, Double(value) < Double(Int.max) else {
            throw HarbethError.configurationInvalid("缩放尺寸必须能表示为正整数；非正值保留原轴。")
        }
    }
}
