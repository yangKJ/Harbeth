//
//  RGBA8ImageBuffer.swift
//  Harbeth
//
//  Created by Condy on 2026/10/10.
//

import CoreGraphics
import Foundation

public struct RGBA8ImageBuffer {
    public let width: Int
    public let height: Int
    public var bytes: [UInt8]
    public let colorSpace: CGColorSpace

    public init(_ image: CGImage, maximumPixels: Int = 4_194_304) throws {
        guard image.width > 0, image.height > 0, image.width <= maximumPixels / image.height else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "RGBA8ImageBuffer", reason: "invalidImage")
        }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: RGBA8ImageBuffer.bitmapInfo
        ) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "RGBA8ImageBuffer", reason: "invalidImage")
        }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        self.width = image.width
        self.height = image.height
        self.bytes = bytes
        self.colorSpace = colorSpace
    }

    public init(width: Int, height: Int, bytes: [UInt8], colorSpace: CGColorSpace) throws {
        guard width > 0, height > 0, width <= Int.max / height / 4, bytes.count == width * height * 4 else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "RGBA8ImageBuffer", reason: "invalidImage")
        }
        self.width = width
        self.height = height
        self.bytes = bytes
        self.colorSpace = colorSpace
    }

    public func makeCGImage() throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "RGBA8ImageBuffer", reason: "invalidImage")
        }
        return image
    }

    private static let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
}
