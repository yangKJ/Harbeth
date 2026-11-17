//
//  TextureStructureStatisticsTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class TextureStructureStatisticsTests: XCTestCase {
    func testConstantTextureHasZeroStructureEnergyAcrossFloatFormats() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for format in [MTLPixelFormat.rgba8Unorm, .rgba16Float, .rgba32Float] {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 5, height: 5, mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = .shaderRead
            let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let bytesPerPixel = format == .rgba8Unorm ? 4 : (format == .rgba16Float ? 8 : 16)
            let bytes = [UInt8](repeating: format == .rgba8Unorm ? 255 : 0, count: texture.width * texture.height * bytesPerPixel)
            texture.replace(
                region: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0,
                withBytes: bytes,
                bytesPerRow: texture.width * bytesPerPixel
            )
            let result = try texture.c7.makeStructureStatistics(alphaType: .alphaIsOne)
            XCTAssertEqual(result.sampleCount, 9)
            XCTAssertEqual(result.laplacianMeanSquare, 0, accuracy: 0.0001)
            XCTAssertEqual(result.gradientMeanSquare, 0, accuracy: 0.0001)
        }
    }

    func testSignedHDRConstantsAndFrameAlphaMetadataRemainExact() throws {
        for value: Float in [0.1, 0.37, 0.5, 2.5, -0.25, 65504] {
            let texture = try makeTexture(values: [Float](repeating: value, count: 25), format: .rgba32Float)
            let statistics = try texture.c7.makeStructureStatistics(alphaType: .alphaIsOne)
            XCTAssertEqual(statistics.sampleCount, 9)
            XCTAssertEqual(statistics.laplacianMeanSquare, 0)
            XCTAssertEqual(statistics.gradientMeanSquare, 0)
        }
        let values = (0..<25).map { Float($0) / 32 }
        let texture = try makeTexture(values: values, format: .rgba32Float, alpha: 0.5)
        let frame = RenderedFrame(texture: texture, alphaType: .nonPremultiplied,
            profile: .readbackQuality, generation: 1, identifier: "straight-alpha")
        XCTAssertEqual(try frame.makeStructureStatistics(), try texture.c7.makeStructureStatistics(alphaType: .nonPremultiplied))
    }

    func testUnsupportedFormatIsRejected() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 5, height: 5, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        XCTAssertThrowsError(try texture.c7.makeStructureStatistics())
    }

    func testNonConstantTextureMatchesIndependentCPUOracle() throws {
        let values: [Float] = (0..<25).map { index in
            let value = (index % 5) * 7 + (index / 5) * 11
            return Float(value) / 255
        }
        let expected = oracle(values: values, width: 5, height: 5)
        let texture = try makeTexture(values: values, format: .rgba8Unorm)
        let result = try texture.c7.makeStructureStatistics(alphaType: .alphaIsOne)
        XCTAssertEqual(result.sampleCount, expected.count)
        XCTAssertEqual(result.laplacianMeanSquare, expected.laplacian, accuracy: 0.001)
        XCTAssertEqual(result.gradientMeanSquare, expected.gradient, accuracy: 0.001)
    }

    func testInversionAndRotationPreserveEnergy() throws {
        let values: [Float] = (0..<25).map { index in
            let value = (index % 5) * 9 + (index / 5) * 5
            return Float(value) / 255
        }
        let inverted = values.map { 1 - $0 }
        let rotated = (0..<5).flatMap { y in (0..<5).map { x in values[(4 - x) * 5 + y] } }
        let original = try makeTexture(values: values, format: .rgba32Float).c7.makeStructureStatistics(alphaType: .alphaIsOne)
        let inverse = try makeTexture(values: inverted, format: .rgba32Float).c7.makeStructureStatistics(alphaType: .alphaIsOne)
        let turn = try makeTexture(values: rotated, format: .rgba32Float).c7.makeStructureStatistics(alphaType: .alphaIsOne)
        XCTAssertEqual(original.sampleCount, inverse.sampleCount)
        XCTAssertEqual(original.laplacianMeanSquare, inverse.laplacianMeanSquare, accuracy: 0.0001)
        XCTAssertEqual(original.gradientMeanSquare, inverse.gradientMeanSquare, accuracy: 0.0001)
        XCTAssertEqual(original.laplacianMeanSquare, turn.laplacianMeanSquare, accuracy: 0.0001)
        XCTAssertEqual(original.gradientMeanSquare, turn.gradientMeanSquare, accuracy: 0.0001)
    }

    func testRGBAAndBGRA8AndFloatFormatsAgreeWithinQuantization() throws {
        let values: [Float] = (0..<25).map { Float(($0 * 13) % 101) / 100 }
        for format in [MTLPixelFormat.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float] {
            let stored: [Float]
            switch format {
            case .rgba8Unorm, .bgra8Unorm: stored = values.map { ($0 * 255).rounded() / 255 }
            case .rgba16Float: stored = values.map { Float(Float16($0)) }
            default: stored = values
            }
            // Oracle 使用各格式真正能表达的输入，精度量化不应被误当成算子误差。
            let expected = oracle(values: stored, width: 5, height: 5)
            let result = try makeTexture(values: values, format: format).c7.makeStructureStatistics(alphaType: .alphaIsOne)
            XCTAssertEqual(result.laplacianMeanSquare, expected.laplacian, accuracy: 0.000002)
            XCTAssertEqual(result.gradientMeanSquare, expected.gradient, accuracy: 0.000002)
        }
    }

    func testPremultipliedAndTransparentNeighborhoods() throws {
        let values: [Float] = (0..<25).map { Float(($0 % 5) * 8) / 255 }
        let premultiplied = try makeTexture(values: values, format: .rgba32Float, alpha: 0.5, premultiply: true)
        let straight = try makeTexture(values: values, format: .rgba32Float, alpha: 0.5, premultiply: false)
        let a = try premultiplied.c7.makeStructureStatistics(alphaType: .premultiplied)
        let b = try straight.c7.makeStructureStatistics(alphaType: .nonPremultiplied)
        XCTAssertEqual(a.sampleCount, b.sampleCount)
        XCTAssertEqual(a.laplacianMeanSquare, b.laplacianMeanSquare, accuracy: 0.0001)
        var transparentValues = values
        transparentValues[12] = 0
        let transparent = try makeTexture(values: transparentValues, format: .rgba32Float, alpha: 1, transparentIndex: 12)
        XCTAssertEqual(try transparent.c7.makeStructureStatistics(alphaType: .nonPremultiplied).sampleCount, 0)
    }

    func testNonFiniteAndPreCancelledRequestsFailClosed() async throws {
        var values = [Float](repeating: 0.5, count: 25)
        values[12] = .infinity
        XCTAssertThrowsError(try makeTexture(values: values, format: .rgba32Float).c7.makeStructureStatistics(alphaType: .alphaIsOne))
        let source = HarbethUncheckedTransfer(value: try makeTexture(values: [Float](repeating: 0.5, count: 25), format: .rgba32Float))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try source.value.c7.makeStructureStatistics(alphaType: .alphaIsOne)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testRenderedFrameEntryPoint() throws {
        let texture = try makeTexture(values: [Float](repeating: 0.5, count: 25), format: .rgba8Unorm)
        let frame = RenderedFrame(texture: texture, profile: .readbackQuality, generation: 1, identifier: "structure")
        XCTAssertEqual(try frame.makeStructureStatistics(alphaType: .alphaIsOne).sampleCount, 9)
    }

    private func oracle(values: [Float], width: Int, height: Int) -> (count: Int, laplacian: Float, gradient: Float) {
        var laplacian: Float = 0, gradient: Float = 0, count = 0
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let p = { (xx: Int, _ yy: Int) in values[yy * width + xx] }
            let c = 4 * p(x, y) - p(x - 1, y) - p(x + 1, y) - p(x, y - 1) - p(x, y + 1)
            let gx = (p(x + 1, y - 1) - p(x - 1, y - 1) + 2 * (p(x + 1, y) - p(x - 1, y)) + p(x + 1, y + 1) - p(x - 1, y + 1)) / 8
            let gy = (p(x - 1, y + 1) - p(x - 1, y - 1) + 2 * (p(x, y + 1) - p(x, y - 1)) + p(x + 1, y + 1) - p(x + 1, y - 1)) / 8
            laplacian += c * c; gradient += gx * gx + gy * gy; count += 1
        }}
        return (count, laplacian / Float(count), gradient / Float(count))
    }

    private func makeTexture(values: [Float], format: MTLPixelFormat, alpha: Float = 1, premultiply: Bool = false, transparentIndex: Int? = nil) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 5, height: 5, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let channels = values.enumerated().flatMap { index, value -> [Float] in
            let a = transparentIndex == index ? 0 : alpha
            let rgb = premultiply ? value * a : value
            return [rgb, rgb, rgb, a]
        }
        if format == .rgba8Unorm || format == .bgra8Unorm {
            let bytes = channels.map { UInt8(max(0, min(255, Int(($0 * 255).rounded())))) }
            texture.replace(region: MTLRegionMake2D(0, 0, 5, 5), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 20)
        } else if format == .rgba16Float {
            let half = channels.map(Float16.init)
            half.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, 5, 5), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 40) }
        } else {
            channels.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, 5, 5), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 80) }
        }
        return texture
    }
}
