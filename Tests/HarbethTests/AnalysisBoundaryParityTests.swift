//
//  AnalysisBoundaryParityTests.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class AnalysisBoundaryParityTests: XCTestCase {
    func testOriginalBoundaryUsesIdenticalInclusiveDecisions() throws {
        let rgb = SIMD4<Float>(0.6733067632, 0.3625498116, 0.1553784907, 1)
        let texture = try makeTexture(rgb, format: .rgba32Float)
        let l: Float = 0.41365897655487061
        XCTAssertEqual(analysisRec709Luminance(rgb.x, rgb.y, rgb.z).bitPattern, l.bitPattern)
        for (minimum, maximum, expected): (Float, Float, Int) in [
            (l, l, 1), (l.nextUp, 1, 0), (0, l.nextDown, 0), (l.nextDown, l, 1), (l, l.nextUp, 1)
        ] {
            let scope = TextureAnalysisScope(luminanceRange: .init(minimum: minimum, maximum: maximum))
            let cpu = try XCTUnwrap(texture.c7.makeStatistics(scope: scope))
            let gpu = try XCTUnwrap(GPUTextureAnalysis.statistics(texture, scope: scope))
            let a = try XCTUnwrap(texture.c7.makeHistogram(channel: .luminance, bins: 257, scope: scope, preferredMethod: .cpuReadback))
            let b = try XCTUnwrap(GPUTextureAnalysis.histogram(texture, channel: .luminance, bins: 257, scope: scope))
            XCTAssertEqual(cpu.sampleCount, expected)
            XCTAssertEqual(gpu.sampleCount, expected)
            XCTAssertEqual(a.totalSampleCount, expected)
            XCTAssertEqual(a.bins, b.bins)
            let mask = try XCTUnwrap(try texture.c7.makeMaskTexture(scope: scope, pixelFormat: .rgba32Float))
            XCTAssertEqual(try NeighborhoodTestImage.read(mask)[0], Float(expected))
        }
    }

    func testStorageFormatsROIAndMaskAgreeAtBothEndpoints() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let color = SIMD4<Float>(0.25, 0.5, 0.75, 1)
            let texture = try makeTexture(color, format: format, width: 17, height: 13)
            let mask = try makeTexture(SIMD4(1, 0, 0, 1), format: .rgba32Float, width: 3, height: 2)
            let l = (color.z * Float(0.0722)).addingProduct(color.y, 0.7152).addingProduct(color.x, 0.2126)
            for (minimum, maximum, count): (Float, Float, Int) in [(l, l, 20), (l.nextUp, 1, 0), (0, l.nextDown, 0)] {
                let scope = TextureAnalysisScope(region: MTLRegionMake2D(3, 2, 5, 4), mask: .init(texture: mask, component: .red),
                    luminanceRange: .init(minimum: minimum, maximum: maximum))
                let cpu = try XCTUnwrap(texture.c7.makeStatistics(scope: scope))
                let gpu = try XCTUnwrap(GPUTextureAnalysis.statistics(texture, scope: scope))
                XCTAssertEqual(cpu.sampleCount, count); XCTAssertEqual(gpu.sampleCount, count)
                let a = try XCTUnwrap(texture.c7.makeHistogram(channel: .luminance, bins: 257, scope: scope, preferredMethod: .cpuReadback))
                let b = try XCTUnwrap(GPUTextureAnalysis.histogram(texture, channel: .luminance, bins: 257, scope: scope))
                XCTAssertEqual(a.bins, b.bins); XCTAssertEqual(a.totalSampleCount, count)
                let scopedMask = try XCTUnwrap(try texture.c7.makeMaskTexture(scope: scope, pixelFormat: .rgba32Float))
                let values = try NeighborhoodTestImage.read(scopedMask)
                for y in 0..<13 { for x in 0..<17 {
                    let selected = count > 0 && (3..<8).contains(x) && (2..<6).contains(y)
                    XCTAssertEqual(values[(y * 17 + x) * 4], selected ? 1 : 0)
                } }
            }
        }
    }

    private func makeTexture(_ value: SIMD4<Float>, format: MTLPixelFormat, width: Int = 1, height: Int = 1) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeTexture(descriptor: d))
        let data = Array(repeating: value, count: width * height)
        if format == .rgba16Float {
            let half = data.flatMap { [Float16($0.x), Float16($0.y), Float16($0.z), Float16($0.w)] }
            half.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else {
            data.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        }
        return texture
    }
}
