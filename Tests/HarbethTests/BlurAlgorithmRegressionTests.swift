//
//  BlurAlgorithmRegressionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

/// 算法数值与边界回归，覆盖独立二维参考和真实 GPU 输出。
final class BlurAlgorithmRegressionTests: XCTestCase {
    func testLocalBlurUsesTwoSeparablePassesAndKeepsRadius() {
        let filter = C7LocalBlur(radius: 40, center: .center, size: 1, softness: 0.3)
        XCTAssertEqual(filter.pipelineFilters.count, 2)
        XCTAssertEqual(filter.factors[0], 40)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 40))
    }

    func testTiltShiftKeepsFullRadiusInBothModes() {
        for mode in [C7TiltShift.TiltShiftMode.linear, .radial] {
            let filter = C7TiltShift(blurRadius: 0.2, mode: mode)
            XCTAssertEqual(filter.pipelineFilters.count, 2)
            XCTAssertEqual(filter.factors[0], 0.2, accuracy: 0.0001)
            XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 20))
        }
    }

    func testBilateralPreservesFloatParametersForHDRAndInvalidSigmaIsRepresentable() {
        let filter = C7BilateralBlur(sigmaSpace: 0, sigmaColor: -1, radius: 7)
        XCTAssertEqual(filter.factors, [0, -1, 7])
        let hdr = C7BilateralBlur(sigmaSpace: 15, sigmaColor: 0.3, radius: 7)
        XCTAssertTrue(hdr.factors.allSatisfy(\.isFinite))
    }

    func testSurfaceBlurRetainsNeighborhoodHaloOnOddDimensions() {
        let filter = C7SurfaceBlur(radius: 8.25, threshold: 0.1)
        XCTAssertEqual(filter.kernelPixelContract.samplingFootprint, .neighborhood(radius: 9))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
    }

    func testZeroRadiusLocalAndTiltShiftArePixelExact() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let input = try makeTexture(width: 5, height: 3, pixels: Array(repeating: [80, 120, 160, 255], count: 15).flatMap { $0 })
        let expected = try XCTUnwrap(input.c7.rawBytes(maximumBytes: 5 * 3 * 4))
        for filter in [C7LocalBlur(radius: 0), C7TiltShift(blurRadius: 0)] as [any C7FilterProtocol] {
            let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: expected.count), expected)
        }
    }

    func testBilateralHDRConstantRemainsFiniteAndStable() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let input = try makeFloatTexture(width: 3, height: 3, value: [1000, 1000, 1000, 1])
        let output: MTLTexture = try HarbethIO(element: input, filter: C7BilateralBlur(sigmaSpace: 15, sigmaColor: 0.3, radius: 2)).output()
        let data = try XCTUnwrap(output.c7.rawBytes(maximumBytes: 3 * 3 * 8))
        XCTAssertTrue(data.withUnsafeBytes { raw in raw.bindMemory(to: UInt16.self).allSatisfy { $0 != 0x7c00 } })
    }

    func testSeparableBlurMatchesIndependentTwoDimensionalReference() throws {
        let width = 9, height = 7
        let pixels: [[Float]] = (0..<(width * height)).map { index in
            let x = Float(index % width) / Float(width), y = Float(index / width) / Float(height)
            let alpha: Float = 0.3 + 0.6 * y
            return [x * alpha, y * alpha, 0.2 * alpha, alpha]
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let source = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let half = pixels.flatMap { $0.map(Float16.init) }
        half.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        let quantized = stride(from: 0, to: half.count, by: 4).map { offset in (0..<4).map { Float(half[offset + $0]) } }
        for filter in [C7LocalBlur(radius: 2), C7LocalBlur(radius: 10), C7LocalBlur(radius: 12, size: 1), C7TiltShift(blurRadius: 0.2, mode: .linear), C7TiltShift(blurRadius: 0.2, mode: .radial)] as [any C7FilterProtocol] {
            let isLocal = filter is C7LocalBlur
            let radius = (filter as? C7LocalBlur).map { Int(ceil($0.radius)) } ?? 20
            let sigma: Double = isLocal ? Double(radius) / 3 : 2
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            let bytes = try XCTUnwrap(output.c7.rawBytes(maximumBytes: width * height * 8))
            let actual = bytes.withUnsafeBytes { $0.bindMemory(to: UInt16.self).map { Float(Float16(bitPattern: $0)) } }
            for y in 0..<height { for x in 0..<width {
                var sums = [Double](repeating: 0, count: 4), total = 0.0
                for dy in -radius...radius { for dx in -radius...radius {
                    let weight = exp(-Double(dx * dx + dy * dy) / (2 * sigma * sigma))
                    let sample = quantized[min(max(y + dy, 0), height - 1) * width + min(max(x + dx, 0), width - 1)]
                    for channel in 0..<4 { sums[channel] += Double(sample[channel]) * weight }
                    total += weight
                } }
                let amount: Float
                if isLocal {
                    let distance = hypot(Float(x) / Float(width) - 0.5, Float(y) / Float(height) - 0.5)
                    let local = filter as! C7LocalBlur
                    let t = min(max((distance - local.size * 0.5) / -local.softness, 0), 1)
                    let strength = t * t * (3 - 2 * t)
                    amount = strength < 0.01 ? 0 : strength
                } else {
                    let tilt = filter as! C7TiltShift
                    let distance = tilt.mode == .linear ? abs(Float(y) / Float(height) - 0.5)
                        : hypot(Float(x) - Float(width) * 0.5, Float(y) - Float(height) * 0.5) / hypot(Float(width) * 0.5, Float(height) * 0.5)
                    amount = min(max((distance - 0.15) / 0.1, 0), 1) * 0.2
                }
                for channel in 0..<4 {
                    let original = quantized[y * width + x][channel]
                    let expected = original + (Float(sums[channel] / total) - original) * amount
                    XCTAssertEqual(actual[(y * width + x) * 4 + channel], expected, accuracy: 0.0015)
                }
            } }
        }
    }

    func testZeroBlurPreservesFloat32Bits() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 3, height: 2, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let source = try XCTUnwrap(device.makeTexture(descriptor: d))
        let values = Array(repeating: [Float(0.1234567), 0.2345678, 0.3456789, 0.9876543], count: 6).flatMap { $0 }
        values.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, 3, 2), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 3 * 16) }
        let expected = try XCTUnwrap(source.c7.rawBytes(maximumBytes: 96))
        for filter in [C7LocalBlur(radius: 0), C7TiltShift(blurRadius: 0)] as [any C7FilterProtocol] {
            let output: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: 96), expected)
        }
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]
        let t = try XCTUnwrap(device.makeTexture(descriptor: d))
        t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
        return t
    }

    private func makeFloatTexture(width: Int, height: Int, value: [Float16]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]
        let t = try XCTUnwrap(device.makeTexture(descriptor: d))
        let bytes = Array(repeating: value, count: width * height).flatMap { $0 }
        t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 8)
        return t
    }
}
