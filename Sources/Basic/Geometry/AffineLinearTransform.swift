//
//  AffineLinearTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/10/13.
//

import CoreGraphics
import Foundation

/// A translation-free 2D linear transform. Consumers own coordinate origins and object layout.
public struct AffineLinearTransform: Codable, Equatable, Sendable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public static let identity = try! Self(a: 1, b: 0, c: 0, d: 1)
    public var isIdentity: Bool { self == .identity }
    public var cgAffineTransform: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: 0, ty: 0) }
    public enum Error: Swift.Error { case invalidMatrix }

    public init(a: Double, b: Double, c: Double, d: Double) throws {
        let determinant = a * d - b * c
        guard [a, b, c, d].allSatisfy(\.isFinite), determinant.isFinite, abs(determinant) > 1e-12 else {
            throw Error.invalidMatrix
        }
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        let inverse = cgAffineTransform.inverted()
        guard [inverse.a, inverse.b, inverse.c, inverse.d].allSatisfy(\.isFinite) else { throw Error.invalidMatrix }
    }

    public init(_ value: CGAffineTransform) throws {
        guard value.tx == 0, value.ty == 0 else { throw Error.invalidMatrix }
        try self.init(a: Double(value.a), b: Double(value.b), c: Double(value.c), d: Double(value.d))
    }

    public func concatenating(_ other: Self) throws -> Self {
        try Self(cgAffineTransform.concatenating(other.cgAffineTransform))
    }

    public func inverted() throws -> Self { try Self(cgAffineTransform.inverted()) }

    private enum CodingKeys: String, CodingKey { case a, b, c, d }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            a: values.decode(Double.self, forKey: .a),
            b: values.decode(Double.self, forKey: .b),
            c: values.decode(Double.self, forKey: .c),
            d: values.decode(Double.self, forKey: .d)
        )
    }
}
