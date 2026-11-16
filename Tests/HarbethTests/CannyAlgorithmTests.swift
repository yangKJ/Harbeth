//
//  CannyAlgorithmTests.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
import MetalPerformanceShaders
@testable import Harbeth

final class CannyAlgorithmTests: XCTestCase {
    func testMPSCannyKeepsIndependentTransformThresholdsAndSigma() {
        let canny = MPSCanny(lowThreshold: 0.12, highThreshold: 0.63, sigma: 2.0, linearToGrayScaleTransform: SIMD3(0.2, 0.3, 0.5))
        XCTAssertEqual(canny.lowThreshold, 0.12, accuracy: 0.0001)
        XCTAssertEqual(canny.highThreshold, 0.63, accuracy: 0.0001)
        XCTAssertEqual(canny.sigma, 2.0, accuracy: 0.0001)
        XCTAssertEqual(canny.linearToGrayScaleTransform, SIMD3(0.2, 0.3, 0.5))
        var copy = canny
        copy.lowThreshold = 0.2
        XCTAssertEqual(canny.lowThreshold, 0.12, accuracy: 0.0001)
    }

    func testNativeCannyUsesMPSReferencePipeline() {
        let canny = C7Canny(threshold1: 0.1, threshold2: 0.5)
        XCTAssertEqual(canny.pipelineFilters.count, 2)
        XCTAssertEqual(canny.pipelineFilters[0].modifier, C7Grayed(with: .luminosity).modifier)
        XCTAssertTrue(canny.pipelineFilters[1] is MPSCanny)
        XCTAssertEqual(canny.makeFinalFilter(otherInputTextures: nil)?.modifier, .compute(kernel: "C7CannyFinal"))
        XCTAssertEqual(canny.kernelPixelContract.outputAlpha, .opaque)
    }

    func testConstantGrayHasNoEdgesAndOpaqueGrayOutput() throws {
        let source = try makeTexture(width: 8, height: 8) { _, _ in [80, 80, 80, 255] }
        let output: MTLTexture = try HarbethIO(element: source, filter: C7Canny()).output()
        let bytes = try XCTUnwrap(output.c7.bytes())
        XCTAssertTrue(bytes.dropLast().allSatisfy { $0 == 0 || $0 == 255 })
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            XCTAssertEqual(bytes[pixel], bytes[pixel + 1]); XCTAssertEqual(bytes[pixel], bytes[pixel + 2]); XCTAssertEqual(bytes[pixel + 3], 255)
        }
        // MPS 对图像外部使用其边缘定义；平坦内部不能生成边缘。
        for y in 3..<5 { for x in 3..<5 { XCTAssertEqual(bytes[(y * 8 + x) * 4], 0) } }
    }

    func testStepImageProducesEdgesMatchingDirectMPSReference() throws {
        let source = try makeTexture(width: 16, height: 16) { x, _ in x < 8 ? [0, 0, 0, 255] : [255, 255, 255, 255] }
        let native: MTLTexture = try HarbethIO(element: source, filter: C7Canny()).output()
        let gray: MTLTexture = try HarbethIO(element: source, filter: C7Grayed(with: .luminosity)).output()
        let reference: MTLTexture = try HarbethIO(element: gray, filter: MPSCanny(lowThreshold: 0.2, highThreshold: 0.4)).output()
        let a = try XCTUnwrap(native.c7.bytes()), b = try XCTUnwrap(reference.c7.bytes())
        XCTAssertGreaterThan(a.filter { $0 == 255 }.count, 0)
        for i in stride(from: 0, to: a.count, by: 4) { XCTAssertEqual(a[i], a[i + 1]); XCTAssertEqual(a[i], a[i + 2]); XCTAssertEqual(a[i + 3], 255); XCTAssertEqual(a[i], b[i]) }
    }

    func testWeakEdgeChainLongerThanThirtyTwoPixelsMatchesMPSReferenceAndThresholdChanges() throws {
        let source = try makeTexture(width: 64, height: 64) { x, y in
            let edge = abs(x - y) <= 1 ? 150 : 0
            return [UInt8(edge), UInt8(edge), UInt8(edge), 255]
        }
        let low: MTLTexture = try HarbethIO(element: source, filter: C7Canny(threshold1: 0.05, threshold2: 0.2)).output()
        let high: MTLTexture = try HarbethIO(element: source, filter: C7Canny(threshold1: 0.4, threshold2: 0.8)).output()
        let gray: MTLTexture = try HarbethIO(element: source, filter: C7Grayed(with: .luminosity)).output()
        let reference: MTLTexture = try HarbethIO(element: gray, filter: MPSCanny(lowThreshold: 0.05, highThreshold: 0.2)).output()
        let lowBytes = try XCTUnwrap(low.c7.bytes()), highBytes = try XCTUnwrap(high.c7.bytes()), refBytes = try XCTUnwrap(reference.c7.bytes())
        XCTAssertEqual(lowBytes.count, 64 * 64 * 4); XCTAssertNotEqual(lowBytes, highBytes)
        for i in stride(from: 0, to: lowBytes.count, by: 4) { XCTAssertEqual(lowBytes[i], refBytes[i]); XCTAssertEqual(lowBytes[i + 3], 255) }
    }

    private func makeTexture(width: Int, height: Int, pixel: (Int, Int) -> [UInt8]) throws -> MTLTexture {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(MTLCreateSystemDefaultDevice()!.makeTexture(descriptor: descriptor))
        var bytes = [UInt8](); bytes.reserveCapacity(width * height * 4)
        for y in 0..<height { for x in 0..<width { bytes.append(contentsOf: pixel(x, y)) } }
        TextureLoader.replaceTexture(texture, region: MTLRegionMake2D(0, 0, width, height), bytes: bytes, packedBytesPerRow: width * 4)
        return texture
    }
}
