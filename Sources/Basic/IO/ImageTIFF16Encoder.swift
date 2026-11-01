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

/// Integer TIFF16 encoding. Consumers own region budgets, temporary files, and delivery.
public enum ImageTIFF16Encoder {
    /// Encodes explicit integer RGBA16 samples without an intermediate JPEG or 8-bit image.
    public static func encode(_ image: CIImage, colorSpace: CGColorSpace) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.tiff" as CFString, 1, nil) else {
            throw HarbethError.imageDestinationCreationFailed("public.tiff")
        }
        let context = CIContext(options: [CIContextOption.priorityRequestLow: true])
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
            context.render(
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
