//
//  TextureAnalysisMask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public extension MTLTextureCompatible_ {
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        guard let bytes = bytes() else { return nil }
        let width = target.width
        let height = target.height
        guard width > 0, height > 0,
              let resolvedRegion = resolvedHistogramRegion(scope.region) else {
            return nil
        }

        let outputTexture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [
                TextureLoader.Option.texturePixelFormat: pixelFormat,
                TextureLoader.Option.textureUsage: MTLTextureUsage.shaderRead
            ],
            identifier: "TextureAnalysisMask"
        )

        let resolvedCoverageThreshold = min(max(scope.coverageThreshold, 0), 1)
        let maskSample = makeMaskCoverageSample(for: scope.mask)
        let bytesPerRow = width * 4
        var outputBytes = [UInt8](repeating: 0, count: width * height * 4)

        bytes.withUnsafeBytes { rawBuffer in
            let rgba = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                let rowBase = y * bytesPerRow
                for x in 0..<width {
                    let outputOffset = rowBase + x * 4
                    outputBytes[outputOffset + 3] = 255

                    let isInRegion =
                        x >= resolvedRegion.origin.x &&
                        y >= resolvedRegion.origin.y &&
                        x < resolvedRegion.origin.x + resolvedRegion.size.width &&
                        y < resolvedRegion.origin.y + resolvedRegion.size.height
                    guard isInRegion else { continue }

                    if let maskSample,
                       maskSample.coverage(atSourceX: x, y: y, sourceWidth: width, sourceHeight: height) < resolvedCoverageThreshold {
                        continue
                    }

                    let sourceOffset = rowBase + x * 4
                    let red = Float(rgba[sourceOffset]) / 255.0
                    let green = Float(rgba[sourceOffset + 1]) / 255.0
                    let blue = Float(rgba[sourceOffset + 2]) / 255.0
                    let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722

                    if let luminanceRange = scope.luminanceRange,
                       luminanceRange.contains(luminance) == false {
                        continue
                    }
                    if let colorRange = scope.colorRange,
                       colorRange.contains(red: red, green: green, blue: blue) == false {
                        continue
                    }

                    outputBytes[outputOffset] = 255
                    outputBytes[outputOffset + 1] = 255
                    outputBytes[outputOffset + 2] = 255
                }
            }
        }

        TextureLoader.replaceTexture(
            outputTexture,
            region: MTLRegionMake2D(0, 0, width, height),
            bytes: outputBytes,
            packedBytesPerRow: bytesPerRow
        )
        return outputTexture
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        guard let texture = try makeMaskTexture(scope: scope, pixelFormat: pixelFormat) else {
            return nil
        }
        return MaskDescriptor(
            texture: texture,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}

public extension RenderedAttachment {
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try texture.c7.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try texture.c7.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderedAttachmentSet {
    func makeMaskTexture(for semantic: RenderOutputAttachmentSemantic,
                         scope: TextureAnalysisScope,
                         pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try attachment(for: semantic)?.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(for semantic: RenderOutputAttachmentSemantic,
                            scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try attachment(for: semantic)?.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderedFrame {
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try texture.c7.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try texture.c7.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderRequest {
    func renderMaskDescriptor(scope: TextureAnalysisScope,
                              component: MaskComponent = .red,
                              blendMode: MaskBlendMode = .mix,
                              invert: Bool = false,
                              featherPolicy: MaskFeatherPolicy = .none,
                              opacity: Float = 1.0,
                              pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try renderFrame().makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}
