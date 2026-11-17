// 由 Condy 创建于 2026/11/17。
import XCTest
import Metal
@testable import Harbeth

final class SpatialStylizationRegressionTests: XCTestCase {
    func testSolidGeneratorProtectsSharedRootsBranchesAndDeliveredFrames() throws {
        for format in NeighborhoodTestImage.formats {
            for policy in [ImageCachePolicy.transient, .persistent] {
                for reverse in [false, true] {
                    let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
                    let base = ImageNode.texture(input.texture).withCachePolicy(policy)
                    let prior = try base.makeFrame()
                    let red = base.applying(C7SolidColor(color: .red)), blue = base.applying(C7SolidColor(color: .blue))
                    let first = try (reverse ? blue : red).makeFrame()
                    let firstPixels = try NeighborhoodTestImage.read(first.texture)
                    let second = try (reverse ? red : blue).makeFrame()
                    XCTAssertFalse(first.texture === input.texture)
                    XCTAssertFalse(second.texture === first.texture)
                    input.assertPixels(try NeighborhoodTestImage.read(input.texture), input.values)
                    input.assertPixels(try NeighborhoodTestImage.read(prior.texture), input.values)
                    input.assertPixels(try NeighborhoodTestImage.read(base.makeTexture()), input.values)
                    XCTAssertEqual(try NeighborhoodTestImage.read(first.texture), firstPixels)
                }
            }
        }
    }

    func testDirectSolidRetainsExplicitInPlaceAndPremultipliesColor() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 3, height: 1, format: format)
            let color = C7Color(red: 1, green: 0.5, blue: 0.25, alpha: 0.25)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7SolidColor(color: color)).output()
            XCTAssertTrue(output === input.texture)
            input.assertPixels(try NeighborhoodTestImage.read(output), Array(repeating: [Float](arrayLiteral: 0.25, 0.125, 0.0625, 0.25), count: 3).flatMap { $0 })
            let frame = try ImageNode.texture(input.texture).applying(C7SolidColor(color: color)).makeFrame()
            XCTAssertEqual(frame.alphaType, .premultiplied)
            input.assertPixels(try NeighborhoodTestImage.read(frame.texture), try NeighborhoodTestImage.read(output))
            let clear = try ImageNode.texture(input.texture).applying(C7SolidColor(color: .clear)).makeTexture()
            XCTAssertTrue(try NeighborhoodTestImage.read(clear).allSatisfy { $0 == 0 })
        }
    }

    func testSolidPremultipliedColorCompositesOnBlackAndWhite() throws {
        let input = try R7Pixels.make(width: 2, height: 2, pixels: nil)
        let layer = try ImageNode.texture(input).applying(C7SolidColor(color: C7Color(red: 1, green: 0.5, blue: 0, alpha: 0.25))).makeTexture()
        for background: Float in [0, 1] {
            let source = try R7Pixels.make(width: 2, height: 2, pixels: Array(repeating: [background, background, background, 1], count: 4).flatMap { $0 })
            let output: MTLTexture = try HarbethIO(element: source, filter: RenderLayerComposite(layerTexture: layer)).output()
            let expected: [Float] = [0.25 + 0.75 * background, 0.125 + 0.75 * background, 0.75 * background, 1]
            let actual = try NeighborhoodTestImage.read(output)
            for i in actual.indices { XCTAssertEqual(actual[i], expected[i % 4], accuracy: 0.001) }
        }
    }

    func testEncodedAndAsyncSolidCannotOverwriteBorrowedTexture() async throws {
        let input = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba16Float)
        let node = ImageNode.texture(input.texture).applying(C7SolidColor(color: .red))
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        let frame = try node.encodeFrame(into: command, inputColorSpace: .extendedLinearSRGB, workingColorSpace: .extendedLinearSRGB)
        await withCheckedContinuation { continuation in
            command.addCompletedHandler { _ in continuation.resume() }
            command.commit()
        }
        XCTAssertEqual(command.status, .completed)
        XCTAssertFalse(frame.texture === input.texture)
        _ = try await node.makeFrameAsync()
        input.assertPixels(try NeighborhoodTestImage.read(input.texture), input.values)
    }

    func testSpatialFiltersRejectPointwiseFusionAndAutomaticTiling() {
        for filter: any C7FilterProtocol in [C7Pixellated(), C7Halftone(), C7PolkaDot(), C7SphereRefraction()] {
            XCTAssertEqual(filter.samplingFootprint, .global)
            XCTAssertEqual(filter.kernelPixelContract.coordinateDependency, .fullImage)
            XCTAssertFalse(filter.kernelPixelContract.canAutoTile)
            XCTAssertFalse(filter.kernelPixelContract.isPointwiseFusionEligible)
        }
    }

    func testZeroAndInvalidControlsKeepFloat32BitsIncludingHDRAndSoftAlpha() throws {
        let input = try R7Pixels.make(width: 3, height: 1, pixels: [2.001, 3.002, -0.1, 1, 0.013, 0.027, 0.011, 0.05, 0, 0, 0, 0], format: .rgba32Float)
        let expected = input.c7.rawBytes(maximumBytes: 48)
        for filter: any C7FilterProtocol in [C7Pixellated(scale: 0), C7Pixellated(scale: .nan), C7Halftone(fractionalWidth: 0),
            C7Halftone(fractionalWidth: .infinity), C7PolkaDot(fractionalWidth: 0), C7PolkaDot(fractionalWidth: .nan),
            C7LensVignetteCorrection(amount: 0), C7DefringeCorrection(), C7StickerOutline(outlineThickness: 0),
            C7StickerOutline(outlineThickness: .nan), C7VoronoiOverlay(alpha: 0), C7Haze()] {
            let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: 48), expected, String(describing: filter))
        }
    }

    func testGridFiltersMatchFullImageCropsWithDifferentOriginsAndHalo() throws {
        for (w, h, inputROI, outputROI) in [(16, 16, CGRect(x: 4, y: 4, width: 8, height: 8), CGRect(x: 6, y: 6, width: 4, height: 4)),
            (24, 16, CGRect(x: 2, y: 0, width: 20, height: 16), CGRect(x: 6, y: 4, width: 12, height: 8))] {
            let input = try NeighborhoodTestImage(width: w, height: h, format: .rgba32Float)
            for scale: Float in [0, 0.25] {
                for filter: any C7FilterProtocol in [C7Pixellated(scale: scale), C7Halftone(fractionalWidth: scale), C7PolkaDot(fractionalWidth: scale)] {
                    let full: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                    let source = try R7Pixels.crop(input.texture, roi: inputROI)
                    let destination = try R7Pixels.make(width: Int(outputROI.width), height: Int(outputROI.height), pixels: nil, format: .rgba32Float)
                    let extent = CGRect(x: 0, y: 0, width: w, height: h)
                    let mapping = try TextureMappingContext(inputLogicalExtent: extent, inputRegion: inputROI, outputLogicalExtent: extent, outputRegion: outputROI)
                    let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
                    _ = try R7RegionFilter(base: filter, mapping: mapping).encode(input: source, destination: destination, commandBuffer: command)
                    command.commit(); command.waitUntilCompleted()
                    XCTAssertEqual(command.status, .completed)
                    input.assertPixels(try NeighborhoodTestImage.read(destination), try NeighborhoodTestImage.read(R7Pixels.crop(full, roi: outputROI)))
                }
            }
        }
    }

    func testPixelCellNearestReferenceIncludingLastEdgeAndSinglePixel() throws {
        for (w, h) in [(1, 1), (17, 13)] {
            let input = try NeighborhoodTestImage(width: w, height: h, format: .rgba32Float)
            for scale: Float in [0, 0.25, 1] {
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7Pixellated(scale: scale)).output()
                var expected = input.values
                if scale > 0 { for y in 0..<h { for x in 0..<w {
                    let stepY = scale
                    let sx = min(Int((floor(Float(x) / Float(w) / scale) + 0.5) * scale * Float(w)), w - 1)
                    let sy = min(Int((floor(Float(y) / Float(h) / stepY) + 0.5) * stepY * Float(h)), h - 1)
                    for c in 0..<4 { expected[(y * w + x) * 4 + c] = input.values[(sy * w + sx) * 4 + c] }
                } } }
                input.assertPixels(try NeighborhoodTestImage.read(output), expected)
            }
        }
    }

    func testToonInvalidLevelsUseDefaultAndNormalQuantizationReference() throws {
        let input = try R7Pixels.make(width: 1, height: 1, pixels: [0.24, 0.51, 0.76, 0.4], format: .rgba32Float)
        for level: Float in [0, -1, .nan, .infinity, 1, 10] {
            let output: MTLTexture = try HarbethIO(element: input, filter: C7Toon(quantizationLevels: level)).output()
            let actual = try NeighborhoodTestImage.read(output)
            let n: Float = level.isFinite && level > 0 ? level : 10
            for c in 0..<3 { XCTAssertEqual(actual[c], floor([Float](arrayLiteral: 0.24, 0.51, 0.76)[c] * n + 0.5) / n, accuracy: 0.00001) }
            XCTAssertEqual(actual[3], 0.4)
        }
    }

    func testHazeKeepsFourChannelEquationAndBypassesOnlySingularRow() throws {
        let input = try NeighborhoodTestImage(width: 16, height: 16, format: .rgba32Float, constant: 0.25)
        for distance: Float in [0, 0.2, 0.5, 1, .nan] {
            for slope: Float in [0, 1] {
                let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7Haze(distance: distance, slope: slope)).output()
                var expected = input.values
                for y in 0..<16 { for x in 0..<16 { for c in 0..<4 {
                    let dd = Double(y) / 16 * Double(slope) + Double(distance)
                    let i = (y * 16 + x) * 4 + c
                    if dd.isFinite && dd != 1 { expected[i] = Float((Double(input.values[i]) - dd) / (1 - dd)) }
                } } }
                input.assertPixels(try NeighborhoodTestImage.read(output), expected, tolerance: max(0.00002, (expected.map { abs($0) }.max() ?? 0) * 0.000002))
            }
        }
    }

    func testSphereGrazingEdgesEmptySphereAndInvalidParameters() throws {
        let input = try NeighborhoodTestImage(width: 64, height: 64, format: .rgba32Float, constant: 1)
        let result: MTLTexture = try HarbethIO(element: input.texture, filter: C7SphereRefraction(radius: 0.25, refractiveIndex: 0)).output()
        let values = try NeighborhoodTestImage.read(result)
        for x in [16, 48] { XCTAssertEqual(Array(values[(32 * 64 + x) * 4..<(32 * 64 + x) * 4 + 4]), [1, 1, 1, 1]) }
        XCTAssertEqual(Array(values.prefix(4)), [0, 0, 0, 0])
        for radius: Float in [0, -1, .nan, .infinity] {
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7SphereRefraction(radius: radius, refractiveIndex: .nan, aspectRatio: .nan)).output()
            XCTAssertTrue(try NeighborhoodTestImage.read(output).allSatisfy { $0 == 0 })
        }
    }
}

// 参考图上传与裁切只搬运数值，不引入照片色彩管理。
enum R7Pixels {
    static func make(width: Int, height: Int, pixels: [Float]?, format: MTLPixelFormat = .rgba16Float) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        let values = pixels ?? [Float](repeating: 0, count: width * height * 4)
        if format == .rgba16Float {
            values.map { Float16($0) }.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else {
            values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        }
        return texture
    }
    static func crop(_ texture: MTLTexture, roi: CGRect) throws -> MTLTexture {
        let values = try NeighborhoodTestImage.read(texture)
        var crop: [Float] = []
        for y in Int(roi.minY)..<Int(roi.maxY) { for x in Int(roi.minX)..<Int(roi.maxX) {
            let i = (y * texture.width + x) * 4; crop += values[i..<i + 4]
        } }
        return try make(width: Int(roi.width), height: Int(roi.height), pixels: crop, format: texture.pixelFormat)
    }
}

private struct R7RegionFilter: C7FilterProtocol {
    let base: any C7FilterProtocol
    let mapping: TextureMappingContext
    var modifier: ModifierEnum { base.modifier }
    var factors: [Float] { base.factors }
    var kernelParameterBindings: [KernelParameterBinding] {
        factors.enumerated().map { .init(name: "factor\($0.offset)", index: $0.offset, stage: .compute, value: .float($0.element)) }
        + [.init(name: "mapping", index: 30, stage: .compute, value: .floatArray(mapping.kernelValues))]
    }
}
