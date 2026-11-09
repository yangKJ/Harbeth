//
//  ImageTIFF16Encoder.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Metal

/// Integer TIFF16 encoding. Consumers own region budgets, temporary files, and delivery.
public enum ImageTIFF16Encoder {
    /// 将纹理帧在 GPU 上量化为整数 RGBA16，仅在最终编码前读取像素。
    public static func encode(_ frame: RenderedFrame, colorSpace: CGColorSpace) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.tiff" as CFString, 1, nil) else {
            throw HarbethError.imageDestinationCreationFailed("public.tiff")
        }
        let image = try integerImage(from: frame, colorSpace: colorSpace)
        try finalizeTIFF16(image, properties: [:], destination: destination)
        return data as Data
    }

    /// Encodes explicit integer RGBA16 samples without an intermediate JPEG or 8-bit image.
    public static func encode(_ image: CIImage, colorSpace: CGColorSpace) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.tiff" as CFString, 1, nil) else {
            throw HarbethError.imageDestinationCreationFailed("public.tiff")
        }
        let bounds = image.extent.integral
        guard bounds.minX.isFinite, bounds.minY.isFinite, bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0,
              bounds.width < CGFloat(Int.max / 8), bounds.height < CGFloat(Int.max / 8) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "invalidDimensions")
        }
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        let rowBytes = width * 8
        let (byteCount, overflow) = rowBytes.multipliedReportingOverflow(by: height)
        guard !overflow else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "invalidDimensions")
        }
        var pixels = Data(count: byteCount)
        pixels.withUnsafeMutableBytes {
            HarbethContext.shared.coreImageContext.render(
                image,
                toBitmap: $0.baseAddress!,
                rowBytes: rowBytes,
                bounds: bounds,
                format: .RGBA16,
                colorSpace: colorSpace
            )
        }
        guard let provider = CGDataProvider(data: pixels as CFData),
              let integerImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 16,
                bitsPerPixel: 64,
                bytesPerRow: rowBytes,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder16Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw HarbethError.imageEncodingFailed("public.tiff")
        }
        try finalizeTIFF16(integerImage, properties: image.properties, destination: destination)
        return data as Data
    }

    /// Writes through ImageIO without allocating an intermediate full TIFF Data value.
    public static func write(_ image: CGImage, to url: URL, printResolution: ImagePrintResolution? = nil) throws {
        guard image.bitsPerComponent == 16, image.bitsPerPixel == 64,
              !image.bitmapInfo.contains(.floatComponents) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "integerRGBA16Required")
        }
        guard url.isFileURL,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.tiff" as CFString, 1, nil) else {
            throw HarbethError.imageDestinationCreationFailed("public.tiff")
        }
        var properties: [String: Any] = [:]
        if let printResolution {
            properties[kCGImagePropertyDPIWidth as String] = printResolution.horizontalDPI
            properties[kCGImagePropertyDPIHeight as String] = printResolution.verticalDPI
        }
        try finalizeTIFF16(image, properties: properties, destination: destination)
    }

    /// 将纹理帧在 GPU 上量化，然后由 ImageIO 写出整数 TIFF16。
    public static func write(_ frame: RenderedFrame, to url: URL,
                             colorSpace: CGColorSpace, printResolution: ImagePrintResolution? = nil) throws {
        let image = try integerImage(from: frame, colorSpace: colorSpace)
        try write(image, to: url, printResolution: printResolution)
    }

    private static func integerImage(from frame: RenderedFrame, colorSpace: CGColorSpace) throws -> CGImage {
        guard colorSpace.model == .rgb, colorSpace.numberOfComponents == 3 else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "rgbColorSpaceRequired")
        }
        let colorFrame: RenderedFrame
        if let sourceColorSpace = frame.colorSpace, !CFEqual(sourceColorSpace, colorSpace) {
            colorFrame = try frame.converted(to: colorSpace)
        } else {
            colorFrame = frame
        }
        let source = colorFrame.alphaType == .nonPremultiplied
            ? try colorFrame.converted(to: RenderOutputContract(alpha: .premultiplied)) : colorFrame
        let texture = source.texture
        guard texture.device === HarbethContext.shared.device,
              texture.width > 0, texture.height > 0, texture.width <= Int.max / 8,
              texture.pixelFormat == .rgba8Unorm || texture.pixelFormat == .bgra8Unorm ||
              texture.pixelFormat == .rgba16Float || texture.pixelFormat == .rgba32Float else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "unsupportedTexture")
        }
        let rowBytes = texture.width * 8
        let (byteCount, overflow) = rowBytes.multipliedReportingOverflow(by: texture.height)
        guard !overflow else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageTIFF16Encoder", reason: "invalidDimensions")
        }
        let pipeline = try Compute.makeComputePipelineState(with: "imageTIFF16Quantize")
        guard let buffer = texture.device.makeBuffer(length: byteCount, options: .storageModeShared),
              let command = HarbethContext.shared.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else {
            throw HarbethError.makeTexture
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        let threads = MTLSize(width: 8, height: 8, depth: 1)
        encoder.dispatchThreads(MTLSize(width: texture.width, height: texture.height, depth: 1), threadsPerThreadgroup: threads)
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: "ImageTIFF16Encoder")

        let pixels = Data(bytes: buffer.contents(), count: byteCount)
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(
                width: texture.width, height: texture.height,
                bitsPerComponent: 16, bitsPerPixel: 64, bytesPerRow: rowBytes,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder16Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else {
            throw HarbethError.imageEncodingFailed("public.tiff")
        }
        return image
    }

    private static func finalizeTIFF16(_ image: CGImage, properties: [String: Any], destination: CGImageDestination) throws {
        // Require integer samples so Core Image or deferred providers cannot pass through half-float data.
        guard image.bitsPerComponent == 16, image.bitsPerPixel == 64,
              !image.bitmapInfo.contains(.floatComponents) else {
            throw HarbethError.imageEncodingFailed("public.tiff")
        }
        var properties = properties
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff[kCGImagePropertyTIFFCompression as String] = 1
        properties[kCGImagePropertyTIFFDictionary as String] = tiff
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw HarbethError.imageEncodingFailed("public.tiff") }
    }
}
