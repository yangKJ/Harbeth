// 由 Condy 创建于 2026/11/17。以恒等合同和独立 Double 重采样参考验收几何路径。
import XCTest
import Metal
import CoreGraphics
@testable import Harbeth

final class ResamplingRegressionTests: XCTestCase {
    func testZeroRotationPreservesPixelsAcrossSamplingEdgesFormatsAndParity() throws {
        for format in NeighborhoodTestImage.formats {
            for (w, h) in [(1, 1), (1, 5), (4, 4), (5, 3), (2, 4)] {
                let source = try NeighborhoodTestImage(width: w, height: h, format: format)
                for mode in [SpatialSamplingMode.nearest, .linear, .adaptive] {
                    for edge in [SpatialEdgeMode.transparent, .clamp, .repeat, .mirrorRepeat] {
                        for placement in [Placement.fixed, .fit] {
                            let result = try render(source.texture, C7Rotate(mode: placement, angle: 0, samplingMode: mode, edgeMode: edge))
                            source.assertPixels(result, source.values)
                        }
                    }
                }
            }
        }
    }

    func testQuarterTurnsAndFitBoundingBoxHaveNoMissingPixels() throws {
        let source = try NeighborhoodTestImage(width: 5, height: 3, format: .rgba32Float)
        for angle: Float in [90, 180, 270] {
            for sampling in [SpatialSamplingMode.nearest, .linear, .adaptive] {
                let filter = C7Rotate(angle: angle, samplingMode: sampling)
                let out: MTLTexture = try HarbethIO(element: source.texture, filter: filter).output()
                XCTAssertEqual(out.width, angle == 180 ? 5 : 3)
                XCTAssertEqual(out.height, angle == 180 ? 3 : 5)
                let expected = rotationReference(source.values, width: 5, height: 3, outputWidth: out.width,
                    outputHeight: out.height, angle: Double(angle), linear: false, edge: .transparent)
                source.assertPixels(try NeighborhoodTestImage.read(out), expected)
            }
        }
        XCTAssertEqual(C7Rotate(angle: 45).resize(input: C7Size(width: 64, height: 32)), C7Size(width: 68, height: 68))
    }

    func testArbitraryRotationMatchesIndependentReferenceAndEdgeModes() throws {
        let source = try NeighborhoodTestImage(width: 7, height: 5, format: .rgba32Float)
        for angle: Float in [13, 27] {
            for sampling in [SpatialSamplingMode.nearest, .linear, .adaptive] {
                for edge in [SpatialEdgeMode.transparent, .clamp, .repeat, .mirrorRepeat] {
                    let expected = rotationReference(source.values, width: 7, height: 5, outputWidth: 7,
                        outputHeight: 5, angle: Double(angle), linear: sampling != .nearest, edge: edge)
                    let actual = try render(source.texture, C7Rotate(mode: .fixed, angle: angle, samplingMode: sampling, edgeMode: edge))
                    source.assertPixels(actual, expected, tolerance: sampling == .nearest ? 0.00001 : 1 / 256 + 0.00001)
                }
            }
        }
    }

    func testResizeIdentityPreservesHDRAndFloat32BitsIncludingFormatConversion() throws {
        let values: [Float] = [100000, -100, 0.123456, 0.5, 2, -0.1, 0.234567, 1]
        let source = try NeighborhoodTestImage.make(width: 2, height: 1, values: values, format: .rgba32Float)
        let filters: [any C7FilterProtocol] = [C7Resize(width: 2, height: 1), C7LanczosResize(width: 2, height: 1), C7Rotate(angle: 0)]
        for filter in filters {
            XCTAssertEqual(try render(source, filter), values)
        }
        let narrow: [Float] = [0.123456, 0.234567, 0.345678, 0.5]
        let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: narrow, format: .rgba32Float)
        for filter: any C7FilterProtocol in [C7Resize(width: 1, height: 1), C7LanczosResize(width: 1, height: 1), C7Rotate(angle: 0), try C7TextureGeometry(width: 1, height: 1)] {
            let output = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 0], format: .rgba16Float)
            let command = try XCTUnwrap(input.device.makeCommandQueue()?.makeCommandBuffer())
            _ = try filter.applyAtTexture(form: input, to: output, for: command)
            command.commit(); command.waitUntilCompleted(); XCTAssertNil(command.error)
            XCTAssertEqual(try NeighborhoodTestImage.read(output), narrow.map { Float(Float16($0)) })
        }
    }

    func testLanczosMatchesScaleAwareDoubleReferenceForEdgesAndMixedAxes() throws {
        for format in NeighborhoodTestImage.formats {
            for (w, h, ow, oh) in [(3, 1, 6, 1), (12, 1, 4, 1), (7, 5, 3, 2), (8, 6, 4, 9), (3, 2, 7, 5), (1, 7, 1, 2)] {
                let source = try NeighborhoodTestImage(width: w, height: h, format: format)
                let expected = lanczosReference(source.values, width: w, height: h, outputWidth: ow, outputHeight: oh)
                let f = C7LanczosResize(width: Float(ow), height: Float(oh))
                source.assertPixels(try render(source.texture, f), expected, tolerance: format == .rgba8Unorm ? 1.5 / 255 : format == .rgba16Float ? 0.0015 : 0.00005)
                // 公开包装仍走直接核，必须与内部可分离路径保持同一方程。
                source.assertPixels(try render(source.texture, ForwardedResamplingFilter(base: f)), expected,
                    tolerance: format == .rgba8Unorm ? 1.5 / 255 : format == .rgba16Float ? 0.0015 : 0.00005)
            }
        }
    }

    func testLanczosMinificationRejectsPeriodThreeAliasAndPreservesConstantHDR() throws {
        let period = (0..<12).flatMap { x -> [Float] in let v: Float = x % 3 == 1 ? 1 : 0; return [v, v, v, 1] }
        let source = try NeighborhoodTestImage.make(width: 12, height: 1, values: period, format: .rgba32Float)
        let actual = try render(source, C7LanczosResize(width: 4, height: 1))
        let expected = lanczosReference(period, width: 12, height: 1, outputWidth: 4, outputHeight: 1)
        for i in actual.indices { XCTAssertEqual(actual[i], expected[i], accuracy: 0.00001) }
        XCTAssertLessThan(actual[4], 0.5)
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let pixel: [Float] = [2, -0.5, 0.123456, 0.5]
            let constant = try NeighborhoodTestImage.make(width: 17, height: 13, values: Array(repeating: pixel, count: 221).flatMap { $0 }, format: format)
            let reference = try NeighborhoodTestImage.read(constant)
            let out = try render(constant, C7LanczosResize(width: 3, height: 2))
            for i in out.indices { XCTAssertEqual(out[i], reference[i % 4], accuracy: format == .rgba16Float ? 0.002 : 0.00002) }
        }
    }

    func testGeometryUsesAssociatedSamplingAndReportsRealOutputAlpha() throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        func image(_ bytes: [UInt8], _ width: Int, _ alpha: CGImageAlphaInfo) throws -> CGImage {
            try XCTUnwrap(CGImage(width: width, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue), provider: CGDataProvider(data: Data(bytes) as CFData)!,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        }
        let opaque = try image([255, 0, 0, 255], 1, .noneSkipLast)
        let filter = try C7TextureGeometry(width: 4, height: 4, destinationRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), background: SIMD4(0.25, 0, 0, 0.25))
        let frame = try ImageNode.cgImage(opaque).applying(filter).makeFrame(profile: .exportQuality)
        XCTAssertEqual(frame.alphaType, .premultiplied)
        XCTAssertEqual(try rgba(frame.texture)[3], 0.25, accuracy: 1 / 255)
        let straight = try image([255, 0, 0, 255, 0, 0, 255, 0], 2, .last)
        let output = try ImageNode.cgImage(straight).applying(C7TextureGeometry(width: 3, height: 1)).makeFrame(profile: .exportQuality)
        XCTAssertEqual(output.alphaType, .premultiplied)
        let middle = Array(try rgba(output.texture)[4..<8])
        for (actual, expected) in zip(middle, [Float](arrayLiteral: 0.5, 0, 0, 0.5)) { XCTAssertEqual(actual, expected, accuracy: 1 / 255) }
        for f: any C7FilterProtocol in [filter, C7Rotate(), C7Resize(width: 4, height: 4), C7LanczosResize(width: 4, height: 4)] {
            XCTAssertFalse(f.samplingFootprint.canAutoTile)
            XCTAssertFalse(f.kernelPixelContract.canAutoTile)
            XCTAssertFalse(f.kernelPixelContract.isPointwiseFusionEligible)
        }
    }

    func testInvalidGeometryPlansSafelyAndExecutionThrowsWithoutChangingSentinels() throws {
        let source = try NeighborhoodTestImage(width: 4, height: 3, format: .rgba32Float)
        for value: Float in [.nan, .infinity, -.infinity] {
            let f = C7Rotate(angle: value)
            XCTAssertEqual(f.resize(input: C7Size(width: 4, height: 3)), C7Size(width: 4, height: 3))
            _ = f.kernelDescriptor(inputSize: C7Size(width: 4, height: 3))
            XCTAssertThrowsError(try ImageNode.texture(source.texture).applying(f).makeFrame())
            XCTAssertThrowsError(try render(source.texture, f))
        }
        for value: Float in [.infinity, .greatestFiniteMagnitude, 0.5] {
            for f: any C7FilterProtocol in [C7Resize(width: value, height: 2), C7LanczosResize(width: 2, height: value)] {
                _ = f.kernelDescriptor(inputSize: C7Size(width: 4, height: 3))
                XCTAssertThrowsError(try render(source.texture, f))
            }
        }
        for value: Float in [0, -1, .nan, -.infinity] {
            for f: any C7FilterProtocol in [C7Resize(width: value, height: value), C7LanczosResize(width: value, height: value)] {
                XCTAssertEqual(f.resize(input: C7Size(width: 4, height: 3)), C7Size(width: 4, height: 3))
                XCTAssertEqual(try render(source.texture, f), source.values)
            }
        }
    }

    func testResizeIdentityAcrossStorageFormatsAndBGRAResampling() throws {
        for format in NeighborhoodTestImage.formats {
            let source = try NeighborhoodTestImage(width: 7, height: 5, format: format)
            for filter: any C7FilterProtocol in [C7Resize(width: 7, height: 5), C7LanczosResize(width: 7, height: 5)] {
                XCTAssertEqual(try render(source.texture, filter), source.values)
            }
        }
        let source = try NeighborhoodTestImage(width: 7, height: 5, format: .rgba8Unorm)
        var converted = HarbethIO(element: source.texture, filter: C7Resize(width: 7, height: 5))
        converted.bufferPixelFormat = .bgra8Unorm
        let bgra: MTLTexture = try converted.output()
        XCTAssertEqual(try rgba(bgra), source.values)
        let output: MTLTexture = try HarbethIO(element: bgra, filter: C7LanczosResize(width: 3, height: 2)).output()
        let expected = lanczosReference(source.values, width: 7, height: 5, outputWidth: 3, outputHeight: 2)
        for (actual, raw) in zip(try rgba(output), expected) { XCTAssertEqual(actual, min(max(raw, 0), 1), accuracy: 1.5 / 255) }
    }

    func testGeometryKeepsRawAssociatedHDRBackgroundInFloat32() throws {
        let source = try NeighborhoodTestImage(width: 2, height: 2, format: .rgba32Float)
        let filter = try C7TextureGeometry(width: 4, height: 4, destinationRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            background: SIMD4(2, -0.5, 0.123456, 0.25))
        XCTAssertEqual(Array(try render(source.texture, filter).prefix(4)), [2, -0.5, 0.123456, 0.25])
    }

    func testAsyncComputeEncodingUsesTheSameSeparableAndIdentityPaths() throws {
        let source = try NeighborhoodTestImage(width: 7, height: 5, format: .rgba32Float)
        for size in [C7Size(width: 7, height: 5), C7Size(width: 3, height: 2)] {
            let filter = C7LanczosResize(width: Float(size.width), height: Float(size.height))
            let output = try NeighborhoodTestImage.make(width: size.width, height: size.height,
                values: [Float](repeating: 0, count: size.width * size.height * 4), format: .rgba32Float)
            let command = try XCTUnwrap(source.texture.device.makeCommandQueue()?.makeCommandBuffer())
            let encoded = expectation(description: "计算编码已交付")
            _ = try filter.apply(form: source.texture, to: output, for: command, complete: { result in
                if case .failure(let error) = result { XCTFail(String(describing: error)) }
                encoded.fulfill()
            })
            wait(for: [encoded], timeout: 5)
            command.commit(); command.waitUntilCompleted(); XCTAssertNil(command.error)
            let expected = size.width == 7 ? source.values : lanczosReference(source.values, width: 7, height: 5, outputWidth: size.width, outputHeight: size.height)
            source.assertPixels(try NeighborhoodTestImage.read(output), expected, tolerance: 0.00005)
        }
    }

    func testSeparableScratchIsBoundedAndBudgetFallbackRemainsCorrect() throws {
        let input = C7Size(width: 17, height: 13), output = C7Size(width: 4, height: 3)
        XCTAssertNotNil(LanczosResampling.scratch(input: input, output: output, limit: 4096))
        XCTAssertNil(LanczosResampling.scratch(input: input, output: output, limit: 0))
        XCTAssertNil(LanczosResampling.scratch(input: C7Size(width: Int.max, height: Int.max), output: output, limit: 4096))
        let source = try NeighborhoodTestImage(width: 7, height: 5, format: .rgba32Float)
        let destination = try NeighborhoodTestImage.make(width: 3, height: 2, values: [Float](repeating: 0, count: 24), format: .rgba32Float)
        let command = try XCTUnwrap(source.texture.device.makeCommandQueue()?.makeCommandBuffer())
        let f = C7LanczosResize(width: 3, height: 2)
        XCTAssertNil(try LanczosResampling.encode(commandBuffer: command, textures: [destination, source.texture], descriptor: f.kernelDescriptor(), maximumTemporaryBytes: 0))
    }

    private func render(_ texture: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        try NeighborhoodTestImage.read(HarbethIO(element: texture, filter: filter).output())
    }
    private func rgba(_ texture: MTLTexture) throws -> [Float] {
        if texture.pixelFormat == .bgra8Unorm {
            var bytes = try XCTUnwrap(texture.c7.rawBytes(maximumBytes: texture.width * texture.height * 4)).map { Float($0) / 255 }
            for i in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(i, i + 2) }; return bytes
        }
        return try NeighborhoodTestImage.read(texture)
    }
}

private func lanczosReference(_ values: [Float], width: Int, height: Int, outputWidth: Int, outputHeight: Int) -> [Float] {
    func weight(_ x: Double) -> Double {
        let a = abs(x); if a < 1e-5 { return 1 }; if a >= 3 { return 0 }
        return sin(.pi * a) / (.pi * a) * sin(.pi * a / 3) / (.pi * a / 3)
    }
    let sx = Double(width) / Double(outputWidth), sy = Double(height) / Double(outputHeight)
    let kx = max(sx, 1), ky = max(sy, 1)
    var output: [Float] = []
    for y in 0..<outputHeight { for x in 0..<outputWidth {
        let px = (Double(x) + 0.5) * sx - 0.5, py = (Double(y) + 0.5) * sy - 0.5
        var color = [Double](repeating: 0, count: 4), sum = 0.0
        for ty in (Int(floor(py - 3 * ky)) + 1)...(Int(ceil(py + 3 * ky)) - 1) {
            for tx in (Int(floor(px - 3 * kx)) + 1)...(Int(ceil(px + 3 * kx)) - 1) {
                let w = weight((px - Double(tx)) / kx) * weight((py - Double(ty)) / ky)
                let i = (min(max(ty, 0), height - 1) * width + min(max(tx, 0), width - 1)) * 4
                for c in 0..<4 { color[c] += Double(values[i + c]) * w }; sum += w
            }
        }
        color = color.map { $0 / sum }
        let alpha = min(max(color[3], 0), 1)
        output += alpha <= 0 ? [0, 0, 0, 0] : [Float(color[0] * alpha / color[3]), Float(color[1] * alpha / color[3]), Float(color[2] * alpha / color[3]), Float(alpha)]
    } }
    return output
}

private func rotationReference(_ values: [Float], width: Int, height: Int, outputWidth: Int, outputHeight: Int,
                               angle: Double, linear: Bool, edge: SpatialEdgeMode) -> [Float] {
    let radians = angle * .pi / 180
    let c = angle.truncatingRemainder(dividingBy: 90) == 0 ? cos(radians).rounded() : cos(radians)
    let s = angle.truncatingRemainder(dividingBy: 90) == 0 ? sin(radians).rounded() : sin(radians)
    func index(_ p: Int, _ count: Int) -> Int? {
        switch edge {
        case .transparent: return (0..<count).contains(p) ? p : nil
        case .clamp: return min(max(p, 0), count - 1)
        case .repeat: return (p % count + count) % count
        case .mirrorRepeat:
            let v = (p % (2 * count) + 2 * count) % (2 * count); return v < count ? v : 2 * count - 1 - v
        }
    }
    func pixel(_ x: Int, _ y: Int, _ channel: Int) -> Double {
        guard let x = index(x, width), let y = index(y, height) else { return 0 }
        return Double(values[(y * width + x) * 4 + channel])
    }
    var output: [Float] = []
    for y in 0..<outputHeight { for x in 0..<outputWidth {
        let dx = Double(x) + 0.5 - Double(outputWidth) / 2, dy = Double(y) + 0.5 - Double(outputHeight) / 2
        let px = dx * c + dy * s + Double(width) / 2, py = -dx * s + dy * c + Double(height) / 2
        if edge == .transparent && (px < 0 || px > Double(width) || py < 0 || py > Double(height)) { output += [0, 0, 0, 0]; continue }
        for channel in 0..<4 {
            if !linear { output.append(Float(pixel(Int(floor(px)), Int(floor(py)), channel))); continue }
            let ix = Int(floor(px - 0.5)), iy = Int(floor(py - 0.5))
            let fx = px - 0.5 - Double(ix), fy = py - 0.5 - Double(iy)
            output.append(Float(pixel(ix, iy, channel) * (1 - fx) * (1 - fy) + pixel(ix + 1, iy, channel) * fx * (1 - fy)
                + pixel(ix, iy + 1, channel) * (1 - fx) * fy + pixel(ix + 1, iy + 1, channel) * fx * fy))
        }
    } }
    return output
}

// 完整转发 resize 与输出合同，但不携带内置滤镜的执行优化类型身份。
private struct ForwardedResamplingFilter: C7FilterProtocol {
    let base: any C7FilterProtocol
    var modifier: ModifierEnum { base.modifier }
    var factors: [Float] { base.factors }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var kernelOutputContract: RenderOutputContract { base.kernelOutputContract }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
    func resize(input size: C7Size) -> C7Size { base.resize(input: size) }
}
