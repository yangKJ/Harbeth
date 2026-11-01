//
//  ImageContentHasher.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import Foundation

/// Stable FNV-1a fingerprints for image bytes and derived caches; not a security identity.
public struct ImageContentHasher: Sendable {
    public private(set) var value: UInt64

    public init(seed: UInt64 = 0) { value = 0xCBF2_9CE4_8422_2325 ^ seed }

    public mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= 0x0000_0100_0000_01B3
    }

    public mutating func combine(littleEndian integer: UInt64) {
        let bytes = integer.littleEndian
        withUnsafeBytes(of: bytes) { buffer in
            for byte in buffer { combine(byte) }
        }
    }

    public static func hash(_ string: String, seed: UInt64 = 0) -> UInt64 {
        var hasher = Self(seed: seed)
        for byte in string.utf8 { hasher.combine(byte) }
        return hasher.value
    }
}
