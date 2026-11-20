import XCTest
import Metal
import simd
@testable import Harbeth

final class PointwiseFusionTests: XCTestCase {
    private func makeTexture() throws -> MTLTexture {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let texture = try TextureLoader.makeTexture(
            width: 2,
            height: 2,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "PointwiseFusionTests"
        )
        let bytes: [UInt8] = [
            32, 64, 128, 255,
            180, 90, 40, 192,
            12, 220, 100, 128,
            240, 200, 160, 64
        ]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    func testPlannerFusesOnlyConsecutiveSupportedPointOperations() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.1),
            C7GaussianBlur(radius: 2),
            C7Saturation(saturation: 1.2),
            C7Exposure(exposure: 0.2)
        ]

        let execution = PointwiseFusionPlanner.makeExecutionFilters(filters)

        XCTAssertEqual(execution.count, 3)
        XCTAssertEqual((execution[0] as? C7FusedPointOperations)?.fusedOperationCount, 2)
        XCTAssertTrue(execution[1] is C7GaussianBlur)
        XCTAssertEqual((execution[2] as? C7FusedPointOperations)?.fusedOperationCount, 2)
    }

    func testFusionUsesOneFusedFilterNodeAndOneDispatchStage() throws {
        let texture = try makeTexture()
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.1),
            C7Saturation(saturation: 1.2),
            C7Exposure(exposure: 0.2)
        ]

        let diagnostics = try HarbethIO(element: texture, filters: filters).renderDiagnostics()

        XCTAssertEqual(diagnostics.optimizedGraphNodeCount, 2, "ImageNode diagnostics include the source node and the fused filter node.")
        XCTAssertEqual(diagnostics.stageCount, 1)
        XCTAssertEqual(diagnostics.optimizationPlan.mergedStageCount, 1)
        XCTAssertEqual(diagnostics.optimizationPlan.fusionEligibleNodeCount, 4)
        XCTAssertTrue(diagnostics.summary.contains("C7FusedPointOperations"))
    }

    func testFusedKernelMatchesOrderedStandaloneKernels() throws {
        let texture = try makeTexture()
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.08),
            C7Contrast(contrast: 1.15),
            C7Saturation(saturation: 0.85),
            C7Exposure(exposure: 0.25),
            C7Gamma(gamma: 1.1),
            C7Opacity(opacity: 0.7)
        ]
        let fused = try HarbethIO(element: texture, filters: filters).output()

        var standalone = texture
        for filter in filters {
            standalone = try HarbethIO(element: standalone, filters: [filter]).output()
        }

        guard let fusedBytes = fused.c7.bytes(), let standaloneBytes = standalone.c7.bytes() else {
            return XCTFail("Expected readable RGBA8 textures.")
        }
        XCTAssertEqual(fusedBytes.count, standaloneBytes.count)
        for (fusedValue, standaloneValue) in zip(fusedBytes, standaloneBytes) {
            XCTAssertEqual(Int(fusedValue), Int(standaloneValue), accuracy: 1)
        }
    }

    func testWhiteBalanceFusionPreservesOrderAndEightBitStorage() throws {
        let texture = try makeTexture()
        let whiteBalance = C7WhiteBalance(temperature: 5900, tint: 18)
        let brightness = C7Brightness(brightness: 0.08)
        let saturation = C7Saturation(saturation: 1.12)
        let contrast = C7Contrast(contrast: 0.9)
        let sequences: [[C7FilterProtocol]] = [
            [whiteBalance, brightness, saturation, contrast],
            [brightness, contrast, saturation, whiteBalance]
        ]
        let solo = PointwiseFusionPlanner.makeExecutionFilters([whiteBalance, C7GaussianBlur(radius: 2)])
        XCTAssertEqual((solo.first as? C7WhiteBalance)?.factors, whiteBalance.factors)
        for (index, filters) in sequences.enumerated() {
            let lowered = PointwiseFusionPlanner.makeExecutionFilters(filters)
            let fused = try XCTUnwrap(lowered.first as? C7FusedPointOperations)
            XCTAssertEqual(lowered.count, 1)
            XCTAssertEqual(fused.operations.count, filters.count)
            XCTAssertEqual(fused.operations[index == 0 ? 0 : 3].kind, .whiteBalance)
            XCTAssertEqual(fused.usesSpecializedKernel, index == 1)
            var standalone = texture
            for filter in filters {
                standalone = try HarbethIO(element: standalone, filters: [filter]).output()
            }
            let actual = try HarbethIO(element: texture, filters: filters).output()
            let expected = try XCTUnwrap(standalone.c7.bytes())
            let bytes = try XCTUnwrap(actual.c7.bytes())
            XCTAssertEqual(bytes.count, expected.count)
            for offset in bytes.indices {
                XCTAssertEqual(Int(bytes[offset]), Int(expected[offset]), accuracy: offset % 4 == 3 ? 0 : 1)
            }
        }
    }

    func testWhiteBalanceMatchesStraightRGBReferenceInFloatTextures() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal device is unavailable.") }
        let inputs: [SIMD4<Float>] = [
            .zero, .init(0.5, 0.5, 0.5, 1), .init(1, 1, 0, 1), .init(0, 0, 1, 1),
            .init(0.25, 0.125, 0.5, 0.5), .init(-0.08, 0.2, 1.25, 0.5),
            .init(0.0001, 0.00002, 0.00006, 0.0001), .init(8, 4, -0.5, 1),
            .init(0.01, 0.02, 0.03, 0), .init(1.0001, 0.8, 0.3, 1)
        ]
        let controls: [(Float, Float)] = [(5000, 0), (4000, 0), (8000, 0), (5000, 200), (5900, 18), (4200, -200)]
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let half = format == .rgba16Float
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: format, width: inputs.count, height: 1, mipmapped: false
            )
            descriptor.storageMode = .shared
            descriptor.usage = [.shaderRead, .shaderWrite]
            let source = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let region = MTLRegionMake2D(0, 0, inputs.count, 1)
            let rowBytes = inputs.count * (half ? 8 : 16)
            let encoded = half
                ? inputs.map { SIMD4<Float>(SIMD4<Float16>($0)) }
                : inputs
            if half {
                inputs.map { SIMD4<Float16>($0) }.withUnsafeBytes {
                    source.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes)
                }
            } else {
                inputs.withUnsafeBytes {
                    source.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes)
                }
            }
            for (temperature, tint) in controls {
                let filter = C7WhiteBalance(temperature: temperature, tint: tint)
                let output = try HarbethIO(element: source, filters: [filter]).output()
                let readback = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
                let command = try XCTUnwrap(device.makeCommandQueue()?.makeCommandBuffer())
                let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
                blit.copy(from: output, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(),
                    sourceSize: .init(width: inputs.count, height: 1, depth: 1), to: readback,
                    destinationSlice: 0, destinationLevel: 0, destinationOrigin: .init())
                blit.endEncoding()
                command.commit()
                command.waitUntilCompleted()
                XCTAssertNil(command.error)
                let actual: [SIMD4<Float>]
                if half {
                    var pixels = Array(repeating: SIMD4<Float16>.zero, count: inputs.count)
                    pixels.withUnsafeMutableBytes {
                        readback.getBytes($0.baseAddress!, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
                    }
                    actual = pixels.map { SIMD4<Float>($0) }
                } else {
                    var pixels = Array(repeating: SIMD4<Float>.zero, count: inputs.count)
                    pixels.withUnsafeMutableBytes {
                        readback.getBytes($0.baseAddress!, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
                    }
                    actual = pixels
                }
                for (pixel, input) in zip(actual, encoded) {
                    var reference = straightWhiteBalance(input, temperature: temperature, tint: tint)
                    if half { reference = SIMD4<Float>(SIMD4<Float16>(reference)) }
                    XCTAssertEqual(pixel.w, reference.w)
                    for component in 0..<3 {
                        let tolerance = half ? Float(Float16(reference[component]).ulp) : 0.000005
                        XCTAssertEqual(pixel[component], reference[component], accuracy: tolerance,
                            "白平衡格式 \(format)，温度 \(temperature)，tint \(tint)，像素 \(input)")
                    }
                }
            }
        }
    }

    // 保留优化前的直通 RGB 算法作为独立数值基线。
    private func straightWhiteBalance(_ color: SIMD4<Float>, temperature: Float, tint: Float) -> SIMD4<Float> {
        if temperature == 5000, tint == 0 { return color }
        guard color.w > 0 else { return .zero }
        var rgb = SIMD3(color.x, color.y, color.z) / color.w
        if tint != 0 {
            let toYIQ = simd_float3x3(SIMD3(0.299, 0.587, 0.114), SIMD3(0.596, -0.274, -0.322), SIMD3(0.212, -0.523, 0.311))
            let toRGB = simd_float3x3(SIMD3(1, 0.956, 0.621), SIMD3(1, -0.272, -0.647), SIMD3(1, -1.105, 1.702))
            var yiq = toYIQ * rgb
            yiq.z += tint / 100 * 0.05226
            if (0...1).contains(rgb.x), (0...1).contains(rgb.y), (0...1).contains(rgb.z) {
                yiq.z = min(0.5226, max(-0.5226, yiq.z))
            }
            rgb = toRGB * yiq
        }
        let amount = (temperature < 5000 ? Float(0.0004) : 0.00006) * (temperature - 5000)
        let warm = SIMD3<Float>(0.93, 0.54, 0)
        for i in 0..<3 {
            let x = rgb[i]
            let shifted = x < 0.5 ? 2 * x * warm[i] : 1 + 2 * (1 - warm[i]) * (x - 1)
            rgb[i] = (x + (shifted - x) * amount) * color.w
        }
        return SIMD4(rgb.x, rgb.y, rgb.z, color.w)
    }

    func testPlannerSplitsRunsAtTheFixedOperationLimit() {
        let filters: [C7FilterProtocol] = (0..<(PointwiseFusionPlanner.maximumOperationCount + 3)).map { index in
            C7Brightness(brightness: Float(index) * 0.001)
        }

        let execution = PointwiseFusionPlanner.makeExecutionFilters(filters)

        XCTAssertEqual(execution.count, 2)
        XCTAssertEqual((execution[0] as? C7FusedPointOperations)?.fusedOperationCount, PointwiseFusionPlanner.maximumOperationCount)
        XCTAssertEqual((execution[1] as? C7FusedPointOperations)?.fusedOperationCount, 3)
    }
}
