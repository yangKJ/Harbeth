// 由 Condy 创建于 2026/11/17。几何配置、纯查询和像素合同的组合回归。
import XCTest
import Metal
import CoreGraphics
@testable import Harbeth

final class GeometrySemanticIdentityTests: XCTestCase {
    func testPersistentGeometryCacheAndParityIncludeEveryRequestedConfiguration() throws {
        let fixtures = try (0..<6).map { _ in try NeighborhoodTestImage(width: 8, height: 6, format: .rgba32Float) }
        let pairs: [(any C7FilterProtocol, any C7FilterProtocol)] = [
            (C7Resize(width: 2, height: 1), C7Resize(width: 4, height: 3)),
            (C7LanczosResize(width: 2, height: 1), C7LanczosResize(width: 4, height: 3)),
            (C7Rotate(mode: .fixed, angle: 30), C7Rotate(mode: .fit, angle: 30)),
            (C7Transform(mode: .fixed, transform: .init(scaleX: 0.5, y: 0.5)), C7Transform(mode: .fit, transform: .init(scaleX: 0.5, y: 0.5))),
            (C7Crop(width: 2, height: 2), C7Crop(width: 4, height: 3)),
            (C7Crop(rect: .init(x: 1, y: 0, width: 3, height: 2)), C7Crop(rect: .init(x: 3, y: 0, width: 3, height: 2)))
        ]
        for (fixture, pair) in zip(fixtures, pairs) {
            let input = ImageNode.texture(fixture.texture)
            let a = input.applying(pair.0), b = input.applying(pair.1)
            XCTAssertNotEqual(pair.0.recipeDescriptor.fingerprint, pair.1.recipeDescriptor.fingerprint)
            _ = try a.withCachePolicy(.persistent).makeTexture()
            let cached = try b.withCachePolicy(.persistent).makeTexture(), direct = try b.withCachePolicy(.transient).makeTexture()
            XCTAssertEqual(cached.width, direct.width); XCTAssertEqual(cached.height, direct.height)
            XCTAssertEqual(try NeighborhoodTestImage.read(cached), try NeighborhoodTestImage.read(direct))
            let first = try a.makeRenderRequest(), second = try b.makeRenderRequest()
            XCTAssertFalse(first.parityReport(comparedTo: second).isExactlyEquivalent)
            XCTAssertNotEqual(first.paritySignature.processingFingerprint, second.paritySignature.processingFingerprint)
        }
    }

    func testCropPlanningDoesNotChangeSharedParametersAndBothContractRoutesAgree() throws {
        let fixture = try NeighborhoodTestImage(width: 8, height: 6, format: .rgba32Float)
        let crop = C7Crop(rect: .init(x: 2, y: 1, width: 3, height: 2)), original = crop.identifier
        for size in [C7Size(width: 8, height: 6), C7Size(width: 16, height: 12)] {
            _ = crop.resize(input: size); _ = crop.kernelDescriptor(inputSize: size)
            XCTAssertEqual(crop.identifier, original); XCTAssertEqual(crop.origin, .zero)
        }
        let bindings = crop.kernelParameterBindings(inputSize: C7Size(width: 8, height: 6))
        XCTAssertEqual(bindings[0].value, .float(0.25)); XCTAssertEqual(bindings[1].value, .float(1 / 6))
        let input = ImageNode.texture(fixture.texture)
        let plain = try input.applying(crop).makeTexture()
        for node in [input.applyingWithContract(crop), input.applyingWithContract(crop, inputSize: C7Size(width: 8, height: 6))] {
            XCTAssertEqual(try NeighborhoodTestImage.read(node.makeTexture()), try NeighborhoodTestImage.read(plain))
        }
        XCTAssertEqual(Array(try NeighborhoodTestImage.read(plain).prefix(4)), Array(fixture.values[(8 + 2) * 4..<(8 + 2) * 4 + 4]))
    }

    func testConfigurationMismatchAndSizedRenderBindingsAreValidated() throws {
        let size = C7Size(width: 8, height: 6)
        let descriptor = C7Resize(width: 2, height: 1).kernelDescriptor(inputSize: size)
        XCTAssertThrowsError(try descriptor.validateCompatibility(with: C7Resize(width: 4, height: 3), inputSize: size))
        let filter = SizedBindingRender()
        XCTAssertEqual(filter.renderCommandDescriptor(inputSize: size).parameterBindings.first?.value, .float(8))
        let adapted = try XCTUnwrap(SamplerExecutionAdapter.adapt(filter: filter, samplerDescriptor: .nearest) as? any RenderProtocol)
        XCTAssertEqual(adapted.kernelParameterBindings(inputSize: size).first?.value, .float(8))
    }

    func testZeroCropAndIdentityAffinePreserveAllStorageSamplingAndEdgeCombinations() throws {
        for format in NeighborhoodTestImage.formats {
            for (w, h) in [(1, 1), (1, 5), (4, 4), (5, 3)] {
                let fixture = try NeighborhoodTestImage(width: w, height: h, format: format)
                for sampling in SpatialSamplingMode.allCases { for edge in SpatialEdgeMode.allCases {
                    for f: any C7FilterProtocol in [C7Crop(width: Float(w), height: Float(h), samplingMode: sampling, edgeMode: edge),
                        C7Transform(transform: .identity, samplingMode: sampling, edgeMode: edge)] {
                        fixture.assertPixels(try render(fixture.texture, f), fixture.values)
                        XCTAssertFalse(f.kernelPixelContract.canAutoTile)
                        XCTAssertFalse(f.kernelPixelContract.isPointwiseFusionEligible)
                    }
                } }
            }
        }
    }

    func testGeometryHDRAndCrossFormatRoundingPreservePrecision() throws {
        let values: [Float] = [100000, -100, 0.123456, 0.5]
        let source = try NeighborhoodTestImage.make(width: 1, height: 1, values: values, format: .rgba32Float)
        for f: any C7FilterProtocol in [C7Crop(width: 1, height: 1), C7Transform(transform: .identity)] { XCTAssertEqual(try render(source, f), values) }
        let narrow: [Float] = [0.123456, 0.234567, 0.345678, 0.5]
        let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: narrow, format: .rgba32Float)
        for f: any C7FilterProtocol in [C7Crop(width: 1, height: 1), C7Transform(transform: .identity)] {
            let destination = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 0])
            let command = try XCTUnwrap(input.device.makeCommandQueue()?.makeCommandBuffer())
            _ = try f.applyAtTexture(form: input, to: destination, for: command)
            command.commit(); command.waitUntilCompleted(); XCTAssertNil(command.error)
            XCTAssertEqual(try NeighborhoodTestImage.read(destination), narrow.map { Float(Float16($0)) })
        }
    }

    func testCGImageGeometryReportsRealCoverageAndNormalizesStraightInput() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        func image(_ values: [UInt8], _ width: Int, _ alpha: CGImageAlphaInfo) throws -> CGImage {
            try XCTUnwrap(CGImage(width: width, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue), provider: CGDataProvider(data: Data(values) as CFData)!,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        }
        let opaque = try image([255, 0, 0, 255], 1, .noneSkipLast)
        for f: any C7FilterProtocol in [C7Crop(width: 1, height: 1, samplingMode: .linear), C7Transform(transform: .identity, samplingMode: .linear)] {
            let frame = try ImageNode.cgImage(opaque).applying(f).makeFrame()
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertEqual(try XCTUnwrap(frame.texture.c7.rawBytes(maximumBytes: 4))[3], 255)
        }
        let straight = try image([255, 0, 0, 255, 0, 0, 255, 0], 2, .last)
        for f: any C7FilterProtocol in [C7Crop(origin: .init(x: 0.25, y: 0), width: 1, height: 1, samplingMode: .linear),
            C7Transform(transform: .init(scaleX: 1.5, y: 1), samplingMode: .linear)] {
            let frame = try ImageNode.cgImage(straight).applying(f).makeFrame()
            let bytes = try XCTUnwrap(frame.texture.c7.rawBytes(maximumBytes: frame.texture.width * frame.texture.height * 4))
            let offset = frame.texture.width == 1 ? 0 : 4
            let redIndex = frame.texture.pixelFormat == .bgra8Unorm ? 2 : 0
            let blueIndex = frame.texture.pixelFormat == .bgra8Unorm ? 0 : 2
            XCTAssertEqual(frame.alphaType, .premultiplied)
            XCTAssertEqual(Int(bytes[offset + redIndex]), 128, accuracy: 1)
            XCTAssertEqual(bytes[offset + blueIndex], 0)
            XCTAssertEqual(Int(bytes[offset + 3]), 128, accuracy: 1)
        }
    }

    func testAffineRegionalCoordinatesKeepPixelCenters() throws {
        let fixture = try NeighborhoodTestImage(width: 8, height: 6, format: .rgba32Float)
        let filter = RegionAffine()
        let actual = try render(fixture.texture, filter)
        let expected = (1..<4).flatMap { y in (2..<6).flatMap { x in Array(fixture.values[(y * 8 + x) * 4..<(y * 8 + x) * 4 + 4]) } }
        fixture.assertPixels(actual, expected)
    }

    func testInvalidCropAndAffineParametersPlanSafelyAndThrowAtExecution() throws {
        let source = try NeighborhoodTestImage(width: 8, height: 6, format: .rgba32Float)
        let filters: [any C7FilterProtocol] = [C7Crop(width: .infinity, height: 2), C7Crop(space: .nan), C7Crop(space: 100),
            C7Crop(rect: .init(x: 0, y: 0, width: CGFloat.nan, height: 2)), C7Crop(rect: .init(x: CGFloat.infinity, y: 0, width: 2, height: 2)),
            C7Transform(transform: .init(a: .nan, b: 0, c: 0, d: 1, tx: 0, ty: 0)), C7Transform(transform: .init(scaleX: CGFloat.infinity, y: 1)),
            C7Transform(transform: .init(scaleX: 0, y: 0))]
        for f in filters {
            _ = f.resize(input: C7Size(width: 8, height: 6)); _ = f.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))
            XCTAssertThrowsError(try render(source.texture, f))
        }
        var mirror = C7Transform(transform: .init(scaleX: -1, y: 1), samplingMode: .nearest)
        mirror.anchorPoint = .init(x: 0.5, y: 0.5)
        let expected = (0..<6).flatMap { y in (0..<8).reversed().flatMap { x in Array(source.values[(y * 8 + x) * 4..<(y * 8 + x) * 4 + 4]) } }
        source.assertPixels(try render(source.texture, mirror), expected)
        let empty = try render(source.texture, C7Transform(mode: .fixed, transform: .init(scaleX: 0, y: 0)))
        XCTAssertTrue(empty.allSatisfy { $0 == 0 })
        XCTAssertEqual(C7Crop(space: -1).resize(input: C7Size(width: 8, height: 6)), C7Size(width: 10, height: 8))
        XCTAssertEqual(C7Crop(width: 0, height: -1).resize(input: C7Size(width: 8, height: 6)), C7Size(width: 8, height: 6))
    }

    private func render(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        try NeighborhoodTestImage.read(HarbethIO(element: source, filter: filter).output())
    }
}

private struct RegionAffine: C7FilterProtocol {
    let base = C7Transform(mode: .fixed, transform: .identity, samplingMode: .nearest, edgeMode: .clamp)
    var modifier: ModifierEnum { base.modifier }
    var kernelParameterBindings: [KernelParameterBinding] {
        base.kernelParameterBindings + [.init(name: "region", index: 30, stage: .compute, value: .floatArray([4, 3, 32, 24, 6, 4, 32, 24]))]
    }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    func resize(input size: C7Size) -> C7Size { C7Size(width: 4, height: 3) }
}

private struct SizedBindingRender: RenderProtocol {
    var modifier: ModifierEnum { RenderBasicFilter().modifier }
    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
    var kernelParameterBindings: [KernelParameterBinding] { [] }
    func kernelParameterBindings(inputSize: C7Size?) -> [KernelParameterBinding] {
        [.init(name: "width", index: 0, stage: .renderFragment, value: .float(Float(inputSize?.width ?? 0)))]
    }
}
