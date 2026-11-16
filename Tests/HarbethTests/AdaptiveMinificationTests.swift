//
//  AdaptiveMinificationTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class AdaptiveMinificationTests: XCTestCase {
    func testAdaptiveModeIsExplicitlyBounded() {
        // adaptive 仅承诺有限 16×16 taps；严格带限仍需更高层策略。
        XCTAssertEqual(SpatialSamplingMode.adaptive.rawValue, 2)
    }

    func testNonAdaptiveSamplingModesRemainStable() {
        XCTAssertEqual(SpatialSamplingMode.nearest.rawValue, 0)
        XCTAssertEqual(SpatialSamplingMode.linear.rawValue, 1)
    }

    func testAdaptiveCheckerboardActuallyReducesMinificationEnergy() throws {
        let input = try makeCheckerboard(size: 64)
        let transform = CGAffineTransform(a: 0.25, b: 0, c: 0, d: 0.25, tx: 0.125, ty: 0.125)
        let adaptive = try HarbethIO(element: input, filter: C7Transform(mode: .fit, transform: transform, samplingMode: .adaptive, edgeMode: .clamp)).output()
        let linear = try HarbethIO(element: input, filter: C7Transform(mode: .fit, transform: transform, samplingMode: .linear, edgeMode: .clamp)).output()
        let a = try readableBytes(adaptive), l = try readableBytes(linear)
        let av = variance(of: a, width: adaptive.width, height: adaptive.height)
        let lv = variance(of: l, width: linear.width, height: linear.height)
        let ae = (mean(of: a) - 127.5) * (mean(of: a) - 127.5) + av
        let le = (mean(of: l) - 127.5) * (mean(of: l) - 127.5) + lv
        XCTAssertLessThan(ae, le)
        XCTAssertEqual(mean(of: a), 127.5, accuracy: 24)
    }

    func testAdaptiveCheckerboardEightToOneRemainsBounded() throws {
        let input = try makeCheckerboard(size: 64)
        let output = try HarbethIO(element: input, filter: C7Transform(mode: .fit, transform: CGAffineTransform(scaleX: 0.125, y: 0.125), samplingMode: .adaptive, edgeMode: .clamp)).output()
        let bytes = try readableBytes(output)
        XCTAssertEqual(mean(of: bytes), 127.5, accuracy: 30)
        XCTAssertLessThan(variance(of: bytes, width: output.width, height: output.height), 3000)
    }

    func testPerspectiveRectificationMinificationKeepsCheckerboardMean() throws {
        let source = try makeCheckerboard(size: 64)
        for quad in [RenderQuadTransform.Quad.identity, .init(topLeft: .init(x: 0.1, y: 0),
            topRight: .init(x: 0.9, y: 0.1), bottomLeft: .init(x: 0, y: 1), bottomRight: .init(x: 1, y: 0.9))] {
            let filter = RenderQuadRectifyTransform(sourceQuad: quad, samplingMode: .adaptive, edgeMode: .clamp, outputScale: 0.25)
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let bytes = try readableBytes(output)
            XCTAssertEqual(mean(of: bytes), 127.5, accuracy: 16)
            for i in stride(from: 3, to: bytes.count, by: 4) { XCTAssertEqual(bytes[i], 255) }
        }
    }

    func testAdaptivePreservesConstantRGBAChannels() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 8, height: 8, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pixel: [UInt8] = (0..<(8 * 8)).flatMap { _ -> [UInt8] in [40, 120, 200, 128] }
        input.replace(region: MTLRegionMake2D(0, 0, 8, 8), mipmapLevel: 0, withBytes: pixel, bytesPerRow: 32)
        let output = try HarbethIO(element: input, filter: C7Transform(mode: .fit, transform: CGAffineTransform(scaleX: 0.25, y: 0.25), samplingMode: .adaptive, edgeMode: .clamp)).output()
        let bytes = try readableBytes(output)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            XCTAssertEqual(bytes[i], 40, accuracy: 2); XCTAssertEqual(bytes[i + 1], 120, accuracy: 2)
            XCTAssertEqual(bytes[i + 2], 200, accuracy: 2); XCTAssertEqual(bytes[i + 3], 128, accuracy: 2)
        }
    }
}

private extension AdaptiveMinificationTests {
    func makeCheckerboard(size: Int) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var bytes = [UInt8](); bytes.reserveCapacity(size * size * 4)
        for y in 0..<size { for x in 0..<size { let v: UInt8 = (x + y).isMultiple(of: 2) ? 0 : 255; bytes += [v, v, v, 255] } }
        texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: bytes, bytesPerRow: size * 4)
        return texture
    }

    func readableBytes(_ texture: MTLTexture) throws -> [UInt8] { guard let bytes = texture.c7.bytes() else { throw HarbethError.texture2Image }; return Array(bytes) }
    func mean(of bytes: [UInt8]) -> Double { stride(from: 0, to: bytes.count, by: 4).map { Double(bytes[$0]) }.reduce(0, +) / Double(bytes.count / 4) }
    func variance(of bytes: [UInt8], width: Int, height: Int) -> Double { let m = mean(of: bytes); return stride(from: 0, to: bytes.count, by: 4).map { let d = Double(bytes[$0]) - m; return d * d }.reduce(0, +) / Double(max(width * height, 1)) }
}
