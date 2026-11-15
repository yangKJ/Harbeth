//
//  ImageRasterPlan.swift
//  Harbeth
//
//  Created by Condy on 2026/11/15.
//

import CoreGraphics

/// 供 CPU 位图适配使用的严格 RGB 计划；不在创建失败时回退到 8-bit 或丢弃 alpha。
public struct ImageRasterPlan {
    public let colorSpace: CGColorSpace
    public let isHighPrecision: Bool

    public init(cgImage: CGImage) {
        if let space = cgImage.colorSpace {
            colorSpace = space.model == .rgb ? space : (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
        } else {
            colorSpace = CGColorSpaceCreateDeviceRGB()
        }
        isHighPrecision = Self.requiresHighPrecision(cgImage)
    }

    /// 纹理上传可复用精度判断，同时保留自己的空间回退、行对齐及缓冲初始化。
    public static func requiresHighPrecision(_ image: CGImage) -> Bool {
        if image.bitsPerComponent > 8 || image.bitmapInfo.contains(.floatComponents) {
            return true
        }
        guard let colorSpace = image.colorSpace else { return false }
        switch ImageColorSpaceContract(colorSpace: colorSpace).dynamicRange {
        case .extendedDynamicRange, .highDynamicRange:
            return true
        case .preserveInput, .standardDynamicRange, .custom:
            return false
        }
    }

    public func makeContext(width: Int, height: Int) -> CGContext? {
        let bytesPerPixel = isHighPrecision ? 8 : 4
        guard width > 0, height > 0, width <= Int.max / bytesPerPixel,
              height <= Int.max / (width * bytesPerPixel) else { return nil }
        let bitmapInfo = isHighPrecision
            ? CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            : CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: isHighPrecision ? 16 : 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }
}
