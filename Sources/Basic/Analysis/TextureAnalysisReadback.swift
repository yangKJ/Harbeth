//
//  TextureAnalysisReadback.swift
//  Harbeth
//
//  Created by Condy on 2026/8/6.
//

import Foundation
import Metal

/// Analysis 的 CPU 读取视图。
///
/// 数值保持纹理存储域：不会隐式执行色域转换、transfer function 解码或 alpha 解预乘。
/// 单通道纹理展开为灰度 RGB，双通道纹理展开为 RG01。
struct TextureAnalysisReadback {
    let data: Data
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let pixelFormat: MTLPixelFormat

    init?(texture: MTLTexture) {
        guard texture.width > 0,
              texture.height > 0,
              let bytesPerPixel = Self.bytesPerPixel(for: texture.pixelFormat) else {
            return nil
        }
        let bytesPerRow = texture.width * bytesPerPixel
        var data = Data(count: bytesPerRow * texture.height)
        let copied = data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            return texture.c7.copyBytes(to: baseAddress, bytesPerRow: bytesPerRow)
        }
        guard copied else { return nil }
        self.data = data
        self.width = texture.width
        self.height = texture.height
        self.bytesPerRow = bytesPerRow
        self.pixelFormat = texture.pixelFormat
    }

    func color(x: Int, y: Int) -> SIMD4<Float>? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        let rowOffset = y * bytesPerRow
        return data.withUnsafeBytes { rawBuffer in
            switch pixelFormat {
            case .a8Unorm:
                let alpha = Float(rawBuffer[rowOffset + x]) / 255
                return SIMD4(0, 0, 0, alpha)
            case .r8Unorm:
                let value = Float(rawBuffer[rowOffset + x]) / 255
                return SIMD4(value, value, value, 1)
            case .rg8Unorm:
                let offset = rowOffset + x * 2
                return SIMD4(Float(rawBuffer[offset]) / 255, Float(rawBuffer[offset + 1]) / 255, 0, 1)
            case .rgba8Unorm, .rgba8Unorm_srgb:
                let offset = rowOffset + x * 4
                return SIMD4(
                    Float(rawBuffer[offset]) / 255,
                    Float(rawBuffer[offset + 1]) / 255,
                    Float(rawBuffer[offset + 2]) / 255,
                    Float(rawBuffer[offset + 3]) / 255
                )
            case .bgra8Unorm, .bgra8Unorm_srgb:
                let offset = rowOffset + x * 4
                return SIMD4(
                    Float(rawBuffer[offset + 2]) / 255,
                    Float(rawBuffer[offset + 1]) / 255,
                    Float(rawBuffer[offset]) / 255,
                    Float(rawBuffer[offset + 3]) / 255
                )
            case .r16Float:
                let value = Self.float16(rawBuffer, offset: rowOffset + x * 2)
                return SIMD4(value, value, value, 1)
            case .rg16Float:
                let offset = rowOffset + x * 4
                return SIMD4(Self.float16(rawBuffer, offset: offset), Self.float16(rawBuffer, offset: offset + 2), 0, 1)
            case .rgba16Float:
                let offset = rowOffset + x * 8
                return SIMD4(
                    Self.float16(rawBuffer, offset: offset),
                    Self.float16(rawBuffer, offset: offset + 2),
                    Self.float16(rawBuffer, offset: offset + 4),
                    Self.float16(rawBuffer, offset: offset + 6)
                )
            case .r32Float:
                let value = Self.float32(rawBuffer, offset: rowOffset + x * 4)
                return SIMD4(value, value, value, 1)
            case .rg32Float:
                let offset = rowOffset + x * 8
                return SIMD4(Self.float32(rawBuffer, offset: offset), Self.float32(rawBuffer, offset: offset + 4), 0, 1)
            case .rgba32Float:
                let offset = rowOffset + x * 16
                return SIMD4(
                    Self.float32(rawBuffer, offset: offset),
                    Self.float32(rawBuffer, offset: offset + 4),
                    Self.float32(rawBuffer, offset: offset + 8),
                    Self.float32(rawBuffer, offset: offset + 12)
                )
            default:
                return nil
            }
        }
    }

    private static func bytesPerPixel(for pixelFormat: MTLPixelFormat) -> Int? {
        switch pixelFormat {
        case .a8Unorm, .r8Unorm: return 1
        case .rg8Unorm, .r16Float: return 2
        case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb, .rg16Float, .r32Float: return 4
        case .rgba16Float, .rg32Float: return 8
        case .rgba32Float: return 16
        default: return nil
        }
    }

    private static func float16(_ buffer: UnsafeRawBufferPointer, offset: Int) -> Float {
        let bits = UInt16(littleEndian: buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        return Float(Float16(bitPattern: bits))
    }

    private static func float32(_ buffer: UnsafeRawBufferPointer, offset: Int) -> Float {
        let bits = UInt32(littleEndian: buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        return Float(bitPattern: bits)
    }
}
