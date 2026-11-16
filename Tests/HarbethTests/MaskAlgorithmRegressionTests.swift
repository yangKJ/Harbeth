//
//  MaskAlgorithmRegressionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class MaskAlgorithmRegressionTests: XCTestCase {
    func testDistanceFieldMatchesSmallImageCPUReference() throws {
        let width = 5, height = 3
        let active = Set([2 + 1 * width])
        let pixels = (0..<(width * height)).flatMap { index -> [UInt8] in
            let value: UInt8 = active.contains(index) ? 255 : 0
            return [0, 0, 0, value]
        }
        let source = try makeTexture(width: width, height: height, pixels: pixels)
        let output = try MaskDistanceFieldRecipe(maxDistance: 4, threshold: 0.5)
            .makeTexture(from: MaskDescriptor(texture: source, component: .alpha))
        for y in 0..<height {
            for x in 0..<width {
                let expected = cpuDistance(x: x, y: y, width: width, height: height, active: active, maxDistance: 4)
                let actual = Float(try MaskTestHelpers.pixel(in: output, x: x, y: y).red) / 255
                XCTAssertEqual(actual, expected, accuracy: 0.03, "pixel (\(x),\(y))")
            }
        }
    }

    func testDistanceFieldHandlesEmptyFullOddAndHalfThreshold() throws {
        let empty = try makeTexture(width: 3, height: 5, pixels: Array(repeating: UInt8(0), count: 3 * 5 * 4))
        let full = try makeTexture(width: 3, height: 5, pixels: Array(repeating: [0, 0, 0, 255], count: 15).flatMap { $0 })
        let mixed = try makeTexture(width: 3, height: 5, pixels: (0..<15).flatMap { i in [0, 0, 0, i == 7 ? 128 : 127] })
        for distance in [3 as Float, 16, 64] {
            let recipe = MaskDistanceFieldRecipe(maxDistance: distance, threshold: 0.5)
            XCTAssertEqual(try MaskTestHelpers.pixel(in: recipe.makeTexture(from: MaskDescriptor(texture: empty, component: .alpha)), x: 1, y: 2).red, 255, accuracy: 3)
            XCTAssertEqual(try MaskTestHelpers.pixel(in: recipe.makeTexture(from: MaskDescriptor(texture: full, component: .alpha)), x: 1, y: 2).red, 255, accuracy: 3)
        }
        let recipe = MaskDistanceFieldRecipe(maxDistance: 3, threshold: 0.5)
        let center = try MaskTestHelpers.pixel(in: recipe.makeTexture(from: MaskDescriptor(texture: mixed, component: .alpha)), x: 1, y: 2).red
        XCTAssertLessThan(center, 255)
    }

    func testGPUAnalysisRetainsSoftCoverageBelowThreshold() throws {
        let texture = try makeTexture(width: 3, height: 3, pixels: (0..<9).flatMap { i in
            let value: UInt8 = i == 4 ? 255 : 64
            return [value, value, value, 255]
        })
        let analysis = try MaskGPUAnalysisBackend.analyze(texture: texture, threshold: 0.5)
        XCTAssertEqual(analysis.activePixelCount, 1)
        XCTAssertEqual(analysis.coverageFraction, (255.0 + 8.0 * 64.0) / (255.0 * 9.0), accuracy: 0.02)
    }
}

private extension MaskAlgorithmRegressionTests {
    func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        let device = try MaskTestHelpers.requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw HarbethError.makeTexture }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
        return texture
    }

    func cpuDistance(x: Int, y: Int, width: Int, height: Int, active: Set<Int>, maxDistance: Float) -> Float {
        let inside = active.contains(x + y * width)
        var best = maxDistance
        for yy in 0..<height {
            for xx in 0..<width where active.contains(xx + yy * width) != inside {
                best = min(best, hypotf(Float(xx - x), Float(yy - y)))
            }
        }
        return min(best / maxDistance, 1)
    }
}
